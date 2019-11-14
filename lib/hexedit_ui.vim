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
    let l:cmdkeys = ['n', 'b', 'h']
	if !exists("b:hooked")
		let b:hooked = 0
	endif
    if b:hooked == 0
        for key in l:cmdkeys
            exec "nnoremap <silent> ".key." :call g:HexEditUI.NormalKeyMap(\"".key."\") <CR>"
        endfor
        let b:hooked = 1
    endif
endfunction

function! s:HexEditUI.hookUninstall()
    if !exists("b:hooked") || b:hooked != 1
        return
    endif
    let l:cmdkeys = ['n', 'b', 'h']
    for key in l:cmdkeys
        " exec "nunmap ".key
    endfor
    let b:hooked = 0
endfunction

function! s:HexEditUI.EnterEditMode()
    call s:HexEditUI.hookInstall()
endfunction

function! s:HexEditUI.QuitEditMode()
    call s:HexEditUI.hookUninstall()
endfunction

function! s:HexEditUI.StartUp()
    let b:hexEditMode      = 1
    let b:hex_area_size    = g:hex_area_size
    let b:offset_area_size = g:offset_area_size
    let b:group_cell_size  = g:group_cell_size
    call s:HexEditUI.InitVars()
    call s:HexEditUI.convert2Hex()
    call s:HexEditUI.EnterEditMode()
endfunction

function! s:HexEditUI.InitVars()
    let s:cursearchoff = 0
    let s:cursearchpattern = ""
endfunction

function! s:HexEditUI.convert2Hex()
    silent exe "%!xxd ". g:hexedit_xxd_options
                \ . "| sed 's/:\\(.\\{".g:hex_area_size."\\}\\)  /:\\1  | /g'"
    let b:oldft = &l:ft
    let &l:ft   = 'xxd'
endfunction

function! s:HexEditUI.Stop()
    let &l:ft = b:oldft
    let b:hexEditMode = 0
    silent exe "%!xxd -r ".g:hexedit_xxd_options
    call s:HexEditUI.QuitEditMode()
endfunction

function! s:HexEditUI.CreateNewFile()
    let b:hexEditMode      = 1
    call s:HexEditUI.InitVars()
    let l:curline = s:HexEditUI.allocNewLineAtTail(0)
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
                \ g:hex_area_size.'}\)  | \(.*\)$')[1:3]
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
        return ["addr", 'space', 1, s:current_line_number_size+1, 0,
                    \ s:current_line_number_size+2]
    elseif a:colnum <= l:hex_end_off-1
        let l:lv2 = 'data'
        let l:hex_off = a:colnum-s:current_line_number_size-2
        if l:hex_off % b:group_cell_size == 0
            let l:lv2 = 'space'
        endif
        return ['hex', l:lv2, s:current_line_number_size+2, l:hex_end_off-1,
                    \ s:current_line_number_size+1, l:hex_end_off+4]
    elseif a:colnum < l:hex_end_off+4
        return ['hex-sepa', 'space', l:hex_end_off, l:hex_end_off+3,
                    \ l:hex_end_off-1, l:hex_end_off+4]
    elseif a:colnum < l:hex_end_off+4+s:current_line_char_area_size
        return ['char', 'data', l:hex_end_off+4, l:hex_end_off+g:octets_per_line+3,
                    \ l:hex_end_off-1, 0]
    else
        return ['limit', 'space', 0, 0, s:current_line_max_size, l:hex_end_off+4]
    endif
endfunction

function! s:HexEditUI.NormalKeyMap(key)
    let [l:cur_line, l:cur_col] = getpos('.')[1:2]
    let [l:area, l:lv2, l:cmin, l:cmax, l:bmax, l:nmin] =
                \ s:HexEditUI.columnType(l:cur_col-1)
    if a:key == 'n'
        if len(s:cursearchpattern) > 0
            call s:HexEditUI.hexSearchNext()
        else
            exec "normal! ".a:key
        endif
    elseif l:area == 'hex' && l:lv2 == 'space' && a:key == 'h'
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
        let l:group_id   = l:hex_off / b:group_cell_size
        let l:group_left = (l:hex_off % b:group_cell_size - 1)/2
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
                \(l:group_id * b:group_cell_size) +
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

function! s:HexEditUI.OnInsertEnter()
    let b:hexedit_paste_flag = 0
    if &paste == 1
        let b:hexedit_paste_flag = 1
        set nopaste
        echom "hook -> ".b:hexedit_paste_flag.":".&paste
    endif
endfunction

function! s:HexEditUI.OnInsertLeave()
    if exists("b:hexedit_paste_flag") && b:hexedit_paste_flag == 1
        let b:hexedit_paste_flag = 0
        set paste
    endif
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
        if l:bt_off < g:octets_per_line
            let l:curr_line = l:curr_line[0:l:cur_col-3].l:vchar.
                        \ l:curr_line[l:cur_col-1:]
            let l:curr_line = s:HexEditUI.lineUpdate(l:curr_line,
                        \ 'char', l:bt_off)
            call setline(l:cur_line, l:curr_line)
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
    let l:lineFmt = "%0".b:offset_area_size."x: 00%".
                \(b:hex_area_size-3)."s  | ."
    let l:curline = printf(l:lineFmt, 0+a:baseOffset, " ")
    return l:curline
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

function! s:HexEditUI.BuildInCommand(cmd, arg1)
    if a:cmd == 'Hexsearch'
        let l:lines = getline(1, line('$'))
        if len(a:arg1)%2 !=0
            echom "Please use legal hex sequence."
            return
        endif
        let l:split_patt = "\\(\\x\\{2}\\)\\(\\x\\{2}\\)"
        let l:split_patt_to = "\\1 \\2"
        let l:patt = substitute(a:arg1,
                    \ l:split_patt, l:split_patt_to, 'g')
        let l:patt = substitute(l:patt,
                    \ l:split_patt, l:split_patt_to, 'g')
        let s:cursearchpattern = l:patt
        let s:cursearchoff = 0
        call s:HexEditUI.hexSearchNext()
    elseif a:cmd == 'HexsearchClean'
        let s:cursearchpattern = ''
        let s:cursearchoff = 0
    endif
endfunction

function! s:HexEditUI.hexSearchNext()
    let l:lines = getline(1, line('$'))
    let l:fmt = "\\(\\x\\{".b:offset_area_size.
                \ "}\\):\\(.\\{".b:hex_area_size.
                \ "}\\)  | \\(.*\\)"
    let l:split_fmt  = " \\(\\x\\{2}\\)\\(\\x\\{2}\\)"
    let l:split_tfmt = " \\1 \\2"
    let l:hex_area = ""
    for l:line in l:lines
        let l:res = matchlist(l:line, l:fmt)
        let l:tmp1 = substitute(l:res[2],
                    \l:split_fmt, l:split_tfmt, 'g')
        let l:tmp1 = substitute(l:tmp1,
                    \l:split_fmt, l:split_tfmt, 'g')
        let l:hex_area .= l:tmp1
    endfor
    let l:offset = match(l:hex_area, s:cursearchpattern,
                \s:cursearchoff)
    let s:cursearchoff = l:offset + 2
    let l:tt_off = ((l:offset-1)/3)

    let l:line_num = l:tt_off / g:octets_per_line + 1
    let l:bt_off   = l:tt_off % g:octets_per_line
    let l:group    = l:bt_off / g:group_octets_num
    let l:left     = l:bt_off % g:group_octets_num

    let l:col_off  = s:current_line_number_size + 3 +
                \ l:group * b:group_cell_size + l:left*2
    call cursor(l:line_num, l:col_off)
endfunction

function! s:HexEditUI.OnBufReadPost()
endfunction

function! s:HexEditUI.OnBufWritePre()
    if b:hexEditMode == 1
        silent exe "%!xxd -r ".g:hexedit_xxd_options
    endif
endfunction

function! s:HexEditUI.OnBufWritePost()
    if b:hexEditMode == 1
        call s:HexEditUI.convert2Hex()
    endif
endfunction
