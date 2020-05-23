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
    runtime lib/hex2py_ui.vim
    runtime lib/hex2c_ui.vim
endfunction

function! hexedit#HexEditInitEnv()
    " let b:HexEditCurrentUI = {}
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

function! hexedit#HexLoad2Edit()
    if hexedit#testCurrentUI() == 0
        call g:HexEditUI.HexLoadTrigger()
        let b:HexEditCurrentUI = g:HexEditUI
    endif
endfunction

function! hexedit#ToggleHexKeep()
    if b:HexEditCurrentUI == {}
        echom "CurrentUI == None"
        return
    elseif b:HexEditCurrentUI.Name() == "HexEditUI"
        call g:HexEditUI.QuitEditMode()
        let b:HexEditCurrentUI = g:HexKeepUI
        call g:HexKeepUI.EnterEditMode()
        call b:HexEditCurrentUI.StartUp()
    elseif b:HexEditCurrentUI.Name() == "HexKeepUI"
        let l:flag = g:HexKeepUI.FillHexAuxiliaryInfo()
        if l:flag == 1
            call g:HexKeepUI.QuitEditMode()
            call g:HexEditUI.EnterEditMode()
            let b:HexEditCurrentUI = g:HexEditUI
        else
            echom "The content of Hex is wrong. Please check it and try again."
        endif
    endif
endfunction

function! hexedit#ToggleHex2C()
    if b:HexEditCurrentUI == {}
        echom "CurrentUI == None"
        return
    elseif b:HexEditCurrentUI.Name() == "HexEditUI"
        call g:HexEditUI.QuitEditMode()
        let b:HexEditCurrentUI = g:Hex2CUI
        call g:Hex2CUI.EnterEditMode()
        call b:HexEditCurrentUI.StartUp()
    elseif b:HexEditCurrentUI.Name() == "Hex2CUI"
        call g:Hex2CUI.FillHexAuxiliaryInfo()
        call g:Hex2CUI.QuitEditMode()
        call g:HexEditUI.EnterEditMode()
        let b:HexEditCurrentUI = g:HexEditUI
    endif
endfunction

function! hexedit#ToggleHex2Py()
    if b:HexEditCurrentUI == {}
        echom "CurrentUI == None"
        return
    elseif b:HexEditCurrentUI.Name() == "HexEditUI"
        call g:HexEditUI.QuitEditMode()
        let b:HexEditCurrentUI = g:Hex2PyUI
        call g:Hex2PyUI.EnterEditMode()
        call b:HexEditCurrentUI.StartUp()
    elseif b:HexEditCurrentUI.Name() == "Hex2PyUI"
        call g:Hex2PyUI.FillHexAuxiliaryInfo()
        call g:Hex2PyUI.QuitEditMode()
        call g:HexEditUI.EnterEditMode()
        let b:HexEditCurrentUI = g:HexEditUI
    endif
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

function! hexedit#ProcessEvent(event)
    if hexedit#testCurrentUI() == 1
        if has_key(b:HexEditCurrentUI, a:event)
            let l:cmdstr = "call b:HexEditCurrentUI.".a:event."()"
            exec l:cmdstr
        else
            echom "Error ".b:HexEditCurrentUI.Name().".".a:event
        endif
    endif
endfunction
