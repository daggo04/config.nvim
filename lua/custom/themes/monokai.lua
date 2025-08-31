-- Monokai Pro theme configuration
-- You can modify this file to customize the monokai-pro colorscheme settings
-- Available filters: classic, octagon, pro, machine, ristretto, spectrum

return {
  'loctvl842/monokai-pro.nvim',
  priority = 1000,
  config = function()
    require('monokai-pro').setup {
      transparent_background = false,
      terminal_colors = true,
      devicons = true,
      filter = 'octagon', -- choose from: classic, octagon, pro, machine, ristretto, spectrum
      styles = {
        comment = { italic = false },
      },
    }

    vim.cmd.colorscheme 'monokai-pro'
  end,
}
