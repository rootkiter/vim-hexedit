" Tests for autoload/hexedit/model.vim

function! Test_Model_FromPlainHex_ByteLength() abort
    let l:m = hexedit#model#FromPlainHex('4142')
    call assert_equal(2, hexedit#model#ByteLength(l:m))
    call assert_equal('4142', l:m.plain_hex)
    call assert_equal(0, l:m.is_windowed)
    call assert_equal('', l:m.path)
endfunction

function! Test_Model_FromPlainHex_StripsWhitespace() abort
    let l:m = hexedit#model#FromPlainHex("41 42\n43\t44")
    call assert_equal('41424344', l:m.plain_hex)
endfunction

function! Test_Model_IsValidHex() abort
    call assert_equal(1, hexedit#model#IsValidHex('4142'))
    call assert_equal(1, hexedit#model#IsValidHex('41 42'))
    call assert_equal(1, hexedit#model#IsValidHex(''))
    call assert_equal(0, hexedit#model#IsValidHex('414'))
    call assert_equal(0, hexedit#model#IsValidHex('41zz'))
endfunction

function! Test_Model_HexDump_RoundTrip() abort
    let l:m = hexedit#model#FromPlainHex('4142434445464748494a4b4c4d4e4f50',
                \ {'octets_per_line': 16, 'group_octets_num': 2})
    let l:lines = hexedit#model#ToHexDumpLines(l:m)
    call assert_equal(1, len(l:lines))
    call assert_match('ABCDEFGHIJKLMNOP', l:lines[0])
    call assert_match('^00000000:', l:lines[0])
    let [l:ok, l:hex] = hexedit#model#ParseHexDumpLines(l:lines)
    call assert_equal(1, l:ok)
    call assert_equal('4142434445464748494a4b4c4d4e4f50', l:hex)
endfunction

function! Test_Model_HexDump_UsesWindowOffsetAsAddress() abort
    let l:m = hexedit#model#FromPlainHex('41424344', {'octets_per_line': 16, 'group_octets_num': 2})
    let l:m.window_offset = 256
    let l:lines = hexedit#model#ToHexDumpLines(l:m)
    call assert_match('^00000100:', l:lines[0])
endfunction

function! Test_Model_HexDump_Empty() abort
    let l:m = hexedit#model#FromPlainHex('')
    let l:lines = hexedit#model#ToHexDumpLines(l:m)
    call assert_equal(1, len(l:lines))
endfunction

function! Test_Model_HexString_RoundTrip() abort
    let l:m = hexedit#model#FromPlainHex('414243444546',
                \ {'group_octets_num': 2, 'octets_per_line': 4})
    let l:lines = hexedit#model#ToHexStringLines(l:m)
    " 6 bytes, grouped by 2 -> 3 cells, 2 cells per line -> 2 lines
    call assert_equal(['4142 4344', '4546'], l:lines)
    let [l:ok, l:hex] = hexedit#model#ParseHexStringLines(l:lines)
    call assert_equal(1, l:ok)
    call assert_equal('414243444546', l:hex)
endfunction

function! Test_Model_ParseHexStringLines_Invalid() abort
    let [l:ok, l:msg] = hexedit#model#ParseHexStringLines(['41 4'])
    call assert_equal(0, l:ok)
    let [l:ok2, l:msg2] = hexedit#model#ParseHexStringLines(['41 zz'])
    call assert_equal(0, l:ok2)
endfunction

function! Test_Model_ToCLines_Format() abort
    let l:m = hexedit#model#FromPlainHex('41424344', {'octets_per_line': 16})
    let l:lines = hexedit#model#ToCLines(l:m, 'buf')
    call assert_equal('unsigned char buf[] = {', l:lines[0])
    call assert_equal('    0x41, 0x42, 0x43, 0x44, // ABCD', l:lines[1])
    call assert_equal('};', l:lines[-1])
endfunction

function! Test_Model_ToCLines_MultiLine() abort
    let l:hex = repeat('41', 20)
    let l:m = hexedit#model#FromPlainHex(l:hex, {'octets_per_line': 16})
    let l:lines = hexedit#model#ToCLines(l:m, 'buf')
    " header + 2 data lines (16 + 4 bytes) + footer
    call assert_equal(4, len(l:lines))
    call assert_match('^    \(0x41, \)\{16}// AAAAAAAAAAAAAAAA$', l:lines[1])
    call assert_match('^    \(0x41, \)\{4}// AAAA$', l:lines[2])
endfunction

function! Test_Model_ToPyLines_Format() abort
    let l:m = hexedit#model#FromPlainHex('41424344',
                \ {'octets_per_line': 16, 'group_octets_num': 2})
    let l:lines = hexedit#model#ToPyLines(l:m)
    call assert_equal('bytes.fromhex(', l:lines[0])
    call assert_equal('    "4142 4344"  ### ABCD', l:lines[1])
    call assert_equal(')', l:lines[-1])
endfunction

function! Test_Model_LowUp_Uppercase() abort
    " Use byte values with actual hex letters (a1/1a render identically to
    " A1/1A) so this test can tell lower/upper apart.
    let l:m = hexedit#model#FromPlainHex('abcd', {'low_up': 'upper', 'octets_per_line': 16})
    let l:lines = hexedit#model#ToHexDumpLines(l:m)
    call assert_match('ABCD', l:lines[0])
    let l:cl = hexedit#model#ToCLines(l:m, 'buf')
    call assert_match('0xAB, 0xCD', l:cl[1])
endfunction

" ---- file-backed constructors ----

function! Test_Model_FromWholeFile() abort
    let l:path = tempname()
    call system(['sh', '-c', 'printf %s ABCD > ' . shellescape(l:path)])
    let l:m = hexedit#model#FromWholeFile(l:path)
    call assert_equal('41424344', l:m.plain_hex)
    call assert_equal(4, l:m.total_size)
    call assert_equal(0, l:m.is_windowed)
    call delete(l:path)
endfunction

function! Test_Model_FromWholeFile_Empty() abort
    let l:path = tempname()
    call writefile([], l:path)
    let l:m = hexedit#model#FromWholeFile(l:path)
    call assert_equal('', l:m.plain_hex)
    call assert_equal(0, l:m.total_size)
    call delete(l:path)
endfunction

function! Test_Model_FromFileWindow() abort
    let l:path = tempname()
    call system(['sh', '-c', 'printf %s 0123456789 > ' . shellescape(l:path)])
    let l:m = hexedit#model#FromFileWindow(l:path, 2, 3)
    call assert_equal('323334', l:m.plain_hex)
    call assert_equal(1, l:m.is_windowed)
    call assert_equal(10, l:m.total_size)
    call assert_equal(2, l:m.window_offset)
    call delete(l:path)
endfunction

function! Test_Model_FromFileWindow_ClampsToFileEnd() abort
    let l:path = tempname()
    call system(['sh', '-c', 'printf %s 0123456789 > ' . shellescape(l:path)])
    let l:m = hexedit#model#FromFileWindow(l:path, 8, 100)
    call assert_equal('3839', l:m.plain_hex)
    call assert_equal(2, l:m.window_length)
    call delete(l:path)
endfunction

" ---- persistence ----

function! Test_Model_Save_WholeFile() abort
    let l:path = tempname()
    let l:m = hexedit#model#FromPlainHex('48656c6c6f')
    let l:m.path = l:path
    let [l:ok, l:msg] = hexedit#model#Save(l:m)
    call assert_equal(1, l:ok)
    call assert_equal('Hello', system(['cat', l:path]))
    call delete(l:path)
endfunction

function! Test_Model_Save_NoPath_Fails() abort
    let l:m = hexedit#model#FromPlainHex('4142')
    let [l:ok, l:msg] = hexedit#model#Save(l:m)
    call assert_equal(0, l:ok)
endfunction

function! Test_Model_Save_PatchWindow_FixedLength() abort
    let l:path = tempname()
    call system(['sh', '-c', 'printf %s 0123456789 > ' . shellescape(l:path)])
    let l:m = hexedit#model#FromFileWindow(l:path, 3, 4)
    call assert_equal('33343536', l:m.plain_hex)
    let l:m.plain_hex = '5858585a'
    let [l:ok, l:msg] = hexedit#model#Save(l:m)
    call assert_equal(1, l:ok)
    call assert_equal('012XXXZ789', system(['cat', l:path]))
    call delete(l:path)
endfunction

function! Test_Model_Save_VariableLength_Confirmed() abort
    let l:path = tempname()
    call system(['sh', '-c', 'printf %s 0123456789 > ' . shellescape(l:path)])
    let l:m = hexedit#model#FromFileWindow(l:path, 3, 4)
    let l:m.plain_hex = '414243'
    let [l:ok, l:msg] = hexedit#model#Save(l:m, {'confirm_fn': {msg -> 1}})
    call assert_equal(1, l:ok)
    call assert_equal('012ABC789', system(['cat', l:path]))
    call delete(l:path)
endfunction

function! Test_Model_Save_VariableLength_Declined() abort
    let l:path = tempname()
    call system(['sh', '-c', 'printf %s 0123456789 > ' . shellescape(l:path)])
    let l:m = hexedit#model#FromFileWindow(l:path, 3, 4)
    let l:m.plain_hex = '4142'
    let [l:ok, l:msg] = hexedit#model#Save(l:m, {'confirm_fn': {msg -> 0}})
    call assert_equal(0, l:ok)
    call assert_equal('0123456789', system(['cat', l:path]))
    call delete(l:path)
endfunction

function! Test_Model_Save_VariableLength_Grow() abort
    let l:path = tempname()
    call system(['sh', '-c', 'printf %s 0123456789 > ' . shellescape(l:path)])
    let l:m = hexedit#model#FromFileWindow(l:path, 3, 2)
    call assert_equal('3334', l:m.plain_hex)
    let l:m.plain_hex = '414243444546'
    let [l:ok, l:msg] = hexedit#model#Save(l:m, {'confirm_fn': {msg -> 1}})
    call assert_equal(1, l:ok)
    call assert_equal('012ABCDEF56789', system(['cat', l:path]))
    call delete(l:path)
endfunction

" ---- whole-file search (SearchFile, REQUIREMENTS 5.7) ---------------------

function! s:WriteBytesFile(path, hexcontent) abort
    call system(['sh', '-c', 'xxd -r -p > ' . shellescape(a:path)], a:hexcontent)
endfunction

function! Test_Model_SearchFile_FindsNearStart() abort
    let l:path = tempname()
    " 4 filler bytes, then the pattern at byte offset 4.
    call s:WriteBytesFile(l:path, '00112233deadbeef44556677')
    let l:m = hexedit#model#FromWholeFile(l:path)
    let [l:found, l:offset, l:len] = hexedit#model#SearchFile(l:m, 'deadbeef', 0)
    call assert_equal(1, l:found)
    call assert_equal(4, l:offset)
    call assert_equal(4, l:len)
    call delete(l:path)
endfunction

function! Test_Model_SearchFile_NotFound() abort
    let l:path = tempname()
    call s:WriteBytesFile(l:path, '0011223344556677')
    let l:m = hexedit#model#FromWholeFile(l:path)
    let [l:found, l:offset, l:len] = hexedit#model#SearchFile(l:m, 'ffffffff', 0)
    call assert_equal(0, l:found)
    call assert_equal(-1, l:offset)
endfunction

function! Test_Model_SearchFile_RespectsStartByte() abort
    let l:path = tempname()
    " bytes: 00 11 ca fe 00 11 00 11 ca fe 00 11
    "  idx:   0  1  2  3  4  5  6  7  8  9 10 11
    " pattern "cafe" occurs at byte offset 2 and again at byte offset 8
    call s:WriteBytesFile(l:path, '0011cafe00110011cafe0011')
    let l:m = hexedit#model#FromWholeFile(l:path)
    let [l:found1, l:offset1, l:len1] = hexedit#model#SearchFile(l:m, 'cafe', 0)
    call assert_equal(1, l:found1)
    call assert_equal(2, l:offset1)
    " search again starting right after the first match -> should find the
    " second occurrence, not re-find the first
    let [l:found2, l:offset2, l:len2] = hexedit#model#SearchFile(l:m, 'cafe', l:offset1 + l:len1)
    call assert_equal(1, l:found2)
    call assert_equal(8, l:offset2)
    call delete(l:path)
endfunction

function! Test_Model_SearchFile_CaseInsensitive() abort
    let l:path = tempname()
    call s:WriteBytesFile(l:path, 'aabbccdd')
    let l:m = hexedit#model#FromWholeFile(l:path)
    let [l:found, l:offset, l:len] = hexedit#model#SearchFile(l:m, 'AABBCCDD', 0)
    call assert_equal(1, l:found)
    call assert_equal(0, l:offset)
    call delete(l:path)
endfunction

function! Test_Model_SearchFile_NoBackingFile() abort
    let l:m = hexedit#model#FromPlainHex('aabbccdd')
    let [l:found, l:offset, l:len] = hexedit#model#SearchFile(l:m, 'aabb', 0)
    call assert_equal(0, l:found)
endfunction

function! Test_Model_SearchFile_InvalidPattern() abort
    let l:path = tempname()
    call s:WriteBytesFile(l:path, 'aabbccdd')
    let l:m = hexedit#model#FromWholeFile(l:path)
    let [l:found, l:offset, l:len] = hexedit#model#SearchFile(l:m, 'zz', 0)
    call assert_equal(0, l:found)
    let [l:found2, l:offset2, l:len2] = hexedit#model#SearchFile(l:m, 'abc', 0)
    call assert_equal(0, l:found2)
    call delete(l:path)
endfunction

function! Test_Model_SearchFile_LargeFile_MatchNearEnd() abort
    " Confirms correctness (not just the near-start fast path) when the
    " match is far from start_byte and the pipeline has to actually scan
    " forward through a non-trivial amount of data.
    let l:path = tempname()
    let l:hex = ''
    for l:i in range(20000)
        let l:hex .= printf('%02x', l:i % 256)
    endfor
    let l:hex .= 'deadbeef'
    call s:WriteBytesFile(l:path, l:hex)
    let l:m = hexedit#model#FromWholeFile(l:path)
    let [l:found, l:offset, l:len] = hexedit#model#SearchFile(l:m, 'deadbeef', 0)
    call assert_equal(1, l:found)
    call assert_equal(20000, l:offset)
    call delete(l:path)
endfunction

" ---- write_mode == 'text' (REQUIREMENTS 6.3) -------------------------------

function! Test_Model_Save_TextMode_WritesHexStringNotBinary() abort
    let l:path = tempname()
    let l:m = hexedit#model#FromPlainHex('48656c6c6f',
                \ {'write_mode': 'text', 'group_octets_num': 2, 'octets_per_line': 16})
    let l:m.path = l:path
    let [l:ok, l:msg] = hexedit#model#Save(l:m)
    call assert_equal(1, l:ok)
    call assert_equal(['4865 6c6c 6f'], readfile(l:path))
    call delete(l:path)
endfunction

function! Test_Model_Save_TextMode_OverwritesWholeFileRegardlessOfWindow() abort
    let l:path = tempname()
    call system(['sh', '-c', 'printf %s 0123456789 > ' . shellescape(l:path)])
    " a windowed model with write_mode=text should still just overwrite
    " the whole file with its own (small) hex-string text -- text has no
    " "patch a byte range" concept the way binary mode does.
    let l:m = hexedit#model#FromFileWindow(l:path, 3, 4,
                \ {'write_mode': 'text', 'group_octets_num': 2, 'octets_per_line': 16})
    call assert_equal('33343536', l:m.plain_hex)
    let [l:ok, l:msg] = hexedit#model#Save(l:m)
    call assert_equal(1, l:ok)
    call assert_match('only writes the currently loaded window', l:msg)
    call assert_equal(['3334 3536'], readfile(l:path))
    call delete(l:path)
endfunction

function! Test_Model_Save_TextMode_DefaultsToBinary() abort
    let l:m = hexedit#model#FromPlainHex('4142')
    call assert_equal('binary', l:m.write_mode)
endfunction
