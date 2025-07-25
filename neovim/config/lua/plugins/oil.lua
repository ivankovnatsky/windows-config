return {
  {
    'stevearc/oil.nvim',
    opts = {
      -- Default oil config
      view_options = {
        -- Show hidden files
        show_hidden = false,
      },
      -- Add file icons
      columns = {
        "icon",
      },
      -- Buffer-local options to use for oil buffers
      buf_options = {
        buflisted = false,
      },
    },
    -- Optional dependency for file icons
    dependencies = { "nvim-tree/nvim-web-devicons" },
  }
}
