" hexedit#modes#c_view - C 语言视图模式 (REQUIREMENTS 4.3) - Renderable only
"
" No ViewToBinary key is defined, so the registry (2.3) automatically
" treats this mode as read-only (setlocal nomodifiable) -- no per-mode
" insert-mode-blocking hack is needed here.

let s:CView = {}

function! s:CView.Name() abort
    return 'c_view'
endfunction

function! s:CView.FileType() abort
    return 'c'
endfunction

function! s:CView.BinaryToView(model) abort
    return hexedit#model#ToCLines(a:model, get(g:, 'hexedit_c_varname', 'buf'))
endfunction

function! hexedit#modes#c_view#Get() abort
    return s:CView
endfunction
