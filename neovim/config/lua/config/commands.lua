-- User commands for LazyVim
-- Ported from nixvim configuration

-- Toggle commands
vim.api.nvim_create_user_command("MouseToggle", function()
  if vim.o.mouse == "a" then
    vim.o.mouse = ""
    print("Mouse disabled")
  else
    vim.o.mouse = "a"
    print("Mouse enabled")
  end
end, {
  desc = "Toggle mouse",
  bang = true,
  bar = true,
})

vim.api.nvim_create_user_command("SpellToggle", function()
  if vim.o.spell then
    vim.o.spell = false
    print("Spell check disabled")
  else
    vim.o.spell = true
    print("Spell check enabled")
  end
end, {
  desc = "Toggle spell check",
  bang = true,
  bar = true,
})

-- File content commands
vim.api.nvim_create_user_command("Yank", function()
  vim.cmd("silent %y+")
  print("Copied file contents to clipboard")
end, {
  desc = "Copy file contents to clipboard",
  bang = true,
  bar = true,
})

vim.api.nvim_create_user_command("Eat", function()
  vim.cmd("Yank")
end, {
  desc = "Copy file contents to clipboard (alias for Yank)",
  bang = true,
  bar = true,
})

vim.api.nvim_create_user_command("PasteReplace", function()
  vim.cmd("%d | put + | 0d | wall")
  print("Replaced file contents with clipboard")
end, {
  desc = "Replace file contents with clipboard",
  bang = true,
  bar = true,
})

vim.api.nvim_create_user_command("ReplaceFileText", function()
  vim.cmd("PasteReplace")
end, {
  desc = "Replace file contents with clipboard (alias for PasteReplace)",
  bang = true,
  bar = true,
})

-- File navigation commands
vim.api.nvim_create_user_command("E", function(opts)
  local current_dir = vim.fn.expand("%:h")
  local new_file = current_dir .. "/" .. opts.args
  vim.cmd("e " .. new_file)
end, {
  desc = "Open a new file in the same directory as the current file",
  nargs = 1,
  bang = true,
  bar = true,
  complete = "dir",
})

vim.api.nvim_create_user_command("EditInCurrentDir", function(opts)
  vim.cmd("E " .. opts.args)
end, {
  desc = "Open a file in the same directory as the current file",
  nargs = 1,
  bang = true,
  bar = true,
  complete = "dir",
})

-- Telescope aliases (fzf.vim muscle memory)
vim.api.nvim_create_user_command("Files", function()
  require("telescope.builtin").find_files()
end, {
  desc = "Find files using Telescope",
  bang = true,
  bar = true,
})

vim.api.nvim_create_user_command("Buffers", function()
  require("telescope.builtin").buffers()
end, {
  desc = "List buffers using Telescope",
  bang = true,
  bar = true,
})

vim.api.nvim_create_user_command("Registers", function()
  require("telescope.builtin").registers()
end, {
  desc = "List registers using Telescope",
  bang = true,
  bar = true,
})

vim.api.nvim_create_user_command("GFiles", function()
  require("telescope.builtin").git_files()
end, {
  desc = "Find git files using Telescope",
  bang = true,
  bar = true,
})

vim.api.nvim_create_user_command("OFiles", function()
  require("telescope.builtin").oldfiles()
end, {
  desc = "Find recently opened files using Telescope",
  bang = true,
  bar = true,
})

-- Ripgrep commands
vim.api.nvim_create_user_command("Rg", function(opts)
  if opts.args and opts.args ~= "" then
    require("telescope.builtin").grep_string({ search = opts.args })
  else
    require("telescope.builtin").grep_string()
  end
end, {
  desc = "Search using ripgrep (static)",
  nargs = "?",
  bang = true,
  bar = true,
})

vim.api.nvim_create_user_command("RG", function()
  require("telescope.builtin").live_grep()
end, {
  desc = "Search using ripgrep (dynamic)",
  bang = true,
  bar = true,
})
