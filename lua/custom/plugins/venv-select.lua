return {
  'linux-cultist/venv-selector.nvim',
  dependencies = {
    'neovim/nvim-lspconfig',
    'mfussenegger/nvim-dap',
    'mfussenegger/nvim-dap-python',
    { 'nvim-telescope/telescope.nvim', dependencies = { 'nvim-lua/plenary.nvim' } },
  },
  branch = 'regexp',
  config = function()
    -- Function to display shorter names in the telescope UI
    local function shorter_venv_name(filename)
      return filename:gsub(os.getenv 'HOME', '~'):gsub('/bin/python', '')
    end

    -- Function to check if mypy is available in the current venv
    local mypy_missing_notified = {}
    local function check_mypy_available()
      local venv_python = require('venv-selector').python()
      if not venv_python then
        return
      end

      local venv_dir = vim.fn.fnamemodify(venv_python, ':h:h')
      local buffer_path = vim.api.nvim_buf_get_name(0)
      local is_windows = vim.fn.has 'win32' == 1

      -- Check for mypy in bin directory (Unix) or Scripts directory (Windows)
      local mypy_path = is_windows and venv_dir .. '\\Scripts\\mypy.exe' or venv_dir .. '/bin/mypy'

      local has_mypy = vim.fn.filereadable(mypy_path) == 1

      if not has_mypy and not mypy_missing_notified[buffer_path] then
        vim.notify(
          "mypy is not installed in the active virtual environment. Install it with 'pip install mypy' for type checking.",
          vim.log.levels.WARN,
          { title = 'Python Environment' }
        )
        mypy_missing_notified[buffer_path] = true
      end
      if has_mypy then
        vim.notify 'Mypy detected in env: Setting linter to Mypy'
      end
    end

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

          -- Function to run after a venv is activated
          on_venv_activate_callback = check_mypy_available,

          -- Customize search timeout if searches are taking too long
          search_timeout = 10,
        },
        search = {
          -- Disable the default workspace search if it's too slow
          -- workspace = false,

          -- Add custom search locations if needed
          -- my_venvs = {
          --   command = "fd 'python$' ~/dev --full-path -I",
          -- },
        },
      },
    }
  end,
  keys = {
    { '<leader>vs', '<cmd>VenvSelect<cr>', desc = 'Select Python Venv' },
  },
}
