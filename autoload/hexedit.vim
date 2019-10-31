if exists("g:loaded_autoload_hexedit")
    finish
endif
let g:loaded_autoload_hexedit = 1

let g:HexEditCurrentUI = {}

function! hexedit#version()
    return '1.0.0'
endfunction

function! hexedit#loadClassFiles()
    runtime lib/hexedit_ui.vim
endfunction

function! hexedit#toggle(new_ui)
    let l:curr_mode = ''
    if g:HexEditCurrentUI != {}
        let l:curr_mode = g:HexEditCurrentUI.Name()
        call g:HexEditCurrentUI.Stop()
        let g:HexEditCurrentUI = {}
    endif

    if l:curr_mode != a:new_ui.Name()
        let g:HexEditCurrentUI = a:new_ui
        call g:HexEditCurrentUI.StartUp()
    endif
endfunction

function! hexedit#BuildInCommand(cmd)
    if g:HexEditCurrentUI != {}
        g:HexEditCurrentUI.BuildInCommand(a:cmd)
    endif
endfunction

function! hexedit#ToggleHexEdit()
    call hexedit#toggle(g:HexEditUI)
endfunction

function! hexedit#ToggleHexKeep()
    let g:HexEditCurrentUI = {}
endfunction

function! hexedit#OnBufNewFile()
    if &l:binary == 1
        call g:HexEditUI.CreateNewFile()
        let g:HexEditCurrentUI = g:HexEditUI
    endif
endfunction

function! hexedit#OnBufReadPost()
    if &l:binary == 1
        call hexedit#ToggleHexEdit()
    endif
endfunction

function! hexedit#OnTextChanged()
    if g:HexEditCurrentUI != {}
        call g:HexEditCurrentUI.OnTextChanged()
    endif
endfunction

function! hexedit#OnCursorMoved()
    if g:HexEditCurrentUI != {}
        call g:HexEditCurrentUI.OnCursorMoved()
    endif
endfunction

function! hexedit#OnCursorMovedI()
    if g:HexEditCurrentUI != {}
        call g:HexEditCurrentUI.OnCursorMovedI()
    endif
endfunction

function! hexedit#OnInsertCharPre()
    if g:HexEditCurrentUI != {}
        call g:HexEditCurrentUI.OnInsertCharPre()
    endif
endfunction

function! hexedit#OnBufWritePost()
    if g:HexEditCurrentUI != {}
        call g:HexEditCurrentUI.OnBufWritePost()
    endif
endfunction

function! hexedit#OnBufUnload()
    if g:HexEditCurrentUI != {}
        call g:HexEditCurrentUI.OnBufUnload()
    endif
endfunction

function! hexedit#OnBufWritePre()
    if g:HexEditCurrentUI != {}
        call g:HexEditCurrentUI.OnBufWritePre()
    endif
endfunction
