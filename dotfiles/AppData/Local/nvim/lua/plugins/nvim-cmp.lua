return {
  {
    "hrsh7th/nvim-cmp",
    dependencies = { 
      "hrsh7th/cmp-emoji",
    },
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      local cmp = require("cmp")
      
      -- Add sources
      opts.sources = cmp.config.sources({
        { name = "nvim_lsp", group_index = 2 },
        { name = "emoji", group_index = 2 },
      })

      return opts
    end,
  },
}
