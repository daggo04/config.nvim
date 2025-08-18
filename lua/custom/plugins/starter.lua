-- lua/custom/plugins/starter.lua
return {
  {
    'echasnovski/mini.starter',
    version = false,
    event = 'VimEnter',
    config = function()
      local starter = require('mini.starter')

      -- ───────── helpers ─────────

      -- 1) Lazy stats
      local function lazy_stats()
        local ok, lazy = pcall(require, 'lazy')
        if not ok then
          return ''
        end
        local s = lazy.stats()
        local st = s.startuptime or s.startup_time
        local loaded = s.loaded or s.count or 0
        local total = s.count or loaded
        return st and string.format('⚡ %d/%d plugins in %.2f ms', loaded, total, st) or string.format('⚡ %d plugins', total)
      end

      -- 2) Weather widget
      local weather = require('custom.widgets.weather')
      weather.setup({
        city = 'Stavanger',
        top_row = 0,
        center = true,
        zindex = 200,
      })

      -- 4) Your ASCII title
      local v = vim.version()
      local title = string.format([[
      ___           ___           ___                         ___           ___     
     /\  \         /\__\         /\  \         _____         /\  \         /\__\    
     \:\  \       /:/ _/_       /::\  \       /::\  \       /::\  \       /:/ _/_   
      \:\  \     /:/ /\__\     /:/\:\  \     /:/\:\  \     /:/\:\  \     /:/ /\  \  
  _____\:\  \   /:/ /:/ _/_   /:/  \:\  \   /:/  \:\__\   /:/ /::\  \   /:/ /::\  \ 
 /::::::::\__\ /:/_/:/ /\__\ /:/__/ \:\__\ /:/__/ \:|__| /:/_/:/\:\__\ /:/__\/\:\__\
 \:\--\--\/__/ \:\/:/ /:/  / \:\  \ /:/  / \:\  \ /:/  / \:\/:/  \/__/ \:\  \ /:/  /
  \:\  \        \::/_/:/  /   \:\  /:/  /   \:\  /:/  /   \::/__/       \:\  /:/  / 
   \:\  \        \:\/:/  /     \:\/:/  /     \:\/:/  /     \:\  \        \:\/:/  /  
    \:\__\        \::/  /       \::/  /       \::/  /       \:\__\        \::/  /   
     \/__/         \/__/         \/__/         \/__/         \/__/         \/__/    

Neovim %d.%d.%d  —  %s
      ]], v.major, v.minor, v.patch, os.date('%Y-%m-%d'))

      -- Make header with just the title
      local function make_header()
        return title
      end

      -- ───────── mini.starter setup ─────────
      starter.setup({
        header = make_header, -- function: recomputed on :StarterRefresh()
        items = {
          starter.sections.recent_files(10, false),
          { name = 'New file',  action = 'enew',                 section = 'Actions' },
          { name = 'Find file', action = 'Telescope find_files', section = 'Actions' },
          { name = 'Live grep', action = 'Telescope live_grep',  section = 'Actions' },
          { name = 'Config',    action = 'edit $MYVIMRC',        section = 'Actions' },
          { name = 'Quit',      action = 'qa',                   section = 'Actions' },
        },
        footer = function()
          local cwd = vim.loop.cwd() or ''
          cwd = (#cwd > 0) and ('  ' .. vim.fn.fnamemodify(cwd, ':t')) or ''
          return table.concat({ '', lazy_stats(), cwd }, '\n')
        end,
        evaluate_single = true,
      })

      -- Only show on empty start; wait for Lazy stats event
      if vim.fn.argc(-1) == 0 and not vim.g.starter_opened then
        vim.g.starter_opened = true
        vim.api.nvim_create_autocmd('User', {
          pattern = 'LazyVimStarted',
          callback = function()
            pcall(vim.cmd, 'bd')
            starter.open()
            weather.show()
            weather.refresh()
          end,
        })
      end

      -- Also refresh weather each time you reopen dashboard
      vim.api.nvim_create_autocmd('User', {
        pattern = 'MiniStarterOpened',
        callback = function()
          weather.show()
          weather.refresh()
        end,
      })

      -- Hide weather when leaving starter
      vim.api.nvim_create_autocmd('BufLeave', {
        callback = function()
          if vim.bo[0].filetype ~= 'starter' then
            weather.hide()
          end
        end,
      })

      -- Hide default intro
      vim.opt.shortmess:append({ I = true })

      -- Re-open dashboard
      vim.keymap.set('n', '<leader>ld', function() starter.open() end, { desc = '[l]aunch [d]ashboard' })

      -- Toggle weather widget
      vim.keymap.set('n', '<leader>lw', function()
        if weather.is_visible() then
          weather.hide()
        else
          weather.show()
          weather.refresh()
        end
      end, { desc = '[l]aunch [w]eather widget' })
    end,
  },
}