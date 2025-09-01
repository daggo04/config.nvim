-- Git signs in the gutter and inline blame
return {
  'lewis6991/gitsigns.nvim',
  event = { 'BufReadPre', 'BufNewFile' },
  config = function()
    -- Get colors from the current theme
    local function get_hl_color(hl_group, attr)
      local hl = vim.api.nvim_get_hl(0, { name = hl_group })
      return hl[attr] and string.format('#%06x', hl[attr]) or nil
    end

    -- Use an autocmd to set colors after colorscheme is loaded
    vim.api.nvim_create_autocmd('ColorScheme', {
      callback = function()
        -- Get theme colors - fallback to defaults if not available
        local add_color = get_hl_color('DiffAdd', 'fg') or get_hl_color('String', 'fg') or '#a6e3a1'
        local change_color = get_hl_color('DiffChange', 'fg') or get_hl_color('Function', 'fg') or '#f9e2af'
        local delete_color = get_hl_color('DiffDelete', 'fg') or get_hl_color('Error', 'fg') or '#f38ba8'

        -- Apply theme colors to GitSigns
        vim.api.nvim_set_hl(0, 'GitSignsAdd', { fg = add_color })
        vim.api.nvim_set_hl(0, 'GitSignsChange', { fg = add_color })
        vim.api.nvim_set_hl(0, 'GitSignsDelete', { fg = delete_color })
        vim.api.nvim_set_hl(0, 'GitSignsChangedelete', { fg = add_color })
        vim.api.nvim_set_hl(0, 'GitSignsTopdelete', { fg = delete_color })
      end,
    })

    -- Set initial colors
    vim.schedule(function()
      vim.cmd 'doautocmd ColorScheme'
    end)

    require('gitsigns').setup {
      signs = {
        add = { text = '┃' },
        change = { text = '┆' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
        untracked = { text = '┆' },
      },
      signs_staged = {
        add = { text = '┃' },
        change = { text = '┆' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
        untracked = { text = '?' },
      },

      on_attach = function(bufnr)
        local gitsigns = require 'gitsigns'

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map('n', ']c', function()
          if vim.wo.diff then
            vim.cmd.normal { ']c', bang = true }
          else
            gitsigns.nav_hunk 'next'
          end
        end, { desc = 'Jump to next git [c]hange' })

        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal { '[c', bang = true }
          else
            gitsigns.nav_hunk 'prev'
          end
        end, { desc = 'Jump to previous git [c]hange' })

        -- Actions
        -- visual mode
        map('v', '<leader>hs', function()
          gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'git [s]tage hunk' })
        map('v', '<leader>hr', function()
          gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'git [r]eset hunk' })
        -- normal mode
        map('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'git [s]tage hunk' })
        map('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'git [r]eset hunk' })
        map('n', '<leader>hS', gitsigns.stage_buffer, { desc = 'git [S]tage buffer' })
        map('n', '<leader>hu', gitsigns.stage_hunk, { desc = 'git [u]ndo stage hunk' })
        map('n', '<leader>hR', gitsigns.reset_buffer, { desc = 'git [R]eset buffer' })
        map('n', '<leader>hp', gitsigns.preview_hunk, { desc = 'git [p]review hunk' })
        map('n', '<leader>hb', gitsigns.blame_line, { desc = 'git [b]lame line' })
        map('n', '<leader>hd', gitsigns.diffthis, { desc = 'git [d]iff against index' })
        map('n', '<leader>hD', function()
          gitsigns.diffthis '@'
        end, { desc = 'git [D]iff against last commit' })
        -- Toggles
        map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line' })
        map('n', '<leader>tD', gitsigns.preview_hunk_inline, { desc = '[T]oggle git show [D]eleted' })
      end,
    }
  end,
}
