" hexedit#modes#hexstr - Hex 字串模式 (REQUIREMENTS 4.2) - Renderable + Editable
"
" Unlike Hex 编辑模式, this mode allows free-form insert/delete (variable
" length editing), so it needs no cursor/key restriction hooks -- normal
" Vim editing applies. Validation happens only when switching away
" (ViewToBinary), per REQUIREMENTS 4.2.

let s:HexStr = {}

function! s:HexStr.Name() abort
    return 'hexstr'
endfunction

function! s:HexStr.FileType() abort
    return 'keephex'
endfunction

function! s:HexStr.BinaryToView(model) abort
    return hexedit#model#ToHexStringLines(a:model)
endfunction

function! s:HexStr.ViewToBinary(lines, model) abort
    let [l:ok, l:result] = hexedit#model#ParseHexStringLines(a:lines)
    if !l:ok
        return [0, l:result]
    endif
    let l:model = copy(a:model)
    let l:model.plain_hex = l:result
    let l:model.window_length = len(l:result) / 2
    return [1, l:model]
endfunction

function! hexedit#modes#hexstr#Get() abort
    return s:HexStr
endfunction
