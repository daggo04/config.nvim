return {
  { -- Linting
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'
      local uv = vim.uv or vim.loop -- For file checking

      -- Create a custom mypy linter that uses poetry
      lint.linters.poetry_mypy = {
        name = 'poetry_mypy',
        cmd = 'poetry',
        args = { 'run', 'mypy' },
        stdin = false,
        append_fname = true,
        stream = 'stdout',
        ignore_exitcode = false,
        env = nil,
        parser = lint.linters.mypy.parser,
      }

      -- Track if we've already shown the mypy missing message for this session
      local mypy_missing_notified = {}

      -- Function to determine which mypy to use based on project
      local function get_mypy_linter()
        local current_file = vim.fn.expand '%:p'
        local file_dir = vim.fn.fnamemodify(current_file, ':h')

        -- Try to find pyproject.toml by going up directories
        local dir = file_dir
        while dir ~= '/' do
          if uv.fs_stat(dir .. '/pyproject.toml') or uv.fs_stat(dir .. '/poetry.lock') then
            -- We found a poetry project - now ensure mypy is installed
            local check_output = vim.fn.system('cd "' .. dir .. '" && poetry show | grep -i "mypy "')
            -- Use vim.trim to handle potential whitespace and improve the check
            if check_output and vim.trim(check_output) ~= '' then
              -- mypy is installed in this poetry environment
              lint.linters.poetry_mypy.cwd = dir -- Set the working directory
              return 'poetry_mypy'
            else
              -- mypy not found in poetry, show notification if we haven't already
              if not mypy_missing_notified[dir] then
                vim.notify(
                  'Poetry project detected, but mypy is not installed.\n'
                    .. 'For better pydantic type checking, consider installing mypy:\n'
                    .. 'poetry add --group dev mypy\n\n'
                    .. 'Then add to your pyproject.toml:\n'
                    .. '[tool.mypy]\n'
                    .. 'plugins = [\n'
                    .. '  "pydantic.mypy"\n'
                    .. ']\n'
                    .. 'follow_imports = "silent"\n'
                    .. 'warn_redundant_casts = true\n'
                    .. 'warn_unused_ignores = true\n'
                    .. 'disallow_any_generics = true\n'
                    .. 'check_untyped_defs = true\n'
                    .. 'disallow_untyped_defs = true\n'
                    .. '\n'
                    .. '[tool.pydantic-mypy]\n'
                    .. 'init_forbid_extra = true\n'
                    .. 'init_typed = true\n'
                    .. 'warn_required_dynamic_aliases = true',
                  vim.log.levels.WARN,
                  { title = 'Linting Setup' }
                )
                mypy_missing_notified[dir] = true
              end

              -- Fall back to global
              return 'mypy'
            end
          end
          -- Go up one directory
          dir = vim.fn.fnamemodify(dir, ':h')
        end

        -- No poetry project found or no mypy in poetry, use global
        return 'mypy'
      end

      -- Initialize linters_by_ft with the result of get_mypy_linter()
      local python_linter = get_mypy_linter()
      lint.linters_by_ft = {
        markdown = { 'markdownlint' },
        python = { python_linter },
      }

      -- Create autocommand which carries out the actual linting
      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          -- Refresh the linter selection in case we've changed projects
          lint.linters_by_ft.python = { get_mypy_linter() }

          -- Only run the linter in buffers that you can modify
          if vim.opt_local.modifiable:get() then
            lint.try_lint()
          end
        end,
      })
    end,
  },
}
