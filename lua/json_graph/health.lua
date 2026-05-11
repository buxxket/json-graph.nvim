local M = {}

local function plugin_root()
	local source = debug.getinfo(1, "S").source:sub(2)
	return vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source)))
end

local function exists(path)
	return vim.uv.fs_stat(path) ~= nil
end

local function check_executable(name, required)
	local executable = vim.fn.exepath(name)
	if executable ~= "" then
		vim.health.ok(string.format("%s found: %s", name, executable))
		return
	end

	if required then
		vim.health.error(string.format("%s not found in PATH", name))
	else
		vim.health.warn(string.format("%s not found in PATH (optional)", name))
	end
end

function M.check()
	vim.health.start("nvim-json-graph requirements")

	check_executable("node", true)
	check_executable("pnpm", true)
	check_executable("nvim", true)
	check_executable("dot", false)

	if vim.ui and vim.ui.open then
		vim.health.ok("vim.ui.open is available for opening browser URLs")
	else
		check_executable("xdg-open", false)
	end

	local root = plugin_root()
	local web_root = root .. "/tools/json-graph-web"
	local package_json = web_root .. "/package.json"
	local server_script = web_root .. "/server.mjs"
	local dist_index = web_root .. "/dist/index.html"

	if exists(package_json) then
		vim.health.ok("Web app source found: " .. package_json)
	else
		vim.health.error("Missing web app source: " .. package_json)
	end

	if exists(server_script) then
		vim.health.ok("Bridge server found: " .. server_script)
	else
		vim.health.error("Missing bridge server: " .. server_script)
	end

	if exists(dist_index) then
		vim.health.ok("Built web assets found: " .. dist_index)
	else
		vim.health.warn("Built web assets missing. Run :JsonGraphBuild")
	end
end

return M