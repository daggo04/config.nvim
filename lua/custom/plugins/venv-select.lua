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

    -- Create a module to expose functions for linter integration and auto-detection
    local M = {}
    _G.venv_utils = M

    -- Track notifications to avoid spam
    local linter_status_notified = {}
    local last_detected_env = nil

    -- =============================================================================
    -- ENVIRONMENT DETECTION CHAIN
    -- =============================================================================
    -- Easy to extend: add new detectors here in order of preference
    -- Each detector should return a python executable path or nil

    -- 1. TERMINAL INHERITANCE DETECTOR
    -- Checks if there's an active virtual environment from the terminal session
    local function detect_terminal_environment()
      -- First check VIRTUAL_ENV (standard virtualenv/venv variable)
      local virtual_env = os.getenv 'VIRTUAL_ENV'
      if virtual_env then
        local python_path = virtual_env .. '/bin/python'
        if vim.fn.filereadable(python_path) == 1 then
          return python_path, 'terminal (VIRTUAL_ENV)'
        end
      end

      -- Fallback: check pyenv current (if pyenv is being used)
      local handle = io.popen 'pyenv which python 2>/dev/null'
      if handle then
        local pyenv_python = handle:read('*a'):gsub('%s+', '') -- trim whitespace
        handle:close()
        if pyenv_python and pyenv_python ~= '' and vim.fn.filereadable(pyenv_python) == 1 then
          return pyenv_python, 'terminal (pyenv current)'
        end
      end

      return nil, nil
    end

    -- 2. PROJECT .python-version FILE DETECTOR
    -- Checks for .python-version file (pyenv local) and resolves it to python path
    local function detect_python_version_file()
      local python_version_file = vim.fn.getcwd() .. '/.python-version'
      if vim.fn.filereadable(python_version_file) == 1 then
        local version = vim.fn.readfile(python_version_file)[1]
        if version then
          version = version:gsub('%s+', '') -- trim whitespace

          -- Try to resolve via pyenv (most common case)
          local handle = io.popen('pyenv prefix ' .. version .. ' 2>/dev/null')
          if handle then
            local pyenv_prefix = handle:read('*a'):gsub('%s+', '')
            handle:close()
            if pyenv_prefix and pyenv_prefix ~= '' then
              local python_path = pyenv_prefix .. '/bin/python'
              if vim.fn.filereadable(python_path) == 1 then
                return python_path, '.python-version (' .. version .. ')'
              end
            end
          end
        end
      end
      return nil, nil
    end

    -- 3. FUTURE DETECTORS - Easy to add more!
    -- Example detectors you can uncomment/modify as needed:

    -- local function detect_poetry_environment()
    --   local poetry_lock = vim.fn.getcwd() .. '/poetry.lock'
    --   if vim.fn.filereadable(poetry_lock) == 1 then
    --     local handle = io.popen('cd ' .. vim.fn.getcwd() .. ' && poetry env info --path 2>/dev/null')
    --     if handle then
    --       local poetry_path = handle:read('*a'):gsub('%s+', '')
    --       handle:close()
    --       if poetry_path and poetry_path ~= '' then
    --         local python_path = poetry_path .. '/bin/python'
    --         if vim.fn.filereadable(python_path) == 1 then
    --           return python_path, 'poetry environment'
    --         end
    --       end
    --     end
    --   end
    --   return nil, nil
    -- end

    -- local function detect_pipfile_environment()
    --   local pipfile = vim.fn.getcwd() .. '/Pipfile'
    --   if vim.fn.filereadable(pipfile) == 1 then
    --     -- Add pipenv detection logic here
    --   end
    --   return nil, nil
    -- end

    -- local function detect_local_venv()
    --   -- Check for common local venv directory names
    --   for _, venv_dir in ipairs({'.venv', 'venv', '.env'}) do
    --     local python_path = vim.fn.getcwd() .. '/' .. venv_dir .. '/bin/python'
    --     if vim.fn.filereadable(python_path) == 1 then
    --       return python_path, 'local venv (' .. venv_dir .. ')'
    --     end
    --   end
    --   return nil, nil
    -- end

    -- MAIN DETECTION FUNCTION
    -- Runs through all detectors in order until one succeeds
    function M.auto_detect_environment()
      -- Detection chain - order matters! Earlier detectors have higher priority
      local detectors = {
        detect_python_version_file, -- Project override takes precedence
        detect_terminal_environment, -- Fall back to terminal environment
        -- detect_poetry_environment, -- Uncomment to enable poetry detection
        -- detect_pipfile_environment, -- Uncomment to enable pipenv detection
        -- detect_local_venv,         -- Uncomment to check for local venv dirs
      }

      local detected_python = nil
      local detection_source = nil

      -- Run through detectors until we find one that works
      for _, detector in ipairs(detectors) do
        detected_python, detection_source = detector()
        if detected_python then
          break
        end
      end

      -- Handle detection results
      if detected_python then
        -- Only switch if we detected something different
        local current_python = require('venv-selector').python()
        if current_python ~= detected_python then
          -- Set the detected environment
          require('venv-selector').set_venv_and_system_python(detected_python)

          -- Show success notification
          mini_notifier('Auto-detected Python environment: ' .. detection_source, vim.log.levels.INFO)

          -- Configure linting and LSP for the new environment
          M.configure_python_linting()
          M.configure_python_lsp()

          last_detected_env = detected_python
        end
      else
        -- No environment detected, check if we had one before
        if last_detected_env then
          mini_notifier('No Python environment detected for project. Keeping previous environment.', vim.log.levels.WARN)
        end
      end

      return detected_python ~= nil
    end

    -- =============================================================================
    -- LINTING CONFIGURATION
    -- =============================================================================

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
        require('lint').linters_by_ft.python = { available_linters[1] }
      else
        -- Fall back to basic linting
        require('lint').linters_by_ft.python = { 'pylint' }
      end

      return #available_linters > 0
    end

    -- =============================================================================
    -- LSP CONFIGURATION
    -- =============================================================================

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

        -- Restart the LSP for current buffer if it's a Python file
        if vim.bo.filetype == 'python' then
          vim.cmd 'LspRestart pyright'
        end
      end
    end

    -- =============================================================================
    -- VENV-SELECTOR SETUP
    -- =============================================================================

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
          save_file_name = '.venv-selector',

          -- Configure both linting AND LSP after venv activation
          on_venv_activate_callback = function()
            M.configure_python_linting()
            M.configure_python_lsp()
          end,

          search_timeout = 10,
        },
      },
    }

    -- =============================================================================
    -- AUTO-DETECTION AUTOCOMMANDS
    -- =============================================================================

    local venv_augroup = vim.api.nvim_create_augroup('venv_selector_integration', { clear = true })

    -- Auto-detect when entering Python files
    vim.api.nvim_create_autocmd({ 'FileType' }, {
      pattern = { 'python' },
      group = venv_augroup,
      callback = function()
        vim.defer_fn(function()
          M.auto_detect_environment()
        end, 100) -- Small delay to ensure everything is loaded
      end,
    })

    -- Auto-detect when changing directories (for when you open new projects)
    vim.api.nvim_create_autocmd({ 'DirChanged' }, {
      group = venv_augroup,
      callback = function()
        -- Only run if we're in a directory that might be a Python project
        local has_python_files = vim.fn.glob '*.py' ~= ''
          or vim.fn.filereadable '.python-version' == 1
          or vim.fn.filereadable 'pyproject.toml' == 1
          or vim.fn.filereadable 'requirements.txt' == 1

        if has_python_files then
          M.auto_detect_environment()
        end
      end,
    })
  end,
  keys = {
    { '<leader>vs', '<cmd>VenvSelect<cr>', desc = 'Select Python Venv' },
    {
      '<leader>va',
      function()
        _G.venv_utils.auto_detect_environment()
      end,
      desc = 'Auto-detect Python Venv',
    },
  },
}
