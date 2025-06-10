-- Simple Python environment detection and LSP configuration
-- Replaces venv-selector with direct environment inheritance

local M = {}

-- Get notifications
local mini_notifier = require('mini.notify').make_notify()

-- Track current Python path to avoid unnecessary reconfigurations
local current_python_path = nil
local linter_notifications = {}

-- =============================================================================
-- PYTHON ENVIRONMENT DETECTION
-- =============================================================================

function M.get_python_path()
  -- 1. Check if there's an activated virtual environment in terminal
  if vim.env.VIRTUAL_ENV then
    local venv_python = vim.env.VIRTUAL_ENV .. '/bin/python'
    if vim.fn.filereadable(venv_python) == 1 then
      return venv_python, 'terminal VIRTUAL_ENV'
    end
  end

  -- 2. Check for project-specific .python-version file (pyenv local)
  local python_version_file = vim.fn.getcwd() .. '/.python-version'
  if vim.fn.filereadable(python_version_file) == 1 then
    local version = vim.fn.readfile(python_version_file)[1]
    if version then
      version = version:gsub('%s+', '') -- trim whitespace
      
      -- Try to resolve via pyenv
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

  -- 3. Fall back to pyenv current
  local handle = io.popen('pyenv which python 2>/dev/null')
  if handle then
    local pyenv_python = handle:read('*a'):gsub('%s+', '')
    handle:close()
    if pyenv_python and pyenv_python ~= '' and vim.fn.filereadable(pyenv_python) == 1 then
      return pyenv_python, 'pyenv current'
    end
  end

  -- 4. System default
  local system_python = vim.fn.exepath('python3') or vim.fn.exepath('python')
  if system_python then
    return system_python, 'system python'
  end

  return nil, 'no python found'
end

-- =============================================================================
-- LINTER CONFIGURATION
-- =============================================================================

function M.configure_linters(python_path)
  if not python_path then
    require('lint').linters_by_ft.python = {}
    return
  end

  local venv_dir = vim.fn.fnamemodify(python_path, ':h:h')
  local is_windows = vim.fn.has('win32') == 1

  -- Check for linters in the environment
  local linters_to_check = {
    ruff = is_windows and venv_dir .. '\\Scripts\\ruff.exe' or venv_dir .. '/bin/ruff',
    flake8 = is_windows and venv_dir .. '\\Scripts\\flake8.exe' or venv_dir .. '/bin/flake8',
    pylint = is_windows and venv_dir .. '\\Scripts\\pylint.exe' or venv_dir .. '/bin/pylint',
    mypy = is_windows and venv_dir .. '\\Scripts\\mypy.exe' or venv_dir .. '/bin/mypy',
  }

  local available_linters = {}
  local preferred_order = { 'ruff', 'flake8', 'pylint', 'mypy' }

  for linter, path in pairs(linters_to_check) do
    if vim.fn.filereadable(path) == 1 then
      table.insert(available_linters, linter)
    end
  end

  -- Sort by preference
  table.sort(available_linters, function(a, b)
    local a_idx = vim.fn.index(preferred_order, a)
    local b_idx = vim.fn.index(preferred_order, b)
    a_idx = a_idx == -1 and 999 or a_idx
    b_idx = b_idx == -1 and 999 or b_idx
    return a_idx < b_idx
  end)

  if #available_linters > 0 then
    require('lint').linters_by_ft.python = { available_linters[1] }
    
    local buffer_path = vim.api.nvim_buf_get_name(0)
    local status_key = table.concat(available_linters, '_')
    
    if not linter_notifications[buffer_path] or linter_notifications[buffer_path] ~= status_key then
      mini_notifier('Using ' .. available_linters[1] .. ' for Python linting', vim.log.levels.INFO)
      linter_notifications[buffer_path] = status_key
    end
  else
    require('lint').linters_by_ft.python = {}
  end
end

-- =============================================================================
-- LSP CONFIGURATION
-- =============================================================================

function M.configure_pyright(python_path, source)
  if not python_path then
    return
  end

  -- Only reconfigure if Python path changed
  if current_python_path == python_path then
    return
  end

  current_python_path = python_path
  mini_notifier('Configuring Pyright with: ' .. source, vim.log.levels.INFO)

  -- Configure pyright with the detected Python path
  local lspconfig = require('lspconfig')
  
  -- Stop existing pyright clients
  local clients = vim.lsp.get_clients({ name = 'pyright' })
  for _, client in ipairs(clients) do
    client.stop()
  end

  -- Wait a bit for clients to stop, then start with new config
  vim.defer_fn(function()
    lspconfig.pyright.setup({
      root_dir = require('lspconfig.util').root_pattern('.git', 'pyproject.toml', 'setup.py', '.python-version', 'requirements.txt'),
      settings = {
        python = {
          pythonPath = python_path,
          analysis = {
            autoSearchPaths = true,
            useLibraryCodeForTypes = true,
            diagnosticMode = 'workspace',
          },
        },
      },
    })

    -- Start LSP if we're in a Python file
    if vim.bo.filetype == 'python' then
      vim.cmd('LspStart pyright')
    end
  end, 500)
end

-- =============================================================================
-- MAIN CONFIGURATION FUNCTION
-- =============================================================================

function M.setup_python_environment()
  local python_path, source = M.get_python_path()
  
  if python_path then
    M.configure_pyright(python_path, source)
    M.configure_linters(python_path)
  end
  
  return python_path ~= nil
end

-- =============================================================================
-- AUTO-DETECTION SETUP
-- =============================================================================

local function setup_autocommands()
  local augroup = vim.api.nvim_create_augroup('python_env_detection', { clear = true })

  -- Detect when opening Python files
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'python',
    group = augroup,
    callback = function()
      vim.defer_fn(M.setup_python_environment, 100)
    end,
  })

  -- Detect when changing directories
  vim.api.nvim_create_autocmd('DirChanged', {
    group = augroup,
    callback = function()
      -- Only run if this looks like a Python project
      local has_python_indicators = vim.fn.glob('*.py') ~= ''
        or vim.fn.filereadable('.python-version') == 1
        or vim.fn.filereadable('pyproject.toml') == 1
        or vim.fn.filereadable('requirements.txt') == 1

      if has_python_indicators then
        current_python_path = nil -- Reset to force reconfiguration
        M.setup_python_environment()
      end
    end,
  })
end

-- =============================================================================
-- KEYMAPS
-- =============================================================================

local function setup_keymaps()
  vim.keymap.set('n', '<leader>pe', M.setup_python_environment, { desc = 'Detect Python Environment' })
  vim.keymap.set('n', '<leader>pp', function()
    local python_path, source = M.get_python_path()
    if python_path then
      mini_notifier('Active Python: ' .. python_path .. ' (' .. source .. ')', vim.log.levels.INFO)
    else
      mini_notifier('No Python environment detected', vim.log.levels.WARN)
    end
  end, { desc = 'Show Python Environment' })
end

-- =============================================================================
-- PLUGIN SETUP
-- =============================================================================

-- Return a plugin spec for lazy.nvim
return {
  -- This is a local configuration plugin (no actual plugin to install)
  dir = '.',
  name = 'python-env',
  lazy = false,
  config = function()
    setup_autocommands()
    setup_keymaps()
  end,
}