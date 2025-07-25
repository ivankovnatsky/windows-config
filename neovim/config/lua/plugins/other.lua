return {
  -- Enhanced 2-character search motion
  "justinmk/vim-sneak",

  -- Surround text objects with quotes, brackets, etc.
  -- https://github.com/LazyVim/LazyVim/discussions/906#discussioncomment-6126533
  {
    "kylechui/nvim-surround",
    version = "*", -- Use for stability; omit to use `main` branch for the latest features
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup()
    end,
  },
}
