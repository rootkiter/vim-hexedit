" hexedit#modes#py_view - Python 视图模式 (REQUIREMENTS 4.4) - Renderable only
"
" No ViewToBinary key is defined, so the registry (2.3) automatically
" treats this mode as read-only.

let s:PyView = {}

function! s:PyView.Name() abort
    return 'py_view'
endfunction

function! s:PyView.FileType() abort
    return 'python'
endfunction

function! s:PyView.BinaryToView(model) abort
    return hexedit#model#ToPyLines(a:model)
endfunction

function! hexedit#modes#py_view#Get() abort
    return s:PyView
endfunction
