return {
  { -- Linting
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'

      -- Initial configuration - will be dynamically updated by venv-selector
      lint.linters_by_ft = {
        markdown = { 'markdownlint' },
        python = {}, -- Updated dynamically by the venv-select plugin in venv-select.lua
      }

      -- Create autocommand for linting
      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          -- Only run the linter in buffers that you can modify
          if vim.opt_local.modifiable:get() then
            -- For Python files, check and configure mypy before linting
            if vim.bo.filetype == 'python' and _G.venv_utils then
              -- Reconfigure linting based on current environment
              _G.venv_utils.configure_python_linting()
            end

            -- Run linting with the configured settings
            lint.try_lint()
          end
        end,
      })
    end,
  },
}
