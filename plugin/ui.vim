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
    if !exists('b:editHex') || b:editHex!=1 |
        return
    endif

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

function! s:hexedit_ui.moreInput(area, next_min, curline, curcol, char)
    if !exists('b:editHex') || b:editHex!=1 |
        return
    endif

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
                let l:cur_line = getline(a:curline)
                let l:cur_num  = "0x".l:cur_line[0:s:current_line_number_size-1]+0
                            \+g:octets_per_line
                let l:next_num = printf("%0".s:current_line_number_size."X:",
                            \l:cur_num)
                let l:hex_tmp  = char2nr(a:char)
                let l:hex_data = printf(" %02X", l:hex_tmp)
                let l:nop_space = printf("%".(s:current_line_hex_area_size-3)."s", " " )
                let l:hex_area = l:hex_data. l:nop_space."  | ".a:char
                let l:nextline = l:next_num.l:hex_area
                call setline(a:curline+1, l:nextline)
                call cursor(a:curline+1, a:next_min+1)
                " calc new line hex-off && update newline number
            endif
        else
            " append char to current-line's tail
            let l:bt_off = s:current_line_char_area_size
            let l:cur_line = getline(a:curline).a:char
            let l:cur_line = s:hexedit_ui.lineUpdate(l:cur_line, 'char', l:bt_off)
            call setline(a:curline, l:cur_line)
            call cursor (a:curline, a:curcol+1)
        endif
    elseif a:area == 'hex'
        if s:current_line_char_area_size == g:octets_per_line
            " input char to nextline
            if s:Max_Line_number >= a:curline+1
                " just append
                let l:next_line = getline(a:curline+1)
                let l:next_min  = s:current_line_number_size+1
                let l:linetmp   = l:next_line[0:l:next_min].a:char.l:next_line[l:next_min+2:]
                let l:next_line = s:hexedit_ui.lineUpdate(l:linetmp, 'hex', 0)
                call setline(a:curline+1, l:next_line)
                call cursor (a:curline+1, l:next_min+3)
            else
                " fresh new line
                let l:cur_line = getline(a:curline)
                let l:cur_num  = "0x".l:cur_line[0:s:current_line_number_size-1]+0+g:octets_per_line
                let l:next_num = printf("%0".s:current_line_number_size."X:", l:cur_num)
                let l:hex_data = " ".a:char."0"
                let l:nop_space = printf("%".(s:current_line_hex_area_size-3)."s", " " )
                let l:next_tmp  = l:next_num.l:hex_data.l:nop_space."  | "
                let l:next_tmp  = s:hexedit_ui.lineUpdate(l:next_tmp, 'hex', 0)
                call setline(a:curline+1, l:next_tmp)
                call cursor (a:curline+1, s:current_line_number_size+4)
            endif
        else
            " append char to current-line's tail
            let l:current_line = getline(a:curline)
            let l:hex_bt_off = a:curcol-s:current_line_number_size-3
            let l:group_left = l:hex_bt_off % s:group_cell_size - 1
            if (l:group_left % 2) == 0
                let l:current_line = l:current_line[0:a:curcol-3].a:char."0".l:current_line[a:curcol:]
            endif
            let l:bt_off = s:current_line_char_area_size
            let l:cur_line = s:hexedit_ui.lineUpdate(l:current_line, 'hex', l:bt_off)
            call setline(a:curline, l:cur_line)
        endif
    endif
    call s:hexedit_ui.OnCursorMoved('minsert')
endfunction

function! s:hexedit_ui.fixCursor(colnum, mode)
    if !exists('b:editHex') || b:editHex!=1 |
        return
    endif

    let l:colnum = a:colnum
    let [l:area, l:lv2, l:cmin, l:cmax, l:bmax, l:nmin] = s:hexedit_ui.columnType(colnum)
    if l:area == 'addr'
        let l:colnum = l:nmin+1
    elseif l:area == 'hex'
        if l:lv2 == 'space'
            let l:colnum = a:colnum + 1
        endif
    elseif l:area == 'hex-sepa'
        if a:mode == 'normal'
            let l:colnum = l:nmin
        endif
    endif
    return l:colnum
endfunction

function! s:hexedit_ui.OnCursorMoved(mode)
    if !exists('b:editHex') || b:editHex!=1 |
        return
    endif

    let l:current_line = getline(".")
    if a:mode == 'normal' || a:mode == 'minsert'
        call s:hexedit_ui.UpdateCurrentLine(l:current_line)
    endif
    let [l:cur_line, l:cur_col] = getpos('.')[1:2]
    let l:new_col = s:hexedit_ui.fixCursor(l:cur_col, a:mode)
    call cursor(l:cur_line, l:new_col)
endfunction

function! s:hexedit_ui.ByteOffCalc(area, colnum)
    if !exists('b:editHex') || b:editHex!=1 |
        return
    endif

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
    if !exists('b:editHex') || b:editHex!=1 |
        return
    endif

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

    let l:setline_flag = 1
    if l:area == 'hex' && l:lv2 == 'data'
        let l:current_line = l:current_line[0:l:cur_col-2].l:current_line[l:cur_col:]
        let l:bt_off = s:hexedit_ui.ByteOffCalc(l:area, l:cur_col-1)
        if l:bt_off == s:current_line_char_area_size
            " append new char to tail
            let l:curr_char = l:current_line[l:cur_col-2]
            let l:current_line = l:current_line[0:l:cur_col-3] ." " .l:current_line[l:cur_col-1:]
            call setline(l:cur_line, l:current_line)
            call s:hexedit_ui.moreInput('hex', l:bmax, l:cur_line, l:cur_col, l:curr_char)
            let l:setline_flag = 0
        else
            let l:current_line = s:hexedit_ui.lineUpdate(l:current_line, l:area, l:bt_off)
        endif
    elseif l:area == 'hex' && l:lv2 == 'space'
        let l:curr_char = l:current_line[l:cur_col-3]
        let l:linetmp   = l:current_line[0:l:cur_col-3] .l:current_line[l:cur_col-1:]
        let l:bt_off    = s:hexedit_ui.ByteOffCalc(l:area, l:cur_col-3)
        let l:current_line = s:hexedit_ui.lineUpdate(l:linetmp, l:area, l:bt_off)
        " let l:current_line = l:linetmp
    elseif l:area == 'hex-sepa'
        let l:curr_char    = l:current_line[l:cur_col-2]
        let l:current_line = l:current_line[0:l:cur_col-3]." " .l:current_line[l:cur_col:]
        call s:hexedit_ui.moreInput('hex', l:cmin, l:cur_line, l:cur_col, l:curr_char)
    elseif l:area == 'char'
        let l:curr_char = l:current_line[l:cur_col-2]
        let l:linetmp   = l:current_line[0:l:cur_col-2] .l:current_line[l:cur_col:]
        let l:bt_off    = s:hexedit_ui.ByteOffCalc(l:area, l:cur_col-1)
        let l:current_line = s:hexedit_ui.lineUpdate(l:linetmp, l:area, l:bt_off)
    else
        let l:curr_char = l:current_line[l:cur_col-2]

        if s:current_line_max_size < len(l:current_line)
            let l:current_line = l:current_line[0:s:current_line_max_size-1]
            call setline(l:cur_line, l:current_line)
        endif
        call s:hexedit_ui.moreInput('char', l:nmin, l:cur_line, l:cur_col, l:curr_char)
        let l:setline_flag = 0
    endif
    if l:setline_flag == 1
        call setline(l:cur_line, l:current_line)
    endif
endfunction

function! s:hexedit_ui.cursorCmdHook(cmd)
    let [l:cur_line, l:cur_col] = getpos('.')[1:2]
    let [l:area, l:lv2, l:cmin, l:cmax, l:bmax, l:nmin] =
                \g:HexEditEvent.columnType(l:cur_col-1)

    if l:area == 'hex'
        if (l:lv2 == 'data' && a:cmd == 'h') || a:cmd == 'b'
            exec "normal! ".a:cmd
        elseif l:lv2 =='space'
            call cursor(l:cur_line, l:cur_col-2)
        endif
    elseif l:area == 'hex-sepa'
        if a:cmd == 'h' || a:cmd == 'b'
            call cursor(l:cur_line, l:bmax)
        endif
    elseif l:area == 'char'
        exec "normal! ".a:cmd
    endif
endfunction

function! s:hexedit_ui.OnInputCharacter()
    if !exists('b:editHex') || b:editHex!=1 |
        return
    endif

    let s:char = v:char
    echom "CurrentInput -> ".v:char
endfunction

function! s:hexedit_ui.KeepHex()

endfunction

function! s:hexedit_ui.insertKeyTrigger(key)
    " if a:key == "CR"
    "     exec "normal l"
    " elseif a:key == 'BS'
    "     exec "normal h"
    " endif
endfunction

function! s:hexedit_ui.CursorCmdHook(mode)
    if !exists('b:editHex') || b:editHex!=1 |
        return
    endif

    let l:cmdkeys = ['h', 'b']
    if a:mode == 'install'
        for key in l:cmdkeys
            exec "nnoremap <silent> ".key." :call g:HexEditEvent.cursorCmdHook(\"".key."\") <CR>"
        endfor
        inoremap <silent> <CR> <ESC>:call g:HexEditEvent.insertKeyTrigger("CR")<CR>a
        inoremap <silent> <BS> <ESC>:call g:HexEditEvent.insertKeyTrigger("BS")<CR>a
    elseif a:mode == 'uninstall'
        for key in l:cmdkeys
            exec "nunmap ".key
        endfor
        iunmap <BS>
        iunmap <CR>
    endif
endfunction
