-- Remove keybind for <+> moving down one line so that <+y> functions correctly.

vim.keymap.set({ 'n', 'v', 'x' }, '+', '<Nop>')
