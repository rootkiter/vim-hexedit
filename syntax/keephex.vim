" Vim syntax file for Hex string mode (filetype 'keephex')
if exists("b:current_syntax")
    finish
endif

syn match khex "[0-9a-fA-F]\{2}"
" String reliably gets an actual distinct color, even under Neovim's own
" built-in default palette with no colorscheme loaded -- unlike Constant,
" which collapses to flat grey there (checked empirically).
hi link khex String

let b:current_syntax = "keephex"
