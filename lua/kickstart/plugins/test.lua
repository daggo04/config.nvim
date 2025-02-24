-- test.lua
return {
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'antoinemadec/FixCursorHold.nvim',
      'nvim-treesitter/nvim-treesitter',
      'nvim-neotest/nvim-nio',
      'nvim-neotest/neotest-python', -- Python test adapter
    },
    config = function()
      -- Get neotest namespace (api call creates or returns namespace)
      local neotest_ns = vim.api.nvim_create_namespace 'neotest'
      vim.diagnostic.config({
        virtual_text = {
          format = function(diagnostic)
            local message = diagnostic.message:gsub('\n', ' '):gsub('\t', ' '):gsub('%s+', ' '):gsub('^%s+', '')
            return message
          end,
        },
      }, neotest_ns)

      require('neotest').setup {
        -- Your neotest config here
        adapters = {
          require 'neotest-python' {
            -- Extra arguments for nvim-dap configuration
            -- See https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for values
            dap = {
              justMyCode = false,
              console = 'integratedTerminal',
            },
            args = { '--verbose' },
            runner = 'pytest',
          },
        },
        status = {
          virtual_text = true,
          signs = true,
        },
        output = {
          enabled = true,
          open_on_run = true,
        },
        floating = {
          border = 'rounded',
          max_height = 0.9,
          max_width = 0.9,
          options = {},
        },
      }

      -- Set up keymaps for convenient test running
      vim.keymap.set('n', '<leader>tt', function()
        require('neotest').run.run()
      end, { desc = 'Run nearest test' })

      vim.keymap.set('n', '<leader>tf', function()
        require('neotest').run.run(vim.fn.expand '%')
      end, { desc = 'Run all tests in file' })

      vim.keymap.set('n', '<leader>td', function()
        require('neotest').run.run { strategy = 'dap' }
      end, { desc = 'Debug nearest test' })

      vim.keymap.set('n', '<leader>ts', function()
        require('neotest').summary.toggle()
      end, { desc = 'Toggle test summary panel' })

      vim.keymap.set('n', '<leader>to', function()
        require('neotest').output.open { enter = true }
      end, { desc = 'Show test output' })

      vim.keymap.set('n', '<leader>ta', function()
        require('neotest').run.run(vim.fn.getcwd())
      end, { desc = 'Run all tests in project' })
    end,
  },
}
