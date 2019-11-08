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
    let l:group_cell_frm = repeat(" \\(\\x\\{2}\\)",
                \ g:group_octets_num)
    let l:group_cell_to  = " ".join(map(range(1,
                \ g:group_octets_num),
                \ '"\\".v:val'), '')

    let l:newfmt = "%0".b:offset_area_size."x:".
                \"%-".b:hex_area_size."s  | %s"

    let l:l_num = 1
    let l:offsetnow = 0
    while l:l_num <= line('$')
        let l:line = getline(l:l_num)
        let l:line = substitute(l:line,
                    \"  *", " ", 'g')
        let l:tmp = substitute(l:line,
                    \ l:group_cell_frm, l:group_cell_to,
                    \ 'g')

        let l:bts_list = split(l:line, " ")
        let l:left_bts = len(l:bts_list)
                    \ % g:group_octets_num
        if l:left_bts > 0
            let l:group_left_frm = repeat(
                        \ " \\(\\x\\{2}\\)",
                        \ l:left_bts)
            let l:group_left_to  = " ".join(
                        \ map(range(1,
                        \ l:left_bts),
                        \ '"\\".v:val'), '')
            let l:tmp = substitute(l:tmp,
                        \ l:group_left_frm,
                        \ l:group_left_to,
                        \ 'g')
        endif

        let l:bts_char_str = ''
        for l:charnow in map(l:bts_list, '"0x".v:val')
            let l:ascii = eval(l:charnow)
            if l:ascii < 127 && l:ascii > 31
                let l:bts_char_str .= nr2char(l:ascii)
            else
                let l:bts_char_str .= "."
            endif
        endfor
        let l:newline = printf(
                    \ l:newfmt,
                    \ l:offsetnow, l:tmp, l:bts_char_str)
        call setline(l:l_num, l:newline)
        let l:l_num += 1
        let l:offsetnow += g:octets_per_line
    endwhile
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
