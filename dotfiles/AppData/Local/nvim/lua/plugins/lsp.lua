return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "jose-elias-alvarez/typescript.nvim",
      init = function()
        require("lazyvim.util").lsp.on_attach(function(_, buffer)
          -- stylua: ignore
          vim.keymap.set("n", "<leader>co", "TypescriptOrganizeImports", { buffer = buffer, desc = "Organize Imports" })
          vim.keymap.set("n", "<leader>cR", "TypescriptRenameFile", { desc = "Rename File", buffer = buffer })
        end)
      end,
    },
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      
      -- PowerShell config
      opts.servers.powershell_es = {
        bundle_path = vim.fn.stdpath("data") .. "/mason/packages/powershell-editor-services",
        shell = "pwsh.exe",
        cmd = { "pwsh.exe", "-NoLogo", "-NoProfile", "-Command" },
        settings = {
          powershell = {
            codeFormatting = { Preset = "OTBS" }
          }
        }
      }

      -- Python config
      opts.servers.pyright = {}

      -- TypeScript config
      opts.servers.tsserver = {}
      
      -- you can do any additional lsp server setup here
      -- return true if you don't want this server to be setup with lspconfig
      opts.setup = {
        -- example to setup with typescript.nvim
        tsserver = function(_, server_opts)
          require("typescript").setup({ server = server_opts })
          return true
        end,
        -- Specify * to use this function as a fallback for any server
        -- ["*"] = function(server, opts) end,
      }
      
      return opts
    end,
  }
} 
