" Class Hex2PyUI
" ============================
let s:Hex2PyUI = {}
let g:Hex2PyUI = s:Hex2PyUI

function! s:Hex2PyUI.Name()
    return "Hex2PyUI"
endfunction

function! s:Hex2PyUI.StartUp()
    let l:line_cur = 1
    let l:cut_hex_frm = "\\(\\x\\{".b:offset_area_size.
                \ "}\\):\\(.\\{".b:hex_area_size.
                \ "}\\)  | \\(.*\\)"
    let l:cut_hex_to = "\\2"
    let l:cut_char_area_to = "\\3"

    let l:hex_split_frm = " \\(\\x\\{2}\\)\\(\\x\\{2}\\)"
    let l:hex_split_to  = " \\1 \\2"

    let l:last_tmp_line = "print ("
    while l:line_cur <= line('$')
        let l:cur_line = getline( l:line_cur )
        let l:cur_hex_area = substitute(l:cur_line,
                    \ l:cut_hex_frm, l:cut_hex_to, 'g')
        let l:cur_hex_area = substitute(l:cur_hex_area,
                    \ l:hex_split_frm, l:hex_split_to, 'g')
        let l:cur_hex_area = substitute(l:cur_hex_area,
                    \ l:hex_split_frm, l:hex_split_to, 'g')
        let l:cur_char_area = substitute(l:cur_line,
                    \ l:cut_hex_frm, l:cut_char_area_to, 'g')

        let l:line_output = "  \"".l:cur_hex_area
        if l:line_cur != line('$')
            let l:line_output .= "\" + ### ".l:cur_char_area
        else
            let l:line_output .= "\"   ### ".l:cur_char_area
        endif

        call setline(l:line_cur, l:last_tmp_line)
        let l:last_tmp_line = l:line_output
        let l:line_cur += 1
    endwhile
    call setline(l:line_cur, l:last_tmp_line)
    call setline(l:line_cur+1, ").replace(' ', '').decode('hex')")
endfunction

function! s:Hex2PyUI.FillHexAuxiliaryInfo()
    let l:cut_hex_frm     = "  \\\"\\(.*\\)\\\" + ### \\(.*\\)"
    let l:cut_hex_end_frm = "  \\\"\\(.*\\)\\\"   ### \\(.*\\)"

    let l:newfmt = "%0".b:offset_area_size."x: ".
                \"%-".b:hex_area_size."s | %s"

    let l:line_cur = 2
    let l:offsetnow = 0
    while l:line_cur <= line('$')-1
        let l:cur_line = getline(l:line_cur)
        if l:line_cur == line('$') -1
            let l:cur_hex_area = substitute( l:cur_line,
                        \ l:cut_hex_end_frm, "\\1", 'g')
        else
            let l:cur_hex_area = substitute( l:cur_line,
                        \ l:cut_hex_frm, "\\1", 'g')
        endif
        let l:hex_area_split = split(l:cur_hex_area, " ")
        if len(l:hex_area_split) <= 0
            continue
        endif

        let l:hex_area_tmp = ""
        let l:char_area_tmp = ""

        for l:num in range(0, len(l:hex_area_split)-1)
            let l:cur_hex = l:hex_area_split[l:num]
            if l:num != 0 && (l:num) % g:group_octets_num == 0
                let l:hex_area_tmp .= " "
            endif
            let l:hex_area_tmp .= l:cur_hex
            if len(l:cur_hex) != 2
                continue
            endif

            let l:ascii = eval("0x".l:cur_hex)
            if l:ascii < 127 && l:ascii > 31
                let l:char_area_tmp .= nr2char(l:ascii)
            else
                let l:char_area_tmp .= "."
            endif
        endfor

        let l:newline = printf(
            \ l:newfmt,
            \ l:offsetnow, l:hex_area_tmp, l:char_area_tmp)
        call setline(l:line_cur-1, l:newline)
        let l:offsetnow += g:octets_per_line
        let l:line_cur += 1
    endwhile
    exec "normal! Gdddd"
endfunction

function! s:Hex2PyUI.CleanEditMode()
endfunction

function! s:Hex2PyUI.Stop()
endfunction

function! s:Hex2PyUI.CreateNewFile()
endfunction

function! s:Hex2PyUI.OnCursorMoved()
endfunction

function! s:Hex2PyUI.OnCursorMovedI()
endfunction

function! s:Hex2PyUI.OnInsertEnter()
    call feedkeys("\<esc>")
endfunction

function! s:Hex2PyUI.OnInsertLeave()
endfunction

function! s:Hex2PyUI.OnTextChanged()
endfunction

function! s:Hex2PyUI.OnBufReadPost()
endfunction

function! s:Hex2PyUI.OnInsertCharPre()
endfunction

function! s:Hex2PyUI.OnBufUnload()
endfunction

function! s:Hex2PyUI.OnBufWritePre()
endfunction

function! s:Hex2PyUI.OnBufWritePost()
endfunction

function! s:Hex2PyUI.BuildInCommand(cmd)
endfunction

function! s:Hex2PyUI.EnterEditMode()
endfunction

function! s:Hex2PyUI.QuitEditMode()
endfunction
