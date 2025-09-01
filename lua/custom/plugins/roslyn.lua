return {
  'seblj/roslyn.nvim',
  ft = 'cs',
  config = function()
    require('roslyn').setup {}

    -- Your highlights
    vim.api.nvim_set_hl(0, 'LspCodeLens', { fg = '#7C7C7C', italic = true, bg = 'NONE' })
    vim.api.nvim_set_hl(0, 'LspCodeLensSeparator', { fg = '#7C7C7C' })

    -- Roslyn settings (keep as-is)
    vim.lsp.config('roslyn', {
      settings = {
        ['csharp|inlay_hints'] = {
          csharp_enable_inlay_hints_for_implicit_variable_types = true,
          csharp_enable_inlay_hints_for_lambda_parameter_types = true,
          csharp_enable_inlay_hints_for_types = true,
        },
        ['csharp|code_lens'] = {
          dotnet_enable_references_code_lens = true,
          dotnet_enable_tests_code_lens = true,
        },
      },
    })

    -- Auto-refresh code lens on save and exit insert mode
    vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufEnter', 'InsertLeave' }, {
      pattern = '*.cs',
      callback = function()
        vim.lsp.codelens.refresh()
      end,
    })
  end,
}
