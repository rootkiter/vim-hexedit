" Class Hex2CUI
" ============================
let s:Hex2CUI = {}
let g:Hex2CUI = s:Hex2CUI

function! s:Hex2CUI.Name()
    return "Hex2CUI"
endfunction

function! s:Hex2CUI.StartUp()
    let l:line_cur = 1
    let l:cut_hex_frm = "\\(\\x\\{".b:offset_area_size.
                \ "}\\):\\(.\\{".b:hex_area_size.
                \ "}\\)  | \\(.*\\)"
    let l:cut_hex_to = "\\2"
    let l:cut_char_area_to = "\\3"

    let l:hex_split_frm = " \\(\\x\\{2}\\)\\(\\x\\{2}\\)"
    let l:hex_split_to  = " \\1 \\2"

    let l:hex_to_C_frm  = " \\(\\x\\{2}\\)"
    let l:hex_to_C_to   = "0x\\1, "

    while l:line_cur <= line('$')
        let l:cur_line = getline( l:line_cur )
        let l:cur_hex_area = substitute(l:cur_line,
                    \ l:cut_hex_frm, l:cut_hex_to, 'g')
        let l:cur_hex_area = substitute(l:cur_hex_area,
                    \ l:hex_split_frm, l:hex_split_to, 'g')
        let l:cur_hex_area = substitute(l:cur_hex_area,
                    \ l:hex_split_frm, l:hex_split_to, 'g')
        let l:cur_hex_area = substitute(l:cur_hex_area,
                    \ l:hex_to_C_frm, l:hex_to_C_to, 'g')

        let l:cur_char_area = substitute(l:cur_line,
                    \ l:cut_hex_frm, l:cut_char_area_to, 'g')

        let l:line_output = l:cur_hex_area." // ".l:cur_char_area

        call setline(l:line_cur, l:line_output)
        let l:line_cur += 1
    endwhile
endfunction

function! s:Hex2CUI.FillHexAuxiliaryInfo()
    " let l:cut_hex_area_frm = 
    let l:group_cell_frm = repeat("0x\\(\\x\\{2}\\), ",
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
        let l:area_split = split(l:line, " // ")
        if len(l:area_split) <= 0
            continue
        endif

        let l:line = l:area_split[0]

        let l:line = substitute(l:line,
                    \"  *", " ", 'g')
        let l:tmp = substitute(l:line,
                    \ l:group_cell_frm, l:group_cell_to,
                    \ 'g')

        let l:bts_list = split(l:line, ", ")
        let l:left_bts = 0
        let l:left_bts = len(l:bts_list)
                    \ % g:group_octets_num
        if l:left_bts > 0
            let l:group_left_frm = repeat(
                        \ "0x\\(\\x\\{2}\\), ",
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
        for l:charnow in map(l:bts_list, '"".v:val')
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

function! s:Hex2CUI.CleanEditMode()
endfunction

function! s:Hex2CUI.Stop()
endfunction

function! s:Hex2CUI.CreateNewFile()
endfunction

function! s:Hex2CUI.OnCursorMoved()
endfunction

function! s:Hex2CUI.OnCursorMovedI()
endfunction

function! s:Hex2CUI.OnInsertEnter()
    call feedkeys("\<esc>")
endfunction

function! s:Hex2CUI.OnTextChanged()
endfunction

function! s:Hex2CUI.OnBufReadPost()
endfunction

function! s:Hex2CUI.OnInsertCharPre()
endfunction

function! s:Hex2CUI.OnBufUnload()
endfunction

function! s:Hex2CUI.OnBufWritePre()
endfunction

function! s:Hex2CUI.OnBufWritePost()
endfunction

function! s:Hex2CUI.BuildInCommand(cmd)
endfunction

function! s:Hex2CUI.EnterEditMode()
endfunction

function! s:Hex2CUI.QuitEditMode()
endfunction
