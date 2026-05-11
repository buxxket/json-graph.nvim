local function parse_args(args)
	local opts = { view = "auto" }
	for _, arg in ipairs(args.fargs) do
		if arg == "browser" or arg == "svg" or arg == "split" or arg == "auto" then
			opts.view = arg
		elseif arg == "schema" or arg == "data" then
			opts.mode = arg
		end
	end
	return opts
end

vim.api.nvim_create_user_command("JsonGraph", function(args)
	require("json_graph").open(parse_args(args))
end, {
	nargs = "*",
	complete = function()
		return { "auto", "browser", "svg", "split", "schema", "data" }
	end,
	desc = "Open a graph view for the current JSON buffer",
})

vim.api.nvim_create_user_command("JsonGraphSchema", function()
	require("json_graph").open({ view = "auto", mode = "schema" })
end, {
	nargs = 0,
	desc = "Open JSON graph with schema defaults",
})

vim.api.nvim_create_user_command("JsonGraphBuild", function()
	local out, err = require("json_graph").build_web()
	if out then
		vim.notify("JSON graph web assets built: " .. out, vim.log.levels.INFO)
		return
	end
	vim.notify("JSON graph web build failed: " .. tostring(err), vim.log.levels.ERROR)
end, {
	nargs = 0,
	desc = "Build local offline web assets for JSON graph",
})

vim.keymap.set("n", "<leader>jg", function()
	require("json_graph").open({ view = "auto" })
end, { desc = "Open JSON graph" })