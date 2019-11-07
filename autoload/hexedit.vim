if exists("g:loaded_autoload_hexedit")
    finish
endif
let g:loaded_autoload_hexedit = 1


function! hexedit#version()
    return '1.0.0'
endfunction

function! hexedit#loadClassFiles()
    runtime lib/hexedit_ui.vim
    runtime lib/hexkeep_ui.vim
endfunction

function! hexedit#HexEditInitEnv()
    let b:HexEditCurrentUI = {}
endfunction

function! hexedit#testCurrentUI()
    if !exists("b:HexEditCurrentUI")
        let b:HexEditCurrentUI = {}
    endif
    if b:HexEditCurrentUI != {}
        return 1
    endif
    return 0
endfunction

function! hexedit#toggle(new_ui)
    let l:curr_mode = ''
    call hexedit#testCurrentUI()

    if b:HexEditCurrentUI != {}
        let l:curr_mode = b:HexEditCurrentUI.Name()
        call b:HexEditCurrentUI.Stop()
        let b:HexEditCurrentUI = {}
    endif

    if l:curr_mode != a:new_ui.Name()
        let b:HexEditCurrentUI = a:new_ui
        call b:HexEditCurrentUI.StartUp()
    endif
endfunction

function! hexedit#BuildInCommand(cmd, arg1)
    if hexedit#testCurrentUI() == 1
        call b:HexEditCurrentUI.BuildInCommand(a:cmd, a:arg1)
    endif
endfunction

function! hexedit#ToggleHexEdit()
    call hexedit#toggle(g:HexEditUI)
endfunction

function! hexedit#ToggleHexKeep()
    if b:HexEditCurrentUI == {}
        echom "CurrentUI == None"
        return
    elseif b:HexEditCurrentUI.Name() != "HexEditUI"
        echom "HexKeep"
        return
   endif
   call g:HexEditUI.QuitEditMode()
   let b:HexEditCurrentUI = g:HexKeepUI
   call b:HexEditCurrentUI.StartUp()
endfunction

function! hexedit#OnBufNewFile()
    if &l:binary == 1
        call g:HexEditUI.CreateNewFile()
        let b:HexEditCurrentUI = g:HexEditUI
    endif
endfunction

function! hexedit#OnBufReadPost()
    if &l:binary == 1
        call hexedit#ToggleHexEdit()
    endif
endfunction

function! hexedit#OnTextChanged()
    if hexedit#testCurrentUI() == 1
        call b:HexEditCurrentUI.OnTextChanged()
    endif
endfunction

function! hexedit#OnCursorMoved()
    if hexedit#testCurrentUI() == 1
        call b:HexEditCurrentUI.OnCursorMoved()
    endif
endfunction

function! hexedit#OnCursorMovedI()
    if hexedit#testCurrentUI() == 1
        call b:HexEditCurrentUI.OnCursorMovedI()
    endif
endfunction

function! hexedit#OnInsertCharPre()
    if hexedit#testCurrentUI() == 1
        call b:HexEditCurrentUI.OnInsertCharPre()
    endif
endfunction

function! hexedit#OnBufWritePost()
    if hexedit#testCurrentUI() == 1
        call b:HexEditCurrentUI.OnBufWritePost()
    endif
endfunction

function! hexedit#OnBufUnload()
    if hexedit#testCurrentUI() == 1
        call b:HexEditCurrentUI.OnBufUnload()
    endif
endfunction

function! hexedit#OnBufWritePre()
    if hexedit#testCurrentUI() == 1
        call b:HexEditCurrentUI.OnBufWritePre()
    endif
endfunction

function! hexedit#OnBufLeave()
    if hexedit#testCurrentUI() == 1
        call b:HexEditCurrentUI.QuitEditMode()
    endif
endfunction

function! hexedit#OnBufEnter()
    if hexedit#testCurrentUI() == 1
        call b:HexEditCurrentUI.EnterEditMode()
    endif
endfunction