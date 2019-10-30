if exists("loaded_hexedit")
    finish
endif
let loaded_hexedit = 1

let g:group_octets_num = get(g:, 'group_octets_num', 2)
let g:octets_per_line  = get(g:, 'octets_per_line' , 16)
let g:hexmode_low_up   = get(g:, 'hexmode_lower_upper', ' -u ')

let g:hexmode_xxd_options = get(g:, 'hexmode_xxd_options', '')
let g:hexmode_xxd_options = g:hexmode_xxd_options.
            \ ' -c '.g:octets_per_line.
            \ ' -g '.g:group_octets_num

command -bar Hexedit call ToggleHex()

function ToggleHex()
    " hex mode should be considered a read-only operation
    " save values for modified and read-only for restoration later,
    " and clear the read-only flag for now
    let l:modified = &l:modified
    let l:oldreadonly = &l:readonly
    let l:oldmodifiable = &l:modifiable
    setlocal noreadonly
    setlocal modifiable
    if !exists("b:editHex") || !b:editHex
        " save old options
        let b:oldft = &l:ft
        " set status
        let b:editHex=1
        " switch to hex editor
        call g:HexEditEvent.OpenHexMode()
        call g:HexEditEvent.CursorCmdHook('install')
        " silent exe "%!xxd " . g:hexmode_xxd_options
        " set new options
        let &l:ft="xxd"
        " call g:HexEditEvent.UpdateCurrentLine("A")
    else
        " restore old options
        let &l:ft = b:oldft
        " return to normal editing
        call g:HexEditEvent.CursorCmdHook('uninstall')
        silent exe "%!xxd -r " . g:hexmode_xxd_options
        " set status
        let b:editHex=0
    endif

    " restore values for modified and read only state
    let &l:modified = l:modified
    let &l:readonly = l:oldreadonly
    let &l:modifiable = l:oldmodifiable
endfunction

if has("autocmd")
    augroup Hexedit
        au!

        au BufReadPost *
            \ if exists('b:editHex') && b:editHex |
            \   let b:editHex = 0 |
            \ endif

        au BufReadPost *
            \ if &l:binary == 1 |
            \   Hexedit |
            \ endif

        au CursorMoved *
            \ call g:HexEditEvent.OnCursorMoved('normal')

        au CursorMovedI *
            \ call g:HexEditEvent.OnCursorMoved('insert')

        au TextChanged *
            \ call g:HexEditEvent.OnTextChanged()

        au TextChangedI *
            \ call g:HexEditEvent.OnTextChangedI()

        au BufUnload *
            \ if getbufvar(expand("<afile>"), 'editHex') == 1 |
            \   call setbufvar(expand("<afile>"), 'editHex', 0) |
            \ endif

        au BufWritePre *
            \ if exists("b:editHex") && b:editHex |
            \  let b:oldview = winsaveview() |
            \  let b:oldro=&l:ro | let &l:ro=0 |
            \  let b:oldma=&l:ma | let &l:ma=1 |
            \  undojoin |
            \  silent exe "%!xxd -r " . g:hexmode_xxd_options |
            \  let &l:ma=b:oldma | let &l:ro=b:oldro |
            \  unlet b:oldma | unlet b:oldro |
            \  let &l:ul = &l:ul |
            \ endif

        au BufWritePost *
            \ if exists("b:editHex") && b:editHex |
            \  let b:oldro=&l:ro | let &l:ro=0 |
            \  let b:oldma=&l:ma | let &l:ma=1 |
            \  undojoin |
            \  call g:HexEditEvent.OpenHexMode() |
            "\  silent exe "%!xxd " . g:hexmode_xxd_options |
            \  exe "setlocal nomod" |
            \  let &l:ma=b:oldma | let &l:ro=b:oldro |
            \  unlet b:oldma | unlet b:oldro |
            \  call winrestview(b:oldview) |
            \  let &l:ul = &l:ul |
            \ endif
    augroup END
endif
