" hexedit#modes#format_parse - 格式解析模式 (REQUIREMENTS 4.5) - PLACEHOLDER
"
" This mode is architecturally reserved, not functionally implemented in
" this iteration (REQUIREMENTS 4.5 explicitly scopes the real parsing /
" field highlighting work out of this refactor). It is registered so that:
"   - the mode registry/dispatch machinery has a 5th mode to prove the
"     "no N x N conversions" design actually generalizes beyond 4 modes;
"   - a future contributor can flesh this out (and add parsers under
"     autoload/hexedit/parsers/) without touching registry.vim, model.vim,
"     or any other mode.
"
" MVP behavior: renders identically to Hex 编辑模式's dump (no field
" highlighting yet, since model.annotations is always empty until a parser
" populates it) and is read-only (no ViewToBinary), per the table in 2.3.

let s:FormatParse = {}

function! s:FormatParse.Name() abort
    return 'format_parse'
endfunction

function! s:FormatParse.FileType() abort
    return 'vhex'
endfunction

function! s:FormatParse.BinaryToView(model) abort
    return hexedit#model#ToHexDumpLines(a:model)
endfunction

function! hexedit#modes#format_parse#Get() abort
    return s:FormatParse
endfunction
