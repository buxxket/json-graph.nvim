local M = {
	state = {
		source_bufnr = nil,
		source_winid = nil,
	},
}

local function plugin_root()
	local source = debug.getinfo(1, "S").source:sub(2)
	return vim.fs.dirname(vim.fs.dirname(source))
end

local function web_root()
	return plugin_root() .. "/tools/json-graph-web"
end

local function web_dist_index()
	return web_root() .. "/dist/index.html"
end

local function read_current_buffer_text(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	return table.concat(lines, "\n")
end

local function decode_json(text)
	local ok, decoded = pcall(vim.json.decode, text)
	if not ok then
		return nil, decoded
	end
	return decoded, nil
end

local function run_command(cmd, cwd)
	if vim.system then
		local result = vim.system(cmd, { cwd = cwd, text = true }):wait()
		return result.code == 0, result.stdout or "", result.stderr or ""
	end

	local joined = table.concat(vim.tbl_map(vim.fn.shellescape, cmd), " ")
	local output = vim.fn.system(joined)
	local ok = vim.v.shell_error == 0
	return ok, output or "", ok and "" or (output or "")
end

local function format_command_error(prefix, stdout_text, stderr_text)
	local stdout_trimmed = vim.trim(stdout_text or "")
	local stderr_trimmed = vim.trim(stderr_text or "")
	local details = stderr_trimmed
	if details == "" then
		details = stdout_trimmed
	end
	if details == "" then
		return prefix
	end
	return prefix .. ": " .. details
end

function M.build_web()
	local root = web_root()
	if vim.uv.fs_stat(root .. "/package.json") == nil then
		return nil, "Missing tools/json-graph-web/package.json"
	end

	local ok_install, install_out, install_err = run_command({ "pnpm", "install", "--frozen-lockfile" }, root)
	if not ok_install then
		-- Lockfile mismatches are common across pnpm versions; retry non-frozen install.
		ok_install, install_out, install_err = run_command({ "pnpm", "install" }, root)
	end
	if not ok_install then
		return nil, format_command_error("pnpm install failed", install_out, install_err)
	end

	local ok_build, build_out, build_err = run_command({ "pnpm", "build" }, root)
	if not ok_build then
		return nil, format_command_error("pnpm build failed", build_out, build_err)
	end

	local dist = web_dist_index()
	if vim.uv.fs_stat(dist) == nil then
		return nil, "Build finished but dist/index.html is missing"
	end

	return dist, nil
end

local function open_in_split(decoded)
	local out = vim.inspect(decoded)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].filetype = "lua"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(out, "\n"))
	vim.cmd("botright split")
	vim.api.nvim_win_set_buf(0, buf)
end

function M.open(opts)
	opts = opts or {}
	local bufnr = vim.api.nvim_get_current_buf()
	local text = read_current_buffer_text(bufnr)
	local decoded, err = decode_json(text)
	if not decoded then
		vim.notify("JsonGraph: invalid JSON: " .. tostring(err), vim.log.levels.ERROR)
		return
	end

	M.state.source_bufnr = bufnr
	M.state.source_winid = vim.api.nvim_get_current_win()

	local view = opts.view or "auto"
	if view == "split" then
		open_in_split(decoded)
		return
	end

	if vim.uv.fs_stat(web_dist_index()) == nil then
		vim.notify("JsonGraph: web assets missing. Run :JsonGraphBuild", vim.log.levels.WARN)
		open_in_split(decoded)
		return
	end

	local target = "file://" .. web_dist_index()
	if vim.ui and vim.ui.open then
		vim.ui.open(target)
	else
		vim.fn.jobstart({ "xdg-open", target }, { detach = true })
	end
end

function M.jump_to_path(_path)
	if M.state.source_winid and vim.api.nvim_win_is_valid(M.state.source_winid) then
		vim.api.nvim_set_current_win(M.state.source_winid)
	end
	return true
end

return M
