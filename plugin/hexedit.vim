" vim-hexedit entry point (REQUIREMENTS.md 2.7): config defaults and
" command/autocmd registration only. All logic lives under autoload/.

if exists('g:loaded_plugin_hexedit')
    finish
endif
let g:loaded_plugin_hexedit = 1

" ---- Config defaults (REQUIREMENTS.md 7) -----------------------------

let g:group_octets_num = get(g:, 'group_octets_num', 2)
let g:octets_per_line  = get(g:, 'octets_per_line', 16)
let g:hexedit_low_up   = get(g:, 'hexedit_low_up', 'lower')
let g:hexedit_patterns = get(g:, 'hexedit_patterns', '*.bin,*.dat,*.hex,*.o')
let g:hexedit_xxd_options = get(g:, 'hexedit_xxd_options', '')

let g:hexedit_large_file_threshold = get(g:, 'hexedit_large_file_threshold', 1 * 1024 * 1024)
let g:hexedit_window_size          = get(g:, 'hexedit_window_size', 65536)
let g:hexedit_cache_window_ratio   = get(g:, 'hexedit_cache_window_ratio', 3)

let g:hexedit_c_varname = get(g:, 'hexedit_c_varname', 'buf')

" ---- Commands (REQUIREMENTS.md 3) -------------------------------------
" :Hexedit :Hexkeep :Hex2C :Hex2Py from the pre-refactor plugin are
" removed without a compatibility alias, per REQUIREMENTS.md 3.

command -bar Hedit   call hexedit#Hedit()
command -bar Hex     call hexedit#Hex()
command -bar H2C     call hexedit#H2C()
command -bar H2Py    call hexedit#H2Py()
command -bar HexLoad call hexedit#HexLoad()
command -bar HexDump call hexedit#HexDump()
command -bar -nargs=1 HGoto call hexedit#HGoto(<q-args>)
command -bar -nargs=1 Hsearch call hexedit#Hsearch(<q-args>)
command -bar -nargs=0 HsearchClean call hexedit#HsearchClean()

" ---- Autocmds (REQUIREMENTS.md 6) --------------------------------------

if has('autocmd')
    augroup Hexedit
        au!

        if !empty(g:hexedit_patterns)
            execute printf('au BufReadCmd %s call hexedit#OnBufReadCmd()', g:hexedit_patterns)
            execute printf('au BufNewFile %s call hexedit#OnBufNewFileCmd()', g:hexedit_patterns)
        endif

        " Fallback for files opened via an explicit -b/++bin flag on a name
        " that doesn't match g:hexedit_patterns (REQUIREMENTS 6.1).
        au BufNewFile   * call hexedit#OnBufNewFile()
        au BufReadPost  * call hexedit#OnBufReadPost()

        au CursorMoved  * call hexedit#OnCursorMoved()
        au CursorMovedI * call hexedit#OnCursorMovedI()
        au InsertEnter  * call hexedit#OnInsertEnter()
        au InsertLeave  * call hexedit#OnInsertLeave()
        au TextChanged  * call hexedit#OnTextChanged()
        au InsertCharPre * call hexedit#OnInsertCharPre()
    augroup END
endif
