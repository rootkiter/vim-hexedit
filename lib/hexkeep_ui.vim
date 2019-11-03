" Class HexKeepUI
" ============================
let s:HexKeepUI = {}
let g:HexKeepUI = s:HexKeepUI

function! s:HexKeepUI.Name()
    return "HexKeepUI"
endfunction

function! s:HexKeepUI.StartUp()
    let l:fmt = "%s/\\(\\x\\{".b:offset_area_size.
                \ "}\\):\\(.\\{".b:hex_area_size."}\\)  | \\(.*\\n\\)/\\2/g"
    silent exec l:fmt
    let l:hex_split = "%s/ \\(\\x\\{2}\\)\\(\\x\\{2}\\)/ \\1 \\2/g"
    silent exec l:hex_split
    silent exec l:hex_split
endfunction

function! s:HexKeepUI.CleanEditMode()
endfunction

function! s:HexKeepUI.Stop()
endfunction

function! s:HexKeepUI.CreateNewFile()
endfunction

function! s:HexKeepUI.OnCursorMoved()
    echom "HexKeepUI.OnCursorMoved()"
endfunction

function! s:HexKeepUI.OnCursorMovedI()
endfunction

function! s:HexKeepUI.OnTextChanged()
endfunction

function! s:HexKeepUI.OnBufReadPost()
endfunction

function! s:HexKeepUI.OnInsertCharPre()
endfunction

function! s:HexKeepUI.OnBufUnload()
endfunction

function! s:HexKeepUI.OnBufWritePre()
endfunction

function! s:HexKeepUI.OnBufWritePost()
endfunction

function! s:HexKeepUI.BuildInCommand(cmd)
endfunction

function! s:HexKeepUI.EnterEditMode()
endfunction

function! s:HexKeepUI.QuitEditMode()
endfunction
