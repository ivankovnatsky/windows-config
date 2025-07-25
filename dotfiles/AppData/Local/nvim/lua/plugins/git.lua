return {
  {
    "tpope/vim-fugitive",    -- The premier Git plugin for Vim
    cmd = { "Git", "G" },    -- Load only when these commands are used
  },
  {
    "sindrets/diffview.nvim", -- Enhanced diff viewing
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles" },
    config = true,
  },
}
