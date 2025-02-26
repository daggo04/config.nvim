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
    local mypy_status_notified = {}

    -- Function to check if mypy is available and configure the linter accordingly
    function M.configure_python_linting()
      local venv_python = require('venv-selector').python()
      local buffer_path = vim.api.nvim_buf_get_name(0)

      -- Handle case when no venv is activated
      if not venv_python then
        -- Reset to default linting (pyright only)
        require('lint').linters_by_ft.python = { 'pyright' }
        return false
      end

      local venv_dir = vim.fn.fnamemodify(venv_python, ':h:h')
      local is_windows = vim.fn.has 'win32' == 1

      -- Check for mypy in bin directory (Unix) or Scripts directory (Windows)
      local mypy_path = is_windows and venv_dir .. '\\Scripts\\mypy.exe' or venv_dir .. '/bin/mypy'
      local has_mypy = vim.fn.filereadable(mypy_path) == 1

      -- Configure linting based on mypy availability
      if has_mypy then
        -- Configure with mypy
        require('lint').linters_by_ft.python = { 'mypy' }

        -- Only notify if we haven't already
        if not mypy_status_notified[buffer_path] or mypy_status_notified[buffer_path] ~= 'mypy' then
          mini_notifier('Mypy detected in environment - Using it for linting', vim.log.levels.INFO)
          mypy_status_notified[buffer_path] = 'mypy'
        end
      else
        -- Fall back to pyright only
        require('lint').linters_by_ft.python = { 'pyright' }

        -- Only notify if we haven't already
        if not mypy_status_notified[buffer_path] or mypy_status_notified[buffer_path] ~= 'no_mypy' then
          mini_notifier(
            "Mypy not detected in the active virtual environment. Using pyright instead. Install mypy with 'pip install mypy' for type checking.",
            vim.log.levels.WARN
          )
          mypy_status_notified[buffer_path] = 'no_mypy'
        end
      end

      return has_mypy
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

          -- Configure linting after venv activation
          on_venv_activate_callback = function()
            M.configure_python_linting()
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

    -- Create autocommands to check mypy when buffer is loaded or filetype is set
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
