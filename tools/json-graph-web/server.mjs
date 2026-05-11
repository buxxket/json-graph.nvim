import { createServer } from "node:http";
import { readFileSync, createReadStream, existsSync, statSync } from "node:fs";
import { extname, join, normalize } from "node:path";
import { spawnSync } from "node:child_process";

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith("--")) {
      continue;
    }
    const key = token.slice(2);
    const value = argv[i + 1];
    if (!value || value.startsWith("--")) {
      args[key] = "true";
      continue;
    }
    args[key] = value;
    i += 1;
  }
  return args;
}

function jsonResponse(response, statusCode, payload) {
  response.writeHead(statusCode, { "Content-Type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(payload));
}

function guessContentType(filePath) {
  const extension = extname(filePath).toLowerCase();
  if (extension === ".html") return "text/html; charset=utf-8";
  if (extension === ".js") return "text/javascript; charset=utf-8";
  if (extension === ".css") return "text/css; charset=utf-8";
  if (extension === ".json") return "application/json; charset=utf-8";
  if (extension === ".svg") return "image/svg+xml";
  return "application/octet-stream";
}

function encodeVimSingleQuoted(value) {
  return `'${value.replace(/'/g, "''")}'`;
}

function sendJump(pathArray, nvimServer, nvimBin) {
  if (!nvimServer || pathArray.length === 0) {
    return { ok: false, reason: "missing nvim target or path" };
  }

  const jsonPath = JSON.stringify(pathArray);
  const expression = `luaeval("require('json_graph').jump_to_path(vim.fn.json_decode(_A))", ${encodeVimSingleQuoted(jsonPath)})`;
  const result = spawnSync(nvimBin, ["--server", nvimServer, "--remote-expr", expression], {
    encoding: "utf8",
  });

  if (result.status !== 0) {
    return {
      ok: false,
      reason: result.stderr || result.stdout || `remote expr failed (${result.status})`,
    };
  }

  return { ok: true };
}

const args = parseArgs(process.argv);
const distDir = args.dist;
const sessionFile = args.session;
const nvimServer = args["nvim-server"];
const nvimBin = args["nvim-bin"] || "nvim";
const mode = args.mode || "auto";

if (!distDir || !sessionFile) {
  console.error("Missing required --dist or --session arguments");
  process.exit(2);
}

if (!existsSync(distDir) || !existsSync(join(distDir, "index.html"))) {
  console.error(`Missing built assets in ${distDir}`);
  process.exit(3);
}

if (!existsSync(sessionFile)) {
  console.error(`Missing session file: ${sessionFile}`);
  process.exit(4);
}

const sessionRaw = readFileSync(sessionFile, "utf8");
const sessionData = JSON.parse(sessionRaw);

const server = createServer((request, response) => {
  if (!request.url) {
    response.writeHead(400);
    response.end("Bad Request");
    return;
  }

  const url = new URL(request.url, "http://127.0.0.1");

  if (request.method === "GET" && url.pathname === "/api/session") {
    jsonResponse(response, 200, {