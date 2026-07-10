" hexedit#modes#hexedit - Hex 编辑模式 (REQUIREMENTS 4.1) - Renderable + Editable
"
" Ported from the legacy lib/hexedit_ui.vim, adapted to the Canonical Model /
" registry architecture. Buffer-local `b:hexedit_line_*` variables replace
" the old script-local `s:current_line_*` ones, which were unsafe when more
" than one buffer was in Hex 编辑模式 at the same time.

let s:HexEdit = {}

function! s:HexEdit.Name() abort
    return 'hexedit'
endfunction

function! s:HexEdit.FileType() abort
    return 'vhex'
endfunction

function! s:HexEdit.BinaryToView(model) abort
    return hexedit#model#ToHexDumpLines(a:model)
endfunction

function! s:HexEdit.ViewToBinary(lines, model) abort
    let [l:ok, l:result] = hexedit#model#ParseHexDumpLines(a:lines)
    if !l:ok
        return [0, l:result]
    endif
    let l:model = copy(a:model)
    let l:model.plain_hex = l:result
    let l:model.window_length = len(l:result) / 2
    return [1, l:model]
endfunction

function! s:Geometry(model) abort
    let l:group_octets_num = a:model.group_octets_num
    let l:octets_per_line = a:model.octets_per_line
    let l:m_group_num = l:octets_per_line / l:group_octets_num
    let l:m_group_left = l:octets_per_line % l:group_octets_num
    let l:group_cell_size = l:group_octets_num * 2 + 1
    let l:group_left_size = l:m_group_left * 2 + (l:m_group_left > 0 ? 1 : 0)
    let l:hex_area_size = l:group_cell_size * l:m_group_num + l:group_left_size
    return {'hex_area_size': l:hex_area_size, 'group_cell_size': l:group_cell_size}
endfunction

" ---- Key mapping install/uninstall ----------------------------------------

function! s:HexEdit.OnEnter() abort
    let l:cmdkeys = ['n', 'b', 'h']
    if !exists('b:hexedit_hooked')
        let b:hexedit_hooked = 0
    endif
    if b:hexedit_hooked ==# 0
        for l:key in l:cmdkeys
            exec 'nnoremap <buffer> <silent> ' . l:key . ' :call hexedit#modes#hexedit#NormalKeyMap("' . l:key . '") <CR>'
        endfor
        nnoremap <buffer> <silent> <Left> :call hexedit#modes#hexedit#NormalKeyMap("h") <CR>
        " G/gg are buffer-relative by default, but the buffer is only ever
        " a sliding window into a possibly much larger file (section 5) --
        " override them to mean "end/start of the FILE", reloading the
        " window if needed, not just "end/start of what's currently loaded".
        nnoremap <buffer> <silent> G :call hexedit#modes#hexedit#GotoFileEnd()<CR>
        nnoremap <buffer> <silent> gg :call hexedit#modes#hexedit#GotoFileStart()<CR>
        let b:hexedit_hooked = 1
    endif
endfunction

function! s:HexEdit.OnLeave() abort
    if !exists('b:hexedit_hooked') || b:hexedit_hooked !=# 1
        return
    endif
    for l:key in ['n', 'b', 'h', '<Left>', 'G', 'gg']
        silent! exec 'nunmap <buffer> ' . l:key
    endfor
    let b:hexedit_hooked = 0
endfunction

" ---- Line geometry parsing --------------------------------------------

function! s:UpdateCurrentLine(cur_line) abort
    let l:model = hexedit#registry#CurrentModel()
    let l:geo = s:Geometry(l:model)
    let l:current_line = getline(a:cur_line)
    let l:m = matchlist(l:current_line,
                \ '^\([a-fA-F0-9]*\):\([ a-fA-F0-9]\{0,' . l:geo.hex_area_size . '}\)  | \(.*\)$')
    if len(l:m) < 3
        return 0
    endif
    let b:hexedit_line_number_size = len(l:m[1])
    let b:hexedit_line_hex_area_size = len(l:m[2])
    let b:hexedit_line_char_area_size = len(l:m[3])
    let b:hexedit_line_max_size = len(l:current_line)
    let b:hexedit_line_offset_number = str2nr(l:m[1], 16)
    let b:hexedit_group_cell_size = l:geo.group_cell_size
    let b:hexedit_octets_per_line = l:model.octets_per_line
    return 1
endfunction

" Returns [area, lv2, cmin, cmax, bmax, nmin]
function! s:ColumnType(colnum) abort
    let l:hex_end_off = b:hexedit_line_number_size + b:hexedit_line_hex_area_size + 2
    if a:colnum <= b:hexedit_line_number_size + 1
        return ['addr', 'space', 1, b:hexedit_line_number_size + 1, 0,
                    \ b:hexedit_line_number_size + 2]
    elseif a:colnum <= l:hex_end_off - 1
        let l:lv2 = 'data'
        let l:hex_off = a:colnum - b:hexedit_line_number_size - 2
        if l:hex_off % b:hexedit_group_cell_size ==# 0
            let l:lv2 = 'space'
        endif
        return ['hex', l:lv2, b:hexedit_line_number_size + 2, l:hex_end_off - 1,
                    \ b:hexedit_line_number_size + 1, l:hex_end_off + 4]
    elseif a:colnum < l:hex_end_off + 4
        return ['hex-sepa', 'space', l:hex_end_off, l:hex_end_off + 3,
                    \ l:hex_end_off - 1, l:hex_end_off + 4]
    elseif a:colnum < l:hex_end_off + 4 + b:hexedit_line_char_area_size
        return ['char', 'data', l:hex_end_off + 4, l:hex_end_off + b:hexedit_octets_per_line + 3,
                    \ l:hex_end_off - 1, 0]
    else
        return ['limit', 'space', 0, 0, b:hexedit_line_max_size, l:hex_end_off + 4]
    endif
endfunction

" Positions the cursor exactly on the hex digit for byte `byte_offset`
" (0-indexed, 0..octets_per_line-1) within the CURRENT line. Assumes the
" cursor is already on the right line (e.g. via cursor(line, 1) +
" hexedit#OnCursorMoved()). Used by :HGoto / :Hsearch jumps to land
" precisely on a byte, not just its containing line (REQUIREMENTS 5.6/5.7).
function! hexedit#modes#hexedit#GotoByteInLine(byte_offset) abort
    if !s:UpdateCurrentLine(line('.'))
        return
    endif
    let l:group_octets_num = hexedit#registry#CurrentModel().group_octets_num
    let l:group_id = a:byte_offset / l:group_octets_num
    let l:group_left = a:byte_offset % l:group_octets_num
    let l:col = b:hexedit_line_number_size + 2
                \ + (l:group_id * b:hexedit_group_cell_size) + 1 + l:group_left * 2
    call cursor(line('.'), l:col)
endfunction

function! hexedit#modes#hexedit#NormalKeyMap(key) abort
    let [l:cur_line, l:cur_col] = getpos('.')[1:2]
    if !s:UpdateCurrentLine(l:cur_line)
        exec 'normal! ' . a:key
        return
    endif
    let [l:area, l:lv2, l:cmin, l:cmax, l:bmax, l:nmin] = s:ColumnType(l:cur_col - 1)
    if a:key ==# 'n'
        if exists('b:hexedit_search_pattern') && len(b:hexedit_search_pattern) > 0
            call s:HexSearchNext()
        else
            exec 'normal! ' . a:key
        endif
    elseif l:area ==# 'hex' && l:lv2 ==# 'space' && a:key ==# 'h'
        call cursor(l:cur_line, l:cur_col - 2)
    elseif l:area ==# 'hex-sepa'
        call cursor(l:cur_line, l:bmax)
    else
        exec 'normal! ' . a:key
    endif
endfunction

function! s:FixCursor(colnum) abort
    let l:colnum = a:colnum
    let [l:area, l:lv2, l:cmin, l:cmax, l:bmax, l:nmin] = s:ColumnType(a:colnum)
    if l:area ==# 'addr'
        let l:colnum = l:nmin + 1
    elseif l:area ==# 'hex'
        if l:lv2 ==# 'space'
            let l:colnum = a:colnum + 1
        endif
    elseif l:area ==# 'hex-sepa'
        let l:colnum = l:nmin
    endif
    return l:colnum
endfunction

function! s:HexEdit.OnCursorMoved() abort
    let [l:cur_line, l:cur_col] = getpos('.')[1:2]
    if !s:UpdateCurrentLine(l:cur_line)
        return
    endif
    let l:cur_col = s:FixCursor(l:cur_col)
    call cursor(l:cur_line, l:cur_col)
endfunction

function! s:ByteOffCalc(area, colnum) abort
    if a:area ==# 'hex'
        let l:hex_off = a:colnum - b:hexedit_line_number_size - 2
        let l:group_id = l:hex_off / b:hexedit_group_cell_size
        let l:group_left = (l:hex_off % b:hexedit_group_cell_size - 1) / 2
        return l:group_id * hexedit#registry#CurrentModel().group_octets_num + l:group_left
    elseif a:area ==# 'char'
        let l:char_area_off = b:hexedit_line_number_size + 1 + b:hexedit_line_hex_area_size + 5
        return a:colnum - l:char_area_off
    endif
endfunction

function! s:LineUpdate(curline, area, bt_off) abort
    let l:model = hexedit#registry#CurrentModel()
    let l:group_octets_num = l:model.group_octets_num
    let l:curline = a:curline
    let l:group_id = a:bt_off / l:group_octets_num
    let l:group_left = a:bt_off % l:group_octets_num
    let l:hex_off = b:hexedit_line_number_size + 2
                \ + (l:group_id * b:hexedit_group_cell_size)
                \ + 1 + l:group_left * 2
    let l:char_off = b:hexedit_line_number_size + 2
                \ + b:hexedit_line_hex_area_size + 2 + a:bt_off

    if a:area ==# 'hex'
        let l:hex_data = a:curline[l:hex_off - 1 : l:hex_off]
        let l:linetmp = a:curline[0 : l:char_off]
        let l:ascii = 0 + ('0x' . l:hex_data)
        if l:ascii < 127 && l:ascii > 31
            let l:linetmp .= nr2char(l:ascii)
        else
            let l:linetmp .= '.'
        endif
        let l:linetmp .= a:curline[l:char_off + 2 :]
        let l:curline = l:linetmp
    elseif a:area ==# 'char'
        let l:ascii = char2nr(a:curline[l:char_off + 1])
        let l:hex_data = printf('%02x', l:ascii)
        let l:linetmp = a:curline[0 : l:hex_off - 2]
        let l:linetmp .= l:hex_data
        let l:linetmp .= a:curline[l:hex_off + 1 :]
        let l:curline = l:linetmp
    endif
    return l:curline
endfunction

function! s:HexEdit.OnInsertEnter() abort
    let b:hexedit_paste_flag = 0
    if &paste ==# 1
        let b:hexedit_paste_flag = 1
        set nopaste
    endif
endfunction

function! s:HexEdit.OnInsertLeave() abort
    if exists('b:hexedit_paste_flag') && b:hexedit_paste_flag ==# 1
        let b:hexedit_paste_flag = 0
        set paste
    endif
endfunction

function! s:HexEdit.OnTextChanged() abort
    let [l:cur_line, l:cur_col] = getpos('.')[1:2]
    if !s:UpdateCurrentLine(l:cur_line)
        return
    endif
    let [l:area, l:lv2, l:cmin, l:cmax, l:bmax, l:nmin] = s:ColumnType(l:cur_col)
    let l:orig_line = getline('.')
    let l:curr_line = l:orig_line
    if l:area ==# 'hex' && l:lv2 ==# 'data'
        let l:vchar = l:curr_line[l:cur_col - 1]
        let l:cur_ascii = char2nr(l:vchar)
        if !((l:cur_ascii >= 48 && l:cur_ascii <= 57)
                    \ || (l:cur_ascii >= 65 && l:cur_ascii <= 70)
                    \ || (l:cur_ascii >= 97 && l:cur_ascii <= 102))
            let l:curr_line = l:curr_line[0 : l:cur_col - 2] . '0' . l:curr_line[l:cur_col :]
        endif
        let l:bt_off = s:ByteOffCalc('hex', l:cur_col)
        let l:curr_line = s:LineUpdate(l:curr_line, 'hex', l:bt_off)
    elseif l:area ==# 'char'
        let l:bt_off = s:ByteOffCalc('char', l:cur_col)
        let l:curr_line = s:LineUpdate(l:curr_line, 'char', l:bt_off)
    endif
    " TextChanged fires for ANY buffer text change, including this mode's
    " own programmatic setline() calls during rendering/mode-switching/
    " window reloads -- not just actual user edits (e.g. a paste). Only
    " write back if something would actually be different, so those
    " no-op firings don't themselves dirty the buffer or spam undo history.
    if l:curr_line !=# l:orig_line
        call setline(l:cur_line, l:curr_line)
    endif
endfunction

function! s:HexEdit.OnCursorMovedI() abort
    call s:HexEdit.OnCursorMoved()
    if !exists('b:hexedit_current_char') || len(b:hexedit_current_char) !=# 1
        let b:hexedit_current_char = ''
        return
    endif
    let l:vchar = b:hexedit_current_char
    let b:hexedit_current_char = ''

    let [l:cur_line, l:cur_col] = getpos('.')[1:2]
    if !s:UpdateCurrentLine(l:cur_line)
        return
    endif
    let [l:area, l:lv2, l:cmin, l:cmax, l:bmin, l:bmax] = s:ColumnType(l:cur_col - 1)

    if l:area ==# 'hex' || l:area ==# 'hex-sepa'
        let l:cur_ascii = char2nr(l:vchar)
        if !((l:cur_ascii >= 48 && l:cur_ascii <= 57)
                    \ || (l:cur_ascii >= 65 && l:cur_ascii <= 70)
                    \ || (l:cur_ascii >= 97 && l:cur_ascii <= 102))
            let l:vchar = '0'
        endif
        let l:bt_off = 0
        let l:curr_line = getline('.')
        if l:area ==# 'hex-sepa'
            let l:bt_off = b:hexedit_octets_per_line - 1
            let l:curr_line = l:curr_line[0 : l:cur_col - 7] . l:vchar . l:curr_line[l:cur_col - 5 :]
            if line('$') <= l:cur_line
                call setline(l:cur_line + 1, s:AllocNewLineAtTail(b:hexedit_line_offset_number + b:hexedit_octets_per_line))
            endif
            call cursor(l:cur_line + 1, b:hexedit_line_number_size + 3)
        elseif l:area ==# 'hex' && l:lv2 ==# 'space'
            let l:bt_off = s:ByteOffCalc('hex', l:cur_col - 2)
            let l:curr_line = l:curr_line[0 : l:cur_col - 4] . l:vchar . l:curr_line[l:cur_col - 2 :]
        elseif l:area ==# 'hex' && l:lv2 ==# 'data'
            let l:bt_off = s:ByteOffCalc('hex', l:cur_col - 1)
            let l:curr_line = l:curr_line[0 : l:cur_col - 3] . l:vchar . l:curr_line[l:cur_col - 1 :]
        endif
        let l:curr_line = s:LineUpdate(l:curr_line, 'hex', l:bt_off)
        call setline(l:cur_line, l:curr_line)
    elseif l:area ==# 'char'
        let l:bt_off = s:ByteOffCalc('char', l:cur_col - 1)
        let l:curr_line = getline('.')
        if l:bt_off < b:hexedit_octets_per_line
            let l:curr_line = l:curr_line[0 : l:cur_col - 3] . l:vchar . l:curr_line[l:cur_col - 1 :]
            let l:curr_line = s:LineUpdate(l:curr_line, 'char', l:bt_off)
            call setline(l:cur_line, l:curr_line)
            if l:bt_off ==# b:hexedit_octets_per_line - 1
                if line('$') <= l:cur_line
                    call setline(l:cur_line + 1, s:AllocNewLineAtTail(b:hexedit_line_offset_number + b:hexedit_octets_per_line))
                endif
                call cursor(l:cur_line + 1, l:cmin)
            endif
        endif
    endif
endfunction

function! s:AllocNewLineAtTail(base_offset) abort
    let l:lineFmt = '%0' . get(hexedit#registry#CurrentModel(), 'addr_width', 8) . 'x: 00%'
                \ . (b:hexedit_line_hex_area_size - 3) . 's  | .'
    return printf(l:lineFmt, 0 + a:base_offset, ' ')
endfunction

function! s:HexEdit.OnInsertCharPre() abort
    let b:hexedit_current_char = v:char
    let v:char = ''
    let [l:cur_line, l:cur_col] = getpos('.')[1:2]
    " Defensive: don't assume a prior CursorMoved already populated the
    " b:hexedit_line_* state for this line -- e.g. pressing 'i' as the very
    " first keystroke after opening the buffer (cursor never having moved)
    " would otherwise fall through to plain insertion instead of overwrite.
    call s:UpdateCurrentLine(l:cur_line)
    if l:cur_col - 1 < get(b:, 'hexedit_line_max_size', 0)
        call cursor(l:cur_line, l:cur_col + 1)
    else
        let v:char = b:hexedit_current_char
    endif
endfunction

" ---- Search (:Hsearch / :HsearchClean, REQUIREMENTS 5.7) ------------------
"
" When the current model is backed by a real file (model.path != ''), search
" the whole file via hexedit#model#SearchFile (a lazy tail|xxd|tr|grep
" pipeline -- see model.vim for why), regardless of whether we're in
" large-file windowed mode. This is what makes `n` able to jump outside the
" currently loaded window. When there is no backing file (e.g. content only
" ever loaded via :HexLoad and never saved), fall back to the legacy
" buffer-text-only search (s:HexSearchNextInBuffer), since there is no file
" on disk to search.

function! s:HexEdit.BuildInCommand(cmd, arg1) abort
    if a:cmd ==# 'Hsearch'
        if len(a:arg1) % 2 !=# 0 || a:arg1 !~? '^\x\+$'
            echom 'Please use a legal hex sequence.'
            return
        endif
        let b:hexedit_search_pattern_raw = tolower(a:arg1)
        let l:split_patt = '\(\x\{2}\)\(\x\{2}\)'
        let l:split_patt_to = '\1 \2'
        let l:patt = substitute(b:hexedit_search_pattern_raw, l:split_patt, l:split_patt_to, 'g')
        let l:patt = substitute(l:patt, l:split_patt, l:split_patt_to, 'g')
        let b:hexedit_search_pattern = l:patt
        unlet! b:hexedit_search_last_offset
        call s:HexSearchNext()
    elseif a:cmd ==# 'HsearchClean'
        let b:hexedit_search_pattern = ''
        let b:hexedit_search_pattern_raw = ''
        unlet! b:hexedit_search_last_offset
    endif
endfunction

" Absolute file offset of the current cursor line, used as the starting
" point for the first file-based search (repeats use the previous match's
" end offset instead, see s:HexSearchNext).
function! s:CurrentAbsoluteOffset() abort
    let l:model = hexedit#registry#CurrentModel()
    if s:UpdateCurrentLine(line('.'))
        return b:hexedit_line_offset_number
    endif
    return l:model.window_offset
endfunction

function! s:HexSearchNext() abort
    let l:model = hexedit#registry#CurrentModel()
    if l:model.path ==# ''
        call s:HexSearchNextInBuffer()
        return
    endif
    let l:start = get(b:, 'hexedit_search_last_offset', s:CurrentAbsoluteOffset())
    let [l:found, l:match_offset, l:match_len] = hexedit#model#SearchFile(
                \ l:model, b:hexedit_search_pattern_raw, l:start)
    if !l:found
        echom "Didn't find pattern -> `" . b:hexedit_search_pattern_raw . '`'
        unlet! b:hexedit_search_last_offset
        return
    endif
    let b:hexedit_search_last_offset = l:match_offset + l:match_len
    call hexedit#GotoAbsoluteOffset(l:match_offset)
endfunction

" ---- Legacy buffer-text-only search (used only when model.path is empty) --

function! s:SeartInWindow(lines, li_num, li_col, pattern) abort
    let l:windowlensize = 100
    let l:fmt = '\(\x\{' . b:hexedit_line_number_size
                \ . '}\):\(.\{' . b:hexedit_line_hex_area_size
                \ . '}\)  | \(.*\)'
    let l:split_fmt = ' \(\x\{2}\)\(\x\{2}\)'
    let l:split_tfmt = ' \1 \2'
    let l:bt_off = s:ByteOffCalc('hex', a:li_col)

    let l:line_total = len(a:lines)
    let l:hexbuffer = ''
    let l:cursor = 0
    while l:cursor < l:windowlensize
        let l:cur_cursor = a:li_num + l:cursor - 1
        if l:line_total <= l:cur_cursor
            break
        endif
        let l:res = matchlist(a:lines[l:cur_cursor], l:fmt)
        if len(l:res) < 4
            break
        endif
        let l:hexbuffer .= l:res[2]
        let l:cursor += 1
    endwhile
    let l:hexbuffer = substitute(l:hexbuffer, l:split_fmt, l:split_tfmt, 'g')
    let l:offset = match(l:hexbuffer, a:pattern, (l:bt_off + 1) * 3)

    if l:offset > 0
        let l:offnow = l:offset / 3
        let l:resline = l:offnow / b:hexedit_octets_per_line + a:li_num
        let l:resleftbts = l:offnow % b:hexedit_octets_per_line
        let l:rescol = (l:resleftbts / hexedit#registry#CurrentModel().group_octets_num) * b:hexedit_group_cell_size
                    \ + (l:resleftbts % hexedit#registry#CurrentModel().group_octets_num) * 2
                    \ + 1 + b:hexedit_line_number_size + 2
        return [1, l:resline, l:rescol]
    else
        let l:pattbts = a:pattern / 3
        let l:needlen = l:pattbts / b:hexedit_octets_per_line
        let l:nextline = a:li_num + l:windowlensize - 1 - l:needlen
        return [2, l:nextline, b:hexedit_line_number_size + 2]
    endif
endfunction

function! s:HexSearchNextInBuffer() abort
    let l:lines = getline(0, line('$'))
    let [l:cur_line, l:cur_col] = getpos('.')[1:2]
    if !s:UpdateCurrentLine(l:cur_line)
        return
    endif
    let [l:tmpline, l:tmpcol] = [l:cur_line, l:cur_col]
    while l:tmpline <= len(l:lines)
        let l:res = s:SeartInWindow(l:lines, l:tmpline, l:tmpcol, b:hexedit_search_pattern)
        if l:res[0] ==# 1
            call cursor(l:res[1], l:res[2])
            return
        elseif l:res[0] ==# 2
            if l:res[1] > 0
                let l:tmpline = l:res[1]
                let l:tmpcol = l:res[2]
            else
                break
            endif
        endif
    endwhile
    echom "Didn't find pattern -> `" . b:hexedit_search_pattern . '`'
endfunction

" G / gg overrides (see s:HexEdit.OnEnter): jump to the end/start of the
" whole FILE, not just whatever is currently loaded in the buffer.
function! hexedit#modes#hexedit#GotoFileEnd() abort
    let l:model = hexedit#registry#CurrentModel()
    if !l:model.is_windowed
        normal! G
        call hexedit#OnCursorMoved()
        return
    endif
    if l:model.total_size <= 0
        return
    endif
    call hexedit#GotoAbsoluteOffset(l:model.total_size - 1)
endfunction

function! hexedit#modes#hexedit#GotoFileStart() abort
    let l:model = hexedit#registry#CurrentModel()
    if !l:model.is_windowed
        normal! gg
        call hexedit#OnCursorMoved()
        return
    endif
    call hexedit#GotoAbsoluteOffset(0)
endfunction

function! hexedit#modes#hexedit#Get() abort
    return s:HexEdit
endfunction
