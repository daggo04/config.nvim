-- Pyright is now handled by the python-env plugin

local servers = {
  cssls = {},
  html = {},
  hls = {
    -- Haskell Language Server configuration
    cmd = { 'haskell-language-server-wrapper', '--lsp' },
    filetypes = { 'haskell', 'lhaskell', 'cabal' },
    settings = {
      haskell = {
        cabalFormattingProvider = 'cabalfmt',
        -- Automatically format on save
        formattingProvider = 'ormolu',
        -- Show type signatures in hover
        plugin = {
          stan = { globalOn = false }, -- Stan is a static analyzer, disable if causing issues
        },
      },
    },
  },
}

return servers
