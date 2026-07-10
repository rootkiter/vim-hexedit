" Tests for syntax/vhex.vim's optional target-byte highlighting
" (g:hexedit_highlight_byte_value / g:hexedit_highlight_byte_hlgroup).
"
" These need `:syntax on` + `:filetype plugin on` active (unlike the rest
" of the suite, which never touches syntax) since the feature is
" implemented entirely as `syn match`/`hi link` commands sourced via the
" normal FileType-triggered `:runtime! syntax/vhex.vim` mechanism.

function! s:WriteBytesFile(path, hexcontent) abort
    call system(['sh', '-c', 'xxd -r -p > ' . shellescape(a:path)], a:hexcontent)
endfunction

" Returns the (untranslated) syntax group name at 1-indexed (line, col).
function! s:SynAt(lnum, col) abort
    return synIDattr(synID(a:lnum, a:col, 1), 'name')
endfunction

function! s:SetUp() abort
    syntax on
    filetype plugin on
endfunction

function! Test_Syntax_TargetByte_DisabledByDefault() abort
    call s:SetUp()
    let l:saved = g:hexedit_highlight_byte_value
    let g:hexedit_highlight_byte_value = -1

    let l:path = tempname() . '.dat'
    call s:WriteBytesFile(l:path, '0041f00a')
    execute 'edit ' . fnameescape(l:path)

    " column 11 = first hex digit of byte0 (0x00); must NOT be the
    " target-byte group when the feature is off.
    call assert_notequal('hex_target_byte', s:SynAt(1, 11))

    bwipeout!
    call delete(l:path)
    let g:hexedit_highlight_byte_value = l:saved
endfunction

function! Test_Syntax_TargetByte_MatchesRealByteNotBoundarySpan() abort
    call s:SetUp()
    let l:saved = [g:hexedit_highlight_byte_value, g:hexedit_highlight_byte_hlgroup]
    let g:hexedit_highlight_byte_value = 0
    let g:hexedit_highlight_byte_hlgroup = 'NonText'

    " bytes: 00 41 f0 0a  (group_octets_num=2 default -> cells "0041" "f00a")
    " The middle of "f00a" also contains the literal substring "00" (from
    " the end of 0xf0 + the start of 0x0a) but that is NOT byte 0x00 and
    " must not be highlighted -- this is the exact bug class the
    " byte-boundary-aware pattern generation exists to avoid.
    let l:path = tempname() . '.dat'
    call s:WriteBytesFile(l:path, '0041f00a')
    execute 'edit ' . fnameescape(l:path)

    " rendered line: "00000000: 0041 f00a  ...padding...  | .A.."
    " cols 11-12 = byte0 (0x00), 13-14 = byte1 (0x41), 16-19 = "f00a" cell
    " (byte2=0xf0 at 16-17, byte3=0x0a at 18-19), verified via 0-indexed
    " substring slices (col N is index N-1).
    call assert_equal('00', getline(1)[10:11])
    call assert_equal('41', getline(1)[12:13])
    call assert_equal('f00a', getline(1)[15:18])

    " byte0 (0x00): real match
    call assert_equal('hex_target_byte', s:SynAt(1, 11))
    call assert_equal('hex_target_byte', s:SynAt(1, 12))
    " byte1 (0x41): not a match
    call assert_notequal('hex_target_byte', s:SynAt(1, 13))
    call assert_notequal('hex_target_byte', s:SynAt(1, 14))
    " the false-positive "00" spanning byte2/byte3 inside cell "f00a"
    " (the literal substring "00" sits at cols 17-18: end of 0xf0 + start
    " of 0x0a) must NOT match -- this is the exact bug the byte-boundary
    " -aware pattern generation exists to avoid.
    call assert_equal('00', getline(1)[16:17])
    call assert_notequal('hex_target_byte', s:SynAt(1, 17))
    call assert_notequal('hex_target_byte', s:SynAt(1, 18))

    bwipeout!
    call delete(l:path)
    let [g:hexedit_highlight_byte_value, g:hexedit_highlight_byte_hlgroup] = l:saved
endfunction

function! Test_Syntax_TargetByte_BothBytesInCellMatchTarget() abort
    " Regression test: content "0000" (both bytes in the cell equal the
    " target 0x00) must highlight BOTH bytes, not just the first. A \zs
    " -based anchor (rather than a lookbehind \@<=) fails this: once byte
    " 0's match consumes the cell's boundary character, byte 1's pattern
    " -- which needs that same boundary for its own anchor -- finds
    " nothing left to anchor to and silently doesn't match.
    call s:SetUp()
    let l:saved = [g:hexedit_highlight_byte_value, g:hexedit_highlight_byte_hlgroup]
    let g:hexedit_highlight_byte_value = 0
    let g:hexedit_highlight_byte_hlgroup = 'NonText'

    let l:path = tempname() . '.dat'
    call s:WriteBytesFile(l:path, '0000')
    execute 'edit ' . fnameescape(l:path)
    call assert_equal('0000', getline(1)[10:13])

    " query byte1 (the one that broke) before byte0, on principle -- see
    " the query-ordering note on Test_Syntax_TargetByte_CustomValueAndHlgroup.
    call assert_equal('hex_target_byte', s:SynAt(1, 13))
    call assert_equal('hex_target_byte', s:SynAt(1, 14))
    call assert_equal('hex_target_byte', s:SynAt(1, 11))
    call assert_equal('hex_target_byte', s:SynAt(1, 12))

    bwipeout!
    call delete(l:path)
    let [g:hexedit_highlight_byte_value, g:hexedit_highlight_byte_hlgroup] = l:saved
endfunction

function! Test_Syntax_TargetByte_AllBytesInCellMatchTarget_GroupThree() abort
    " Same regression, generalized: with group_octets_num=3 (3 bytes per
    " cell, no separators), all three bytes equal to the target must all
    " be highlighted.
    call s:SetUp()
    let l:saved = [g:hexedit_highlight_byte_value, g:group_octets_num]
    let g:hexedit_highlight_byte_value = 0
    let g:group_octets_num = 3

    let l:path = tempname() . '.dat'
    call s:WriteBytesFile(l:path, '000000')
    execute 'edit ' . fnameescape(l:path)
    call assert_equal('000000', getline(1)[10:15])

    for l:col in [15, 14, 13, 12, 11]
        call assert_equal('hex_target_byte', s:SynAt(1, l:col), 'col ' . l:col)
    endfor

    bwipeout!
    call delete(l:path)
    let [g:hexedit_highlight_byte_value, g:group_octets_num] = l:saved
endfunction

function! Test_Syntax_TargetByte_GroupOctetsNumOne() abort
    call s:SetUp()
    let l:saved = [g:hexedit_highlight_byte_value, g:group_octets_num]
    let g:hexedit_highlight_byte_value = 0
    let g:group_octets_num = 1

    " bytes: 00 41  (group_octets_num=1 -> cells "00" "41", space-separated)
    let l:path = tempname() . '.dat'
    call s:WriteBytesFile(l:path, '0041')
    execute 'edit ' . fnameescape(l:path)

    let l:line = getline(1)
    " "00000000: 00 41 ..." -- byte0 at cols 11-12, byte1 at cols 14-15
    call assert_equal('hex_target_byte', s:SynAt(1, 11))
    call assert_equal('hex_target_byte', s:SynAt(1, 12))
    call assert_notequal('hex_target_byte', s:SynAt(1, 14))
    call assert_notequal('hex_target_byte', s:SynAt(1, 15))

    bwipeout!
    call delete(l:path)
    let [g:hexedit_highlight_byte_value, g:group_octets_num] = l:saved
endfunction

function! Test_Syntax_TargetByte_CustomValueAndHlgroup() abort
    call s:SetUp()
    let l:saved = [g:hexedit_highlight_byte_value, g:hexedit_highlight_byte_hlgroup]
    let g:hexedit_highlight_byte_value = 255
    let g:hexedit_highlight_byte_hlgroup = 'ErrorMsg'

    let l:path = tempname() . '.dat'
    call s:WriteBytesFile(l:path, '00ff')
    execute 'edit ' . fnameescape(l:path)

    " Query the expected-match column before the expected-non-match column.
    " Verified empirically: Vim's synID() has an incremental-caching quirk
    " where querying a "miss" column first can poison the cached state for
    " a later "hit" column on the same line (specific to `containedin=`
    " items whose earlier sibling pattern, here the k=0 byte-offset match,
    " legitimately fails to match at that position) -- this only affects
    " out-of-order *script* polling, not Vim's own left-to-right rendering,
    " so it's a test-harness ordering requirement, not a real bug.
    call assert_equal('hex_target_byte', s:SynAt(1, 13))    " byte1 = 0xFF, the target
    call assert_equal('ErrorMsg', synIDattr(synIDtrans(synID(1, 13, 1)), 'name'))
    call assert_notequal('hex_target_byte', s:SynAt(1, 11)) " byte0 = 0x00, not the target (0xFF)

    bwipeout!
    call delete(l:path)
    let [g:hexedit_highlight_byte_value, g:hexedit_highlight_byte_hlgroup] = l:saved
endfunction
