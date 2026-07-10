" Vim syntax file for Hex Edit mode (filetype 'vhex')
if exists("b:current_syntax")
    finish
endif

syn match adr_area "^\x*"
syn match hex_area ":[ 0-9a-fA-F]*"hs=s+1,he=e-1 contains=vhexSep
syn match vhexSep  /:/ contained
syn match vhexLine /|/ contained
syn match chr_area "| .*$"hs=s+1 contains=vhexLine

" Optionally highlight every occurrence of one specific byte value (e.g.
" 0x00) distinctly within the hex column -- opt-in via
" g:hexedit_highlight_byte_value (-1 = disabled, the default, so existing
" users see no change unless they set it).
"
" This must be byte-boundary aware, not a raw text search: within a cell of
" g:group_octets_num bytes there is no separator between adjacent bytes'
" digits (e.g. bytes 0xF0 then 0x0A render as the single cell "f00a"), so a
" naive search for "00" would wrongly highlight across two different bytes.
" One `syn match` is generated per byte offset k (0..group-1) within a
" cell, requiring a real cell boundary (line start / space / colon)
" followed by exactly k complete byte-pairs immediately before the target.
"
" That boundary+prefix check is a LOOKBEHIND (\@<=), not a \zs-adjusted
" ordinary match. \zs only *displays* highlighting starting later, but the
" match still consumes the boundary character as part of its own span for
" scanning purposes -- so if byte 0 of a cell equals the target, its match
" claims the cell's boundary character, and byte 1's pattern (which also
" needs that same boundary to satisfy its own anchor) then finds nothing
" left to anchor to and silently fails to match even though it should.
" (Concretely: content "0000" with target byte 0x00 would highlight only
" the first byte, not the second, with a \zs-based anchor.) A lookbehind
" re-examines the literal preceding text on its own each time regardless
" of what any other syntax item already matched there, so every byte
" offset's pattern succeeds independently.
if get(g:, 'hexedit_highlight_byte_value', -1) >= 0
    let s:hb_hex = printf('%02x', g:hexedit_highlight_byte_value)
    let s:hb_group_octets_num = max([1, get(g:, 'group_octets_num', 2)])
    for s:hb_k in range(s:hb_group_octets_num)
        let s:hb_prefix = '\%(^\|[ :]\)' . repeat('\x\x', s:hb_k)
        execute 'syn match hex_target_byte "\c\%(' . s:hb_prefix
                    \ . '\)\@<=' . s:hb_hex . '" contained containedin=hex_area'
    endfor
    execute 'hi link hex_target_byte ' . get(g:, 'hexedit_highlight_byte_hlgroup', 'NonText')
    unlet s:hb_hex s:hb_group_octets_num s:hb_k s:hb_prefix
endif

" Linked to groups that reliably get an actual distinct color, even under
" Neovim's own built-in default palette with no colorscheme loaded (checked
" empirically: Special/String/Identifier resolve to real cyan/green/blue
" there, while e.g. Constant/Comment/PreCondit/Label all collapse to the
" same flat grey and are visually indistinguishable from plain text).
hi link adr_area SpecialChar
hi link hex_area String
hi link chr_area Identifier
hi link vhexSep  WarningMsg
hi link vhexLine WarningMsg

let b:current_syntax = "vhex"
