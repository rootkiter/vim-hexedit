if exists("loaded_hexedit_ui")
    finish
endif
let loaded_hexedit_ui = 1

let s:hexedit_ui = {}
let g:HexEditEvent = s:hexedit_ui

function! s:hexedit_ui.OpenHexMode()
    let l:group_num  = g:octets_per_line / g:group_octets_num
    let l:group_left = g:octets_per_line % g:group_octets_num
    let s:group_cell_size = g:group_octets_num*2+1
    let l:group_left_size = l:group_left * 2 + (l:group_left>0?1:0)
    let s:hex_area_size   = s:group_cell_size*l:group_num + l:group_left_size
    silent exe "%!xxd " . g:hexmode_xxd_options
                \ . "| sed 's/:\\(.\\{".s:hex_area_size."\\}\\)  /:\\1  | /g'"
    let s:Max_Line_number = line("$")
    if !s:Max_Line_number > 0
        return
    endif
    let l:curline1 = getline(1)
    call s:hexedit_ui.UpdateCurrentLine(l:curline1)
endfunction

function! s:hexedit_ui.UpdateCurrentLine(current_line)
    if !exists('b:editHex') || b:editHex!=1 |
        return
    endif

    let l:clinelist = matchlist(a:current_line,
                \ '^\([a-fA-F0-9]*\):\([ a-fA-F0-9]\{0,'.
                \ s:hex_area_size.'}\)  | \(.*\)$')[1:3]
    if len(l:clinelist)!=3
        return
    endif
    let s:current_line_number_size    = len(l:clinelist[0])
    let s:current_line_hex_area_size  = len(l:clinelist[1])
    let s:current_line_char_area_size = len(l:clinelist[2])
    let s:current_line_max_size       = len(a:current_line)
endfunction

function! s:hexedit_ui.columnType(colnum)
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

function! s:hexedit_ui.moreInput(area, next_min, curline, char)
    if a:area == 'char'
        if s:current_line_char_area_size == g:octets_per_line
            " input char to nextline
            if s:Max_Line_number >= a:curline+1
                let l:next_line = getline(a:curline+1)
                let l:linetmp   = l:next_line[0:a:next_min-2].a:char.l:next_line[a:next_min:]
                let l:next_line = s:hexedit_ui.lineUpdate(l:linetmp, 'char', 0)
                call setline(a:curline+1, l:next_line)
                call cursor (a:curline+1, a:next_min+1)
            else
                " append new line
                " calc new line hex-off && update newline number
            endif
        else
            " append char to current-line's tail
        endif
    " elseif a:area == 'hex'
    endif
endfunction

function! s:hexedit_ui.fixCursor(colnum)
    let l:colnum = a:colnum
    let [l:area, l:lv2, l:cmin, l:cmax, l:bmax, l:nmin] = s:hexedit_ui.columnType(colnum)
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

function! s:hexedit_ui.OnCursorMoved(mode)
    if !exists('b:editHex') || b:editHex!=1 |
        return
    endif

    let l:current_line = getline(".")
    let [l:cur_line, l:cur_col] = getpos('.')[1:2]
    if a:mode == 'normal'
        call s:hexedit_ui.UpdateCurrentLine(l:current_line)
        let l:new_col = s:hexedit_ui.fixCursor(l:cur_col)
        call cursor(l:cur_line, l:new_col)
    elseif a:mode == 'insert'
        let l:new_col = s:hexedit_ui.fixCursor(l:cur_col)
        call cursor(l:cur_line, l:new_col)
    endif
endfunction

function! s:hexedit_ui.ByteOffCalc(area, colnum)
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

function! s:hexedit_ui.lineUpdate(curline, area, bt_off)
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

function! s:hexedit_ui.OnTextChanged()
    if !exists('b:editHex') || b:editHex!=1 |
        return
    endif

    let l:current_line = getline('.')
    let [l:cur_line, l:cur_col] = getpos('.')[1:2]
    let [l:area, l:lv2, l:cmin, l:cmax, l:bmax, l:nmin] =
        \ s:hexedit_ui.columnType(l:cur_col)

    let l:bt_off = s:hexedit_ui.ByteOffCalc(l:area, l:cur_col)
    let l:linetmp = s:hexedit_ui.lineUpdate(l:current_line, l:area, l:bt_off)
    call setline(l:cur_line, l:linetmp)
endfunction

function! s:hexedit_ui.OnTextChangedI()
    if !exists('b:editHex') || b:editHex!=1 |
        return
    endif

    let l:current_line = getline('.')
    let [l:cur_line, l:cur_col] = getpos('.')[1:2]

    if len(l:current_line) > s:current_line_max_size+1
        call setline(l:cur_line, l:current_line[0:s:current_line_max_size])
        return
    elseif len(l:current_line) < s:current_line_max_size+1
        return
    endif

    let [l:area, l:lv2, l:cmin, l:cmax, l:bmax, l:nmin] =
        \ s:hexedit_ui.columnType(l:cur_col-1)

    if l:area == 'hex' && l:lv2 == 'data'
        let l:current_line = l:current_line[0:l:cur_col-2].l:current_line[l:cur_col:]
        let l:bt_off = s:hexedit_ui.ByteOffCalc(l:area, l:cur_col-1)
        let l:current_line = s:hexedit_ui.lineUpdate(l:current_line, l:area, l:bt_off)
    elseif l:area == 'hex' && l:lv2 == 'space'
        let l:curr_char = l:current_line[l:cur_col-3]
        let l:linetmp   = l:current_line[0:l:cur_col-3] .l:current_line[l:cur_col-1:]
        let l:bt_off    = s:hexedit_ui.ByteOffCalc(l:area, l:cur_col-3)
        let l:current_line = s:hexedit_ui.lineUpdate(l:linetmp, l:area, l:bt_off)
        " let l:current_line = l:linetmp
    elseif l:area == 'hex-sepa'
        let l:curr_char = l:current_line[l:cur_col-6]
        let l:linetmp   = l:current_line[0:l:cur_col-6] .l:current_line[l:cur_col-4:]
        let l:bt_off    = s:hexedit_ui.ByteOffCalc('hex', l:cur_col-6)
        let l:current_line = s:hexedit_ui.lineUpdate(l:linetmp, 'hex', l:bt_off)
        if l:cur_line<s:Max_Line_number
            call cursor(l:cur_line+1, s:current_line_number_size+3)
            let l:newline = getline(l:cur_line+1)
            call s:hexedit_ui.UpdateCurrentLine(l:newline)
        endif
    elseif l:area == 'char'
        let l:curr_char = l:current_line[l:cur_col-2]
        let l:linetmp   = l:current_line[0:l:cur_col-2] .l:current_line[l:cur_col:]
        let l:bt_off    = s:hexedit_ui.ByteOffCalc(l:area, l:cur_col-1)
        let l:current_line = s:hexedit_ui.lineUpdate(l:linetmp, l:area, l:bt_off)
    else
        let l:curr_char = l:current_line[l:cur_col-2]
        let l:current_line = l:current_line[0:s:current_line_max_size-1]
        call s:hexedit_ui.moreInput('char', l:nmin, l:cur_line, l:curr_char)
        " call setline(32, "move to next line -> ".l:curr_char)
    endif
    call setline(l:cur_line, l:current_line)
endfunction
