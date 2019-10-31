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

call hexedit#loadClassFiles()

command -bar Hexedit call hexedit#ToggleHexEdit()
command -bar Hexkeep call hexedit#ToggleHexKeep()

if has("autocmd")
    augroup Hexedit
        au!

        au BufNewFile    * call hexedit#OnBufNewFile()   

        au BufReadPost   * call hexedit#OnBufReadPost()
        au CursorMoved   * call hexedit#OnCursorMoved()
        au CursorMovedI  * call hexedit#OnCursorMovedI()

        au TextChanged   * call hexedit#OnTextChanged()

        au BufUnload     * call hexedit#OnBufUnload()

        au InsertCharPre * call hexedit#OnInsertCharPre()

        au BufWritePre   * call hexedit#OnBufWritePre()

        au BufWritePost  * call hexedit#OnBufWritePost()
    augroup END
endif
