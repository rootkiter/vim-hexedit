" Class HexEdit ui
"===============================
let s:HexEditUI = {}
let g:HexEditUI = s:HexEditUI
let b:hexEditMode  = 0
let b:current_char = ''

function! s:HexEditUI.Name()
    return "HexEditUI"
endfunction

function! s:HexEditUI.hookInstall()
    let l:cmdkeys = ['b','h']
    for key in l:cmdkeys
        exec "nnoremap <silent> ".key." :call g:HexEditUI.NormalKeyMap(\"".key."\") <CR>"
    endfor
endfunction

function! s:HexEditUI.hookUninstall()
    let l:cmdkeys = ['b', 'h']
    for key in l:cmdkeys
        exec "nunmap ".key
    endfor
    echom "hookUninstall"
endfunction

function! s:HexEditUI.StartUp()
    let b:hexEditMode      = 1
    call s:HexEditUI.InitVars()
    call s:HexEditUI.convert2Hex()
    call s:HexEditUI.hookInstall()
endfunction

function! s:HexEditUI.InitVars()
    let l:group_num  = g:octets_per_line / g:group_octets_num
    let l:group_left = g:octets_per_line % g:group_octets_num
    let s:group_cell_size  = g:group_octets_num*2+1
    let l:group_left_size  = l:group_left * 2 + (l:group_left>0?1:0)
    let s:hex_area_size    = s:group_cell_size*l:group_num + l:group_left_size
    let s:offset_area_size = 8
endfunction

function! s:HexEditUI.convert2Hex()
    silent exe "%!xxd ". g:hexmode_xxd_options
                \ . "| sed 's/:\\(.\\{".s:hex_area_size."\\}\\)  /:\\1  | /g'"
    let b:oldft = &l:ft
    let &l:ft   = 'xxd'
endfunction

function! s:HexEditUI.Stop()
    let &l:ft = b:oldft
    let b:hexEditMode = 0
    silent exe "%!xxd -r ".g:hexmode_xxd_options
    call s:HexEditUI.hookUninstall()
endfunction

function! s:HexEditUI.CreateNewFile()
    let b:hexEditMode      = 1
    call s:HexEditUI.InitVars()
    let l:curline = s:HexEditUI.allocNewLineAtTail(0)
    " let l:lineFmt = "%0".s:offset_area_size."x: 00%".
    "             \(s:hex_area_size-3)."s  | ."
    " let l:curline = printf(l:lineFmt, 0, " ")
    call setline(1, l:curline)
    let b:oldft = &l:ft
    let &l:ft   = 'xxd'
    call s:HexEditUI.hookInstall()
endfunction

function! s:HexEditUI.UpdateCurrentLine(cur_line)
    if b:hexEditMode != 1
        return
    endif
    let l:current_line = getline(a:cur_line)
    let l:clinelist = matchlist(l:current_line,
                \ '^\([a-fA-F0-9]*\):\([ a-fA-F0-9]\{0,'.
                \ s:hex_area_size.'}\)  | \(.*\)$')[1:3]
    if len(l:clinelist)!=3
        return
    endif
    let s:current_line_number_size    = len(l:clinelist[0])
    let s:current_line_hex_area_size  = len(l:clinelist[1])
    let s:current_line_char_area_size = len(l:clinelist[2])
    let s:current_line_max_size       = len(l:current_line)
    let s:current_line_offset_number  = "0x".l:clinelist[0] + 0
endfunction

function! s:HexEditUI.columnType(colnum)
    let l:hex_end_off = s:current_line_number_size+s:current_line_hex_area_size+2
    if a:colnum<=s:current_line_number_size+1
        return ["addr", 'space', 1, s:current_line_number_size+1, 0, s:current_line_number_size+2]
    elseif a:colnum <= l:hex_end_off-1
        let l:lv2 = 'data'
        let l:hex_off = a:colnum-s:current_line_number_size-2
        if l:hex_off % s:group_cell_size == 0
            let l:lv2 = 'space'
        endif
        return ['hex',l:lv2, s:current_line_number_size+2, l:hex_end_off-1, s:current_line_number_size+1, l:hex_end_off+4]
    elseif a:colnum < l:hex_end_off+4
        return ['hex-sepa', 'space', l:hex_end_off, l:hex_end_off+3, l:hex_end_off-1, l:hex_end_off+4]
    elseif a:colnum < l:hex_end_off+4+s:current_line_char_area_size
        return ['char', 'data', l:hex_end_off+4, l:hex_end_off+g:octets_per_line+3, l:hex_end_off-1, 0]
    else
        return ['limit', 'space', 0, 0, s:current_line_max_size, l:hex_end_off+4]
    endif
endfunction

function! s:HexEditUI.NormalKeyMap(key)
    let [l:cur_line, l:cur_col] = getpos('.')[1:2]
    let [l:area, l:lv2, l:cmin, l:cmax, l:bmax, l:nmin] =
                \ s:HexEditUI.columnType(l:cur_col-1)
    if l:area == 'hex' && l:lv2 == 'space' && a:key == 'h'
        call cursor(l:cur_line, l:cur_col-2)
    elseif l:area == 'hex-sepa'
        call cursor(l:cur_line, l:bmax)
    else
        exec "normal! ".a:key
    endif
endfunction

function! s:HexEditUI.fixCursor(colnum)
    let l:colnum = a:colnum
    let [l:area, l:lv2, l:cmin, l:cmax, l:bmax, l:nmin] = s:HexEditUI.columnType(colnum)
    if l:area == 'addr'
        let l:colnum = l:nmin+1
    elseif l:area == 'hex'
        if l:lv2 == 'space'
            let l:colnum = a:colnum + 1
        endif
    elseif l:area == 'hex-sepa'
        let l:colnum = l:nmin
    endif
    return l:colnum
endfunction

function! s:HexEditUI.OnCursorMoved()
    let [l:cur_line, l:cur_col] = getpos('.')[1:2]
    call s:HexEditUI.UpdateCurrentLine(l:cur_line)
    let l:x = s:HexEditUI.columnType(l:cur_col)
    let l:cur_col =  s:HexEditUI.fixCursor(l:cur_col)
    call cursor(l:cur_line, l:cur_col)
endfunction

function! s:HexEditUI.ByteOffCalc(area, colnum)
    if a:area == 'hex'
        let l:hex_off = a:colnum-s:current_line_number_size-2
        let l:group_id   = l:hex_off / s:group_cell_size
        let l:group_left = (l:hex_off % s:group_cell_size - 1)/2
        ""let l:group_left_off = l:group_left % 2

        let l:bt_off = l:group_id * g:group_octets_num + l:group_left
        return l:bt_off
    elseif a:area == 'char'
        let l:char_area_off = s:current_line_number_size+1+s:current_line_hex_area_size+5
        let l:bt_off = a:colnum-l:char_area_off
        return l:bt_off
    endif
endfunction

function! s:HexEditUI.lineUpdate(curline, area, bt_off)
    let l:curline = a:curline
    let l:group_id   = a:bt_off / g:group_octets_num
    let l:group_left = a:bt_off % g:group_octets_num
    let l:hex_off    = s:current_line_number_size + 2 +
                \(l:group_id * s:group_cell_size) +
                \1 +l:group_left*2
    let l:char_off   = s:current_line_number_size + 2 +
                \s:current_line_hex_area_size + 2 + a:bt_off

    if a:area == 'hex'
        let l:hex_data = a:curline[l:hex_off-1:l:hex_off]
        let l:linetmp  = a:curline[0:l:char_off]
        let l:ascii = 0+("0x".l:hex_data)
        if l:ascii < 127 && l:ascii>31
            let l:linetmp .= nr2char(l:ascii)
        else
            let l:linetmp .= "."
        endif
        let l:linetmp .= a:curline[l:char_off+2:]
        let l:curline = l:linetmp
    elseif a:area == 'char'
        let l:ascii = char2nr(a:curline[l:char_off+1])
        let l:hex_data = printf("%02X", l:ascii)
        let l:linetmp  = a:curline[0:l:hex_off-2]
        let l:linetmp .= l:hex_data
        let l:linetmp .= a:curline[l:hex_off+1:]
        let l:curline  = l:linetmp
    endif
    return l:curline
endfunction

function! s:HexEditUI.OnTextChanged()
    let [l:cur_line, l:cur_col] = getpos('.')[1:2]
    let [l:area, l:lv2, l:cmin, l:cmax, l:bmax, l:nmin] =
                \ s:HexEditUI.columnType(l:cur_col)
    let l:curr_line = getline('.')
    if l:area == 'hex' && l:lv2 == 'data'
        let l:vchar = l:curr_line[l:cur_col-1]
        let l:cur_ascii = char2nr(l:vchar)
        if (l:cur_ascii >= 48 && l:cur_ascii <= 57) ||
            \ (l:cur_ascii >= 65 && l:cur_ascii <= 70 ) ||
            \ (l:cur_ascii >= 97 && l:cur_ascii <= 102)
        else
            let l:curr_line = l:curr_line[0:l:cur_col-2]."0"
                \ .l:curr_line[l:cur_col:]
        endif

        let l:bt_off = s:HexEditUI.ByteOffCalc('hex', l:cur_col)
        let l:curr_line = s:HexEditUI.lineUpdate(l:curr_line,
            \ 'hex', l:bt_off)
    elseif l:area == 'char'
        let l:bt_off = s:HexEditUI.ByteOffCalc('char', l:cur_col)
        let l:curr_line = s:HexEditUI.lineUpdate(l:curr_line,
            \ 'char', l:bt_off)
    endif
    call setline(l:cur_line, l:curr_line)
endfunction

function! s:HexEditUI.OnCursorMovedI()
    call s:HexEditUI.OnCursorMoved()
    if len(b:current_char) != 1
        let b:current_char = ''
        return
    endif
    let l:vchar = b:current_char
    let b:current_char = ''

    let [l:cur_line, l:cur_col] = getpos('.')[1:2]
    let [l:area, l:lv2, l:cmin, l:cmax, l:bmin, l:bmax] =
        \ s:HexEditUI.columnType(l:cur_col-1)

    if l:area == 'hex' || l:area == 'hex-sepa'
        let l:cur_ascii = char2nr(l:vchar)
        if (l:cur_ascii >= 48 && l:cur_ascii <= 57) ||
            \ (l:cur_ascii >= 65 && l:cur_ascii <= 70 ) ||
            \ (l:cur_ascii >= 97 && l:cur_ascii <= 102)
        else
            let l:vchar = '0'
        endif
        let l:bt_off = 0
        let l:curr_line = getline('.')
        if l:area == 'hex-sepa'
            let l:bt_off = g:octets_per_line-1
            let l:curr_line = l:curr_line[0:l:cur_col-7]
                        \.l:vchar.l:curr_line[l:cur_col-5:]

            if line("$") <= l:cur_line
                let l:nextline = s:HexEditUI.allocNewLineAtTail(
                            \s:current_line_offset_number
                            \+g:octets_per_line)
                call setline(l:cur_line+1, l:nextline)
            endif
            call cursor(l:cur_line+1, s:current_line_number_size+3)
        elseif l:area == 'hex' && l:lv2 == 'space'
            let l:bt_off = s:HexEditUI.ByteOffCalc('hex', l:cur_col-2)
            let l:curr_line = l:curr_line[0:l:cur_col-4]
                        \.l:vchar.l:curr_line[l:cur_col-2:]
        elseif l:area == 'hex' && l:lv2 == 'data'
            let l:bt_off = s:HexEditUI.ByteOffCalc('hex', l:cur_col-1)
            let l:curr_line = l:curr_line[0:l:cur_col-3]
                        \.l:vchar.l:curr_line[l:cur_col-1:]
        endif
        let l:curr_line = s:HexEditUI.lineUpdate(l:curr_line,
                \ 'hex', l:bt_off)
        call setline(l:cur_line, l:curr_line)
    elseif l:area == 'char'
        let l:bt_off = s:HexEditUI.ByteOffCalc('char', l:cur_col-1)
        let l:curr_line = getline('.')
        " echom l:bt_off.":".g:octets_per_line.":".l:cur_col.":".s:current_line_max_size
        if l:bt_off < g:octets_per_line
            let l:curr_line = l:curr_line[0:l:cur_col-3].l:vchar.
                        \ l:curr_line[l:cur_col-1:]
            let l:curr_line = s:HexEditUI.lineUpdate(l:curr_line,
                        \ 'char', l:bt_off)
            call setline(l:cur_line, l:curr_line)
            " echom l:bt_off.":".s:current_line_char_area_size
            if l:bt_off == g:octets_per_line - 1
                if line("$") <= l:cur_line
                    let l:nextline = s:HexEditUI.allocNewLineAtTail(
                                \s:current_line_offset_number
                                \+g:octets_per_line)
                    call setline(l:cur_line+1, l:nextline)
                endif
                call cursor(l:cur_line+1, l:cmin)
            endif
        endif
    endif
endfunction

function! s:HexEditUI.allocNewLineAtTail(baseOffset)
    let l:lineFmt = "%0".s:offset_area_size."x: 00%".
                \(s:hex_area_size-3)."s  | ."
    let l:curline = printf(l:lineFmt, 0+a:baseOffset, " ")
    return l:curline
endfunction

function! s:HexEditUI.BuildInCommand(cmd)
endfunction

function! s:HexEditUI.OnBufReadPost()
endfunction

function! s:HexEditUI.OnInsertCharPre()
    let b:current_char = v:char
    let v:char = ''
    let [l:cur_line, l:cur_col] = getpos('.')[1:2]
    if l:cur_col-1 < s:current_line_max_size
        call cursor(l:cur_line, l:cur_col+1)
    else
        let v:char = b:current_char
    endif
endfunction

function! s:HexEditUI.OnBufUnload()
endfunction

function! s:HexEditUI.OnBufWritePre()
    if b:hexEditMode == 1
        silent exe "%!xxd -r ".g:hexmode_xxd_options
    endif
endfunction

function! s:HexEditUI.OnBufWritePost()
    if b:hexEditMode == 1
        call s:HexEditUI.convert2Hex()
    endif
endfunction
