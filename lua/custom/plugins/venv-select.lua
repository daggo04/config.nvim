return {
  'linux-cultist/venv-selector.nvim',
  dependencies = {
    'neovim/nvim-lspconfig',
    'mfussenegger/nvim-dap',
    'mfussenegger/nvim-dap-python',
    'mfussenegger/nvim-lint',
    { 'nvim-telescope/telescope.nvim', dependencies = { 'nvim-lua/plenary.nvim' } },
  },
  branch = 'regexp',
  config = function()
    -- Function to display shorter names in the telescope UI
    local function shorter_venv_name(filename)
      return filename:gsub(os.getenv 'HOME', '~'):gsub('/bin/python', '')
    end

    -- Get mini.notify's auto-dismissing notifications
    local mini_notifier = require('mini.notify').make_notify()

    -- Create a module to expose functions for linter integration
    local M = {}
    _G.venv_utils = M

    -- Track already notified buffers to avoid spam
    local linter_status_notified = {}

    -- Function to check available linters and configure accordingly
    function M.configure_python_linting()
      local venv_python = require('venv-selector').python()
      local buffer_path = vim.api.nvim_buf_get_name(0)

      -- Handle case when no venv is activated
      if not venv_python then
        -- Use basic linters that don't require venv
        require('lint').linters_by_ft.python = { 'pylint' }
        return false
      end

      local venv_dir = vim.fn.fnamemodify(venv_python, ':h:h')
      local is_windows = vim.fn.has 'win32' == 1

      -- Check for various Python linters in the venv
      local linters_to_check = {
        ruff = is_windows and venv_dir .. '\\Scripts\\ruff.exe' or venv_dir .. '/bin/ruff',
        flake8 = is_windows and venv_dir .. '\\Scripts\\flake8.exe' or venv_dir .. '/bin/flake8',
        pylint = is_windows and venv_dir .. '\\Scripts\\pylint.exe' or venv_dir .. '/bin/pylint',
        mypy = is_windows and venv_dir .. '\\Scripts\\mypy.exe' or venv_dir .. '/bin/mypy',
      }

      local available_linters = {}
      local preferred_order = { 'ruff', 'flake8', 'pylint', 'mypy' }

      -- Check which linters are available
      for linter, path in pairs(linters_to_check) do
        if vim.fn.filereadable(path) == 1 then
          table.insert(available_linters, linter)
        end
      end

      -- Sort by preference
      table.sort(available_linters, function(a, b)
        local a_idx = vim.tbl_contains(preferred_order, a) and vim.fn.index(preferred_order, a) or 999
        local b_idx = vim.tbl_contains(preferred_order, b) and vim.fn.index(preferred_order, b) or 999
        return a_idx < b_idx
      end)

      -- Configure linting based on available linters
      if #available_linters > 0 then
        -- Use the best available linter(s)
        require('lint').linters_by_ft.python = { available_linters[1] }

        local linter_list = table.concat(available_linters, ', ')
        local status_key = 'linters_' .. table.concat(available_linters, '_')

        if not linter_status_notified[buffer_path] or linter_status_notified[buffer_path] ~= status_key then
          mini_notifier(string.format('Python linters detected: %s. Using %s for linting.', linter_list, available_linters[1]), vim.log.levels.INFO)
          linter_status_notified[buffer_path] = status_key
        end
      else
        -- Fall back to basic linting
        require('lint').linters_by_ft.python = { 'pylint' }

        if not linter_status_notified[buffer_path] or linter_status_notified[buffer_path] ~= 'no_linters' then
          mini_notifier('No Python linters detected in venv. Install linters like ruff, flake8, or pylint for better code analysis.', vim.log.levels.WARN)
          linter_status_notified[buffer_path] = 'no_linters'
        end
      end

      return #available_linters > 0
    end

    -- Function to update LSP settings when venv changes
    function M.configure_python_lsp()
      local venv_python = require('venv-selector').python()

      if venv_python then
        -- Update pyright to use the selected Python interpreter
        local lspconfig = require 'lspconfig'

        -- Restart pyright with new Python path
        lspconfig.pyright.setup {
          settings = {
            python = {
              pythonPath = venv_python,
            },
          },
        }

        -- Restart the LSP for current buffer
        vim.cmd 'LspRestart pyright'
      end
    end

    -- Setup venv-selector
    require('venv-selector').setup {
      settings = {
        options = {
          -- Show nicer names in the telescope UI
          on_telescope_result_callback = shorter_venv_name,

          -- Show notification when venv is activated
          notify_user_on_venv_activation = true,

          -- Cache used envs
          enable_cached_venvs = true,
          cached_venv_automatic_activation = true,

          -- Save selected venv to project directory
          auto_save_venv = true,
          -- Name of the file that stores the venv path
          save_file_name = '.venv-selector',

          -- Configure both linting AND LSP after venv activation
          on_venv_activate_callback = function()
            M.configure_python_linting()
            M.configure_python_lsp()
          end,

          -- Customize search timeout if searches are taking too long
          search_timeout = 10,
        },
        search = {
          -- You can uncomment and customize these as needed
          -- workspace = false,
          -- my_venvs = {
          --   command = "fd 'python$' ~/dev --full-path -I",
          -- },
        },
      },
    }

    -- Create autocommands to check linters when buffer is loaded or filetype is set
    local venv_augroup = vim.api.nvim_create_augroup('venv_selector_integration', { clear = true })

    vim.api.nvim_create_autocmd({ 'FileType' }, {
      pattern = { 'python' },
      group = venv_augroup,
      callback = function()
        -- Configure linting when entering a Python buffer
        vim.defer_fn(function()
          M.configure_python_linting()
        end, 100) -- Small delay to ensure venv is loaded
      end,
    })
  end,
  keys = {
    { '<leader>vs', '<cmd>VenvSelect<cr>', desc = 'Select Python Venv' },
  },
}
