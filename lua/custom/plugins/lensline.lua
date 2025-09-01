return {
  'oribarilan/lensline.nvim',
  tag = '1.0.0', -- or: branch = 'release/1.x' for latest non-breaking updates
  event = 'LspAttach',
  config = function()
    require('lensline').setup {
      providers = {
        { name = 'references', enabled = true },
        { name = 'last_author', enabled = true },
        { name = 'complexity', enabled = false },
        { name = 'diagnostics', enabled = true },

        {
          name = 'roslyn_tests',
          enabled = true,
          event = { 'LspAttach', 'BufWritePost', 'CursorHold' },

          -- Show ONLY "n/m tests passed" above each function
          handler = function(bufnr, func_info, provider_config, callback)
            local api = vim.api
            local params = vim.lsp.util.make_text_document_params(bufnr)

            -- Ask any LSP client attached to this buffer for CodeLens
            vim.lsp.buf_request(bufnr, 'textDocument/codeLens', { textDocument = params }, function(err, result, ctx, _)
              if err or not result then
                return callback(nil)
              end

              -- Find lenses that lie on the function's signature line (or inside its range if you prefer)
              local fline = func_info.line
              local best_title = nil

              for _, lens in ipairs(result) do
                local r = lens.range or {}
                local s = r.start or {}
                local line = s.line
                if line == fline or (line and func_info.end_line and line >= fline and line <= func_info.end_line) then
                  -- Pull titles from either `command` or `commands`
                  local titles = {}
                  if lens.command and lens.command.title then
                    table.insert(titles, lens.command.title)
                  elseif lens.commands then
                    for _, cmd in ipairs(lens.commands) do
                      if cmd and cmd.title then
                        table.insert(titles, cmd.title)
                      end
                    end
                  end

                  -- Prefer a title that looks like "3/4 tests passed", “passed”, “failed”, etc.
                  for _, t in ipairs(titles) do
                    local low = t:lower()
                    if low:find '%d+%s*/%s*%d+%s*tests?' or low:find 'tests?%s+passed' or low:find 'passed' or low:find 'failed' then
                      best_title = t
                      break
                    end
                  end

                  if best_title then
                    break
                  end
                end
              end

              if not best_title then
                return callback(nil)
              end

              -- Choose highlight by pass/fail
              local hl = 'LspCodeLens'
              local low = best_title:lower()
              if low:find 'fail' then
                hl = 'DiagnosticError'
              elseif low:find 'pass' or low:find '%d+%s*/%s*%d+' then
                hl = vim.fn.hlexists 'DiagnosticOk' == 1 and 'DiagnosticOk' or 'DiagnosticHint'
              end

              callback {
                line = func_info.line,
                text = best_title,
                highlight = hl,
              }
            end)
          end,
        },
        style = {
          separator = ' • ', -- separator between all lens attributes
          highlight = 'Comment', -- highlight group for lens text
          prefix = '┃ ', -- prefix before lens content
          placement = 'above', -- "above" | "inline" - where to render lenses (consider prefix = "" for inline)
          use_nerdfont = true, -- enable nerd font icons in built-in providers
        },
      },
    }
  end,
}
