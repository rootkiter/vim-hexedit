if exists("loaded_plugin_hexedit")
    finish
endif
let loaded_plugin_hexedit = 1

let g:group_octets_num = get(g:, 'group_octets_num', 2)
let g:octets_per_line  = get(g:, 'octets_per_line' , 16)
let g:hexedit_low_up   = get(g:, 'hexedit_low_up'  , 'lower')
let g:hexedit_patterns = get(g:, 'hexedit_patterns', '*.bin,*.dat,*.o')

let g:hexedit_xxd_options = get(g:, 'hexedit_xxd_options', '')
let g:hexedit_xxd_options = g:hexedit_xxd_options.
            \ ' -c '.g:octets_per_line.
            \ ' -g '.g:group_octets_num


let b:m_group_num  = g:octets_per_line / g:group_octets_num
let b:m_group_left = g:octets_per_line % g:group_octets_num
let g:group_cell_size  = g:group_octets_num*2+1
let b:group_left_size  = b:m_group_left * 2 + (b:m_group_left>0?1:0)
let g:hex_area_size    = g:group_cell_size*b:m_group_num +
            \ b:group_left_size
let g:offset_area_size = 8


call hexedit#HexEditInitEnv()
call hexedit#loadClassFiles()

command -bar HexLoad call hexedit#HexLoad2Edit ()
command -bar Hexedit call hexedit#ToggleHexEdit()
command -bar Hexkeep call hexedit#ToggleHexKeep()
command -bar Hex2C   call hexedit#ToggleHex2C  ()
command -bar Hex2Py  call hexedit#ToggleHex2Py ()
command -bar -nargs=1 Hexsearch call hexedit#BuildInCommand("Hexsearch", <q-args>)
command -bar -nargs=0 HexsearchClean call hexedit#BuildInCommand("HexsearchClean", <q-args>)

function! s:Echom(message)
	echom "Echom -> ".a:message
endfunction

if has("autocmd")
    augroup Hexedit
        au!

        if !empty(g:hexedit_patterns)
            execute printf('au BufNewFile %s setlocal binary noeol', g:hexedit_patterns)
            execute printf('au BufReadPre %s setlocal binary noeol', g:hexedit_patterns)
        endif


        au BufNewFile    * call hexedit#OnBufNewFile()   

        au BufReadPost   * call hexedit#OnBufReadPost()
        au CursorMoved   * call hexedit#ProcessEvent("OnCursorMoved")
        au CursorMovedI  * call hexedit#ProcessEvent("OnCursorMovedI")

        au InsertEnter   * call hexedit#ProcessEvent("OnInsertEnter")
        au InsertLeave   * call hexedit#ProcessEvent("OnInsertLeave")
        au TextChanged   * call hexedit#ProcessEvent("OnTextChanged")

        au BufUnload     * call hexedit#ProcessEvent("OnBufUnload")
        au BufEnter      * call hexedit#ProcessEvent("OnBufEnter")
        au BufLeave      * call hexedit#ProcessEvent("OnBufLeave")

        au InsertCharPre * call hexedit#ProcessEvent("OnInsertCharPre")

        au BufWritePre   * call hexedit#ProcessEvent("OnBufWritePre")

        au BufWritePost  * call hexedit#ProcessEvent("OnBufWritePost")
    augroup END
endif
