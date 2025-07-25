return {
  -- Enhanced PowerShell configuration
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- Add PowerShell to ensure_installed
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, { "powershell" })
      end
    end,
  },

  -- Configure PowerShell LSP
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        powershell_es = {
          bundle_path = vim.fn.stdpath("data") .. "/mason/packages/powershell-editor-services",
          shell = "pwsh.exe", -- or "powershell.exe" for Windows PowerShell
          cmd = { "pwsh.exe", "-NoLogo", "-NoProfile", "-Command" },
          settings = {
            powershell = {
              codeFormatting = {
                Preset = "OTBS", -- One True Brace Style
              },
            },
          },
        },
      },
    },
  },
}
