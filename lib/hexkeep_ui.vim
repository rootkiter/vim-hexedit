" Class HexKeepUI
" ============================
let s:HexKeepUI = {}
let g:HexKeepUI = s:HexKeepUI

function! s:HexKeepUI.Name()
    return "HexKeepUI"
endfunction

function! s:HexKeepUI.StartUp()
    let l:line_cur = 1
    let l:cut_hex_frm = "\\(\\x\\{".b:offset_area_size.
                \ "}\\):\\(.\\{".b:hex_area_size.
                \ "}\\)  | \\(.*\\)"
    let l:cut_hex_to = "\\2"

    let l:hex_split_frm = " \\(\\x\\{2}\\)\\(\\x\\{2}\\)"
    let l:hex_split_to  = " \\1 \\2"

    while l:line_cur <= line('$')
        let l:cur_line = getline( l:line_cur )
        let l:cur_line = substitute(l:cur_line,
                    \ l:cut_hex_frm, l:cut_hex_to, 'g')
        let l:cur_line = substitute(l:cur_line,
                    \ l:hex_split_frm, l:hex_split_to, 'g')
        let l:cur_line = substitute(l:cur_line,
                    \ l:hex_split_frm, l:hex_split_to, 'g')

        call setline(l:line_cur, l:cur_line)
        " echom l:cut_hex_frm
        " echom l:cut_hex_to
        " echom l:cur_line2
        let l:line_cur += 1
    endwhile
endfunction

function! s:HexKeepUI.FillHexAuxiliaryInfo()
    let l:hex_areas_lines = getline(1, line('$'))
    let l:hex_areas_bts   = join(split(join(l:hex_areas_lines, ''), ' '), '')
    let l:hex_bts_len     = len(l:hex_areas_bts)
    if l:hex_bts_len % 2 != 0
        return 0
    endif
    let l:hex_area_split_frm = "\\(\\x\\{2}\\)\\(\\x\\{2}\\)"
    let l:hex_area_split_to  = "\\1 \\2 "
    let l:hex_areas_bts = substitute(
                \ l:hex_areas_bts, l:hex_area_split_frm,
                \ l:hex_area_split_to, 'g')
    let l:hex_areas_bts = split(l:hex_areas_bts, " ")

    let l:newfmt = "%0".b:offset_area_size."x:".
                \"%-".b:hex_area_size."s  | %s"

    let l:line_number = 0
    let l:line_bt_off = 0
    let l:hex_tmp     = ""
    let l:char_tmp    = ""
    let l:offsetnow   = 0
    for l:nid in range(0, len(l:hex_areas_bts)-1)
        if l:nid % g:octets_per_line == 0
            if l:line_number > 0
                let l:cur_line = printf( l:newfmt,
                            \ l:offsetnow, l:hex_tmp, l:char_tmp)
                call setline(l:line_number, l:cur_line)
                let l:offsetnow += g:octets_per_line
                let l:hex_tmp = ""
                let l:char_tmp = ""
                let l:line_bt_off = 0
            endif
            let l:line_number += 1
        endif
        let l:bt_hex = l:hex_areas_bts[l:nid]
        if l:line_bt_off % g:group_octets_num == 0
            let l:hex_tmp .= " "
        endif
        let l:hex_tmp  .= l:bt_hex
        let l:ascii  = eval("0x".l:bt_hex)
        if l:ascii < 127 && l:ascii > 31
            let l:char_tmp .= nr2char(l:ascii)
        else
            let l:char_tmp .= "."
        endif
        let l:line_bt_off += 1
    endfor
    let l:cur_line = printf( l:newfmt,
                \ l:offsetnow, l:hex_tmp, l:char_tmp)
    call setline(l:line_number, l:cur_line)

    while l:line_number < line('$')
        exe "normal! Gdd"
    endwhile
    return 1
endfunction

function! s:HexKeepUI.CleanEditMode()
endfunction

function! s:HexKeepUI.OnInsertEnter()
endfunction

function! s:HexKeepUI.Stop()
endfunction

function! s:HexKeepUI.CreateNewFile()
endfunction

function! s:HexKeepUI.OnCursorMoved()
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
