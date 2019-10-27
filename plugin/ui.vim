if exists("loaded_hexedit_ui")
    finish
endif
let loaded_hexedit_ui = 1

let s:hexedit_ui = {}
let g:HexEditEvent = s:hexedit_ui

function! s:hexedit_ui.OpenHexMode()
    let l:group_num  = g:octets_per_line / g:group_octets_num
    let l:group_left = g:octets_per_line % g:group_octets_num
    let l:group_cell_size = g:group_octets_num*2+1
    let l:group_left_size = l:group_left * 2 + 1
    let s:hex_area_size   = l:group_cell_size*l:group_num + l:group_left_size
    silent exe "%!xxd " . g:hexmode_xxd_options
                \ . "| sed 's/:\\(.\\{".s:hex_area_size."\\}\\)  /:\\1  | /g'"
    let l:line_size = line("$")
    if !l:line_size > 0
        return
    endif
    let l:curline1 = getline(1)
    call s:hexedit_ui.UpdateCurrentLine(l:curline1)
endfunction

function! s:hexedit_ui.UpdateCurrentLine(current_line)
    let l:clinelist = matchlist(a:current_line, '^\([a-fA-F0-9]*\):\([ a-fA-F0-9]\{0,'.s:hex_area_size.'}\)  | \(.*\)$')[1:3]
    let s:current_line_number_size    = len(l:clinelist[0])
    let s:current_line_hex_area_size  = len(l:clinelist[1])
    let s:current_line_char_area_size = len(l:clinelist[2])
endfunction

function! s:hexedit_ui.columnType(colnum)
    let l:hex_end_off = s:current_line_number_size+s:current_line_hex_area_size+2
    if a:colnum<=s:current_line_number_size+1
        return ["addr", 'space', 1, s:current_line_number_size+1, 0, s:current_line_number_size+2]
    elseif a:colnum <= l:hex_end_off-1
        return ['hex', 'data', s:current_line_number_size+2, l:hex_end_off-1, s:current_line_number_size+1, l:hex_end_off+4]
    elseif a:colnum < l:hex_end_off+4
        return ['hex-sepa', 'space', l:hex_end_off, l:hex_end_off+3, l:hex_end_off-1, l:hex_end_off+4]
    elseif a:colnum <= l:hex_end_off+4+s:current_line_char_area_size
        return ['char', 'data', l:hex_end_off+4, l:hex_end_off+g:octets_per_line+3, l:hex_end_off-1, 0]
    endif
endfunction

function! s:hexedit_ui.OnCursorMoved(cmd)
    let [l:cur_line, l:cur_col] = getpos('.')[1:2]
    " call setline(2, s:hexedit_ui.columnType(l:cur_col))
endfunction
