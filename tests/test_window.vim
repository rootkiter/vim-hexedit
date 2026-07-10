" Tests for offset parsing and large-file windowing (autoload/hexedit.vim,
" REQUIREMENTS.md section 5).

function! Test_ParseOffset_Hex() abort
    call assert_equal(255, hexedit#ParseOffset('0xFF'))
    call assert_equal(255, hexedit#ParseOffset('0xff'))
    call assert_equal(0, hexedit#ParseOffset('0x0'))
endfunction

function! Test_ParseOffset_Decimal() abort
    call assert_equal(100, hexedit#ParseOffset('100'))
    call assert_equal(0, hexedit#ParseOffset('0'))
endfunction

function! Test_ParseOffset_Invalid() abort
    call assert_equal(-1, hexedit#ParseOffset('notanumber'))
    call assert_equal(-1, hexedit#ParseOffset(''))
    call assert_equal(-1, hexedit#ParseOffset('-5'))
endfunction

function! Test_CacheWindowSize() abort
    let l:saved_w = g:hexedit_window_size
    let l:saved_r = g:hexedit_cache_window_ratio
    let g:hexedit_window_size = 100
    let g:hexedit_cache_window_ratio = 3
    call assert_equal(300, hexedit#CacheWindowSize())
    let g:hexedit_window_size = l:saved_w
    let g:hexedit_cache_window_ratio = l:saved_r
endfunction

function! s:WriteSequentialFile(path, nbytes) abort
    let l:hex = ''
    for l:i in range(a:nbytes)
        let l:hex .= printf('%02x', l:i % 256)
    endfor
    call system(['sh', '-c', 'xxd -r -p > ' . shellescape(a:path)], l:hex)
endfunction

function! Test_LargeFile_OpensWindowed_ViaExtensionPattern() abort
    let l:path = tempname() . '.bin'
    call s:WriteSequentialFile(l:path, 2000)

    let l:saved = [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio]
    let g:hexedit_large_file_threshold = 500
    let g:hexedit_window_size = 200
    let g:hexedit_cache_window_ratio = 2

    execute 'edit ' . fnameescape(l:path)
    call assert_equal(1, hexedit#registry#IsActive())
    let l:m = hexedit#registry#CurrentModel()
    call assert_equal(1, l:m.is_windowed)
    call assert_equal(400, l:m.window_length)
    call assert_equal(0, l:m.window_offset)
    call assert_equal(2000, l:m.total_size)
    call assert_equal(1, &l:binary)

    bwipeout!
    call delete(l:path)
    let [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio] = l:saved
endfunction

function! Test_LargeFile_SmallFileNotWindowed() abort
    let l:path = tempname() . '.bin'
    call s:WriteSequentialFile(l:path, 20)

    let l:saved = g:hexedit_large_file_threshold
    let g:hexedit_large_file_threshold = 500

    execute 'edit ' . fnameescape(l:path)
    let l:m = hexedit#registry#CurrentModel()
    call assert_equal(0, l:m.is_windowed)
    call assert_equal(20, l:m.window_length)

    bwipeout!
    call delete(l:path)
    let g:hexedit_large_file_threshold = l:saved
endfunction

function! Test_LargeFile_HGoto_RecentersWindow() abort
    let l:path = tempname() . '.bin'
    call s:WriteSequentialFile(l:path, 2000)

    let l:saved = [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio]
    let g:hexedit_large_file_threshold = 500
    let g:hexedit_window_size = 200
    let g:hexedit_cache_window_ratio = 2

    execute 'edit ' . fnameescape(l:path)
    call hexedit#HGoto('1000')
    let l:m = hexedit#registry#CurrentModel()
    call assert_true(l:m.window_offset <= 1000 && 1000 < l:m.window_offset + l:m.window_length,
                \ printf('offset=%d length=%d', l:m.window_offset, l:m.window_length))

    call hexedit#HGoto('0x64')
    let l:m2 = hexedit#registry#CurrentModel()
    call assert_true(l:m2.window_offset <= 100 && 100 < l:m2.window_offset + l:m2.window_length)

    bwipeout!
    call delete(l:path)
    let [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio] = l:saved
endfunction

function! Test_LargeFile_WindowClampedToFileBounds() abort
    let l:path = tempname() . '.bin'
    call s:WriteSequentialFile(l:path, 2000)

    let l:saved = [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio]
    let g:hexedit_large_file_threshold = 500
    let g:hexedit_window_size = 200
    let g:hexedit_cache_window_ratio = 2

    execute 'edit ' . fnameescape(l:path)
    call hexedit#HGoto('1999')
    let l:m = hexedit#registry#CurrentModel()
    call assert_equal(2000, l:m.window_offset + l:m.window_length)

    call hexedit#HGoto('0')
    let l:m2 = hexedit#registry#CurrentModel()
    call assert_equal(0, l:m2.window_offset)

    bwipeout!
    call delete(l:path)
    let [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio] = l:saved
endfunction

function! Test_LargeFile_WindowOffset_AlignedToOctetsPerLine() abort
    " Jumping to a deliberately unaligned offset must still produce a
    " window whose start (and therefore every line's address) is a
    " multiple of octets_per_line -- otherwise the same file byte would
    " render in a different column depending on which window loaded it.
    let l:path = tempname() . '.bin'
    call s:WriteSequentialFile(l:path, 2000)

    let l:saved = [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio]
    let g:hexedit_large_file_threshold = 500
    let g:hexedit_window_size = 200
    let g:hexedit_cache_window_ratio = 2

    execute 'edit ' . fnameescape(l:path)
    let l:per_line = hexedit#registry#CurrentModel().octets_per_line

    " 1237 is deliberately not a multiple of 16, and is not near either
    " end of the file (so no EOF/start clamping masks the alignment check).
    call hexedit#HGoto('1237')
    let l:m = hexedit#registry#CurrentModel()
    call assert_equal(0, l:m.window_offset % l:per_line,
                \ printf('window_offset=%d not aligned to %d', l:m.window_offset, l:per_line))
    call assert_true(l:m.window_offset <= 1237 && 1237 < l:m.window_offset + l:m.window_length)

    " the rendered line address itself must be the aligned offset
    call assert_equal(printf('%08x:', l:m.window_offset), getline(1)[0:8])

    bwipeout!
    call delete(l:path)
    let [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio] = l:saved
endfunction

function! Test_LargeFile_WindowOffset_AlignedNearEOF() abort
    let l:path = tempname() . '.bin'
    call s:WriteSequentialFile(l:path, 2000)

    let l:saved = [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio]
    let g:hexedit_large_file_threshold = 500
    let g:hexedit_window_size = 200
    let g:hexedit_cache_window_ratio = 2

    execute 'edit ' . fnameescape(l:path)
    let l:per_line = hexedit#registry#CurrentModel().octets_per_line

    call hexedit#modes#hexedit#GotoFileEnd()
    let l:m = hexedit#registry#CurrentModel()
    call assert_equal(0, l:m.window_offset % l:per_line)
    " still reaches exactly to EOF despite alignment shrinking the window
    call assert_equal(2000, l:m.window_offset + l:m.window_length)

    bwipeout!
    call delete(l:path)
    let [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio] = l:saved
endfunction
