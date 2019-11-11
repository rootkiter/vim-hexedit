if exists("loaded_plugin_hexedit")
    finish
endif
let loaded_plugin_hexedit = 1

let g:group_octets_num = get(g:, 'group_octets_num', 2)
let g:octets_per_line  = get(g:, 'octets_per_line' , 16)
let g:hexmode_low_up   = get(g:, 'hexmode_lower_upper', ' -u ')

let g:hexmode_xxd_options = get(g:, 'hexmode_xxd_options', '')
let g:hexmode_xxd_options = g:hexmode_xxd_options.
            \ ' -c '.g:octets_per_line.
            \ ' -g '.g:group_octets_num


let b:m_group_num  = g:octets_per_line / g:group_octets_num
let b:m_group_left = g:octets_per_line % g:group_octets_num
let b:group_cell_size  = g:group_octets_num*2+1
let b:group_left_size  = b:m_group_left * 2 + (b:m_group_left>0?1:0)
let b:hex_area_size    = b:group_cell_size*b:m_group_num +
            \ b:group_left_size
let b:offset_area_size = 8


call hexedit#HexEditInitEnv()
call hexedit#loadClassFiles()

command -bar Hexedit call hexedit#ToggleHexEdit()
command -bar Hexkeep call hexedit#ToggleHexKeep()
command -bar Hex2C   call hexedit#ToggleHex2C  ()
command -bar -nargs=1 Hexsearch call hexedit#BuildInCommand("Hexsearch", <q-args>)
command -bar -nargs=0 HexsearchClean call hexedit#BuildInCommand("HexsearchClean", <q-args>)

if has("autocmd")
    augroup Hexedit
        au!
        au BufNewFile    * call hexedit#OnBufNewFile()   

        au BufReadPost   * call hexedit#OnBufReadPost()
        au CursorMoved   * call hexedit#OnCursorMoved()
        au CursorMovedI  * call hexedit#OnCursorMovedI()

        au TextChanged   * call hexedit#OnTextChanged()

        au BufUnload     * call hexedit#OnBufUnload()
        au BufEnter      * call hexedit#OnBufEnter()
        au BufLeave      * call hexedit#OnBufLeave()

        au InsertCharPre * call hexedit#OnInsertCharPre()

        au BufWritePre   * call hexedit#OnBufWritePre()

        au BufWritePost  * call hexedit#OnBufWritePost()
    augroup END
endif
