" Tests for hexedit#GotoAbsoluteOffset and the whole-file :Hsearch/`n`
" behavior added by REQUIREMENTS.md 5.6/5.7.
"
" As established in tests/test_hexedit_editing.vim, headless `-es` batch
" mode does not fire CursorMoved/CursorMovedI, and `:normal!` bypasses
" custom key mappings entirely -- so `n` is exercised by calling
" hexedit#modes#hexedit#NormalKeyMap('n') directly (exactly what the
" buffer-local `nnoremap n ...` mapping invokes for a real keypress).

function! s:WriteBytesFile(path, hexcontent) abort
    call system(['sh', '-c', 'xxd -r -p > ' . shellescape(a:path)], a:hexcontent)
endfunction

" ---- hexedit#GotoAbsoluteOffset --------------------------------------------

function! Test_GotoAbsoluteOffset_NonWindowed_MovesCursor() abort
    let l:path = tempname() . '.dat'
    call s:WriteBytesFile(l:path, repeat('41', 40))
    execute 'edit ' . fnameescape(l:path)
    call assert_equal(0, hexedit#registry#CurrentModel().is_windowed)

    call assert_equal(1, hexedit#GotoAbsoluteOffset(16))
    call assert_equal(2, line('.'))

    bwipeout!
    call delete(l:path)
endfunction

function! Test_GotoAbsoluteOffset_Windowed_AlreadyLoaded_NoReload() abort
    let l:path = tempname() . '.bin'
    call s:WriteBytesFile(l:path, repeat('41', 2000))
    let l:saved = [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio]
    let g:hexedit_large_file_threshold = 500
    let g:hexedit_window_size = 200
    let g:hexedit_cache_window_ratio = 2

    execute 'edit ' . fnameescape(l:path)
    let l:before = hexedit#registry#CurrentModel().window_offset

    call assert_equal(1, hexedit#GotoAbsoluteOffset(100))
    call assert_equal(l:before, hexedit#registry#CurrentModel().window_offset)

    bwipeout!
    call delete(l:path)
    let [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio] = l:saved
endfunction

function! Test_GotoAbsoluteOffset_Windowed_OutsideWindow_Reloads() abort
    let l:path = tempname() . '.bin'
    call s:WriteBytesFile(l:path, repeat('41', 2000))
    let l:saved = [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio]
    let g:hexedit_large_file_threshold = 500
    let g:hexedit_window_size = 200
    let g:hexedit_cache_window_ratio = 2

    execute 'edit ' . fnameescape(l:path)
    call assert_equal(1, hexedit#GotoAbsoluteOffset(1500))
    let l:m = hexedit#registry#CurrentModel()
    call assert_true(l:m.window_offset <= 1500 && 1500 < l:m.window_offset + l:m.window_length)

    bwipeout!
    call delete(l:path)
    let [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio] = l:saved
endfunction

function! Test_GotoAbsoluteOffset_RefusesWhenUnsavedAndReloadNeeded() abort
    let l:path = tempname() . '.bin'
    call s:WriteBytesFile(l:path, repeat('41', 2000))
    let l:saved = [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio]
    let g:hexedit_large_file_threshold = 500
    let g:hexedit_window_size = 200
    let g:hexedit_cache_window_ratio = 2

    execute 'edit ' . fnameescape(l:path)
    let l:before = hexedit#registry#CurrentModel().window_offset
    setlocal modified

    call assert_equal(0, hexedit#GotoAbsoluteOffset(1500))
    call assert_equal(l:before, hexedit#registry#CurrentModel().window_offset)
    call assert_equal(1, &l:modified)

    " jumping to an offset already within the loaded window is still fine
    " even with unsaved changes, since no reload is required
    call assert_equal(1, hexedit#GotoAbsoluteOffset(50))

    bwipeout!
    call delete(l:path)
    let [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio] = l:saved
endfunction

" ---- :Hsearch / n -----------------------------------------------------

function! Test_Hsearch_FindsMatch_LandsOnExactByteColumn() abort
    let l:path = tempname() . '.dat'
    " bytes: AA BB CC DD EE FF -- pattern "ccdd" is byte index 2
    call s:WriteBytesFile(l:path, 'aabbccddeeff')
    execute 'edit ' . fnameescape(l:path)

    call hexedit#registry#Dispatch('BuildInCommand', 'Hsearch', 'ccdd')
    call assert_equal('c', getline('.')[col('.') - 1])

    bwipeout!
    call delete(l:path)
endfunction

function! Test_Hsearch_NotFound_ReportsAndClearsLastOffset() abort
    let l:path = tempname() . '.dat'
    call s:WriteBytesFile(l:path, 'aabbccdd')
    execute 'edit ' . fnameescape(l:path)

    call hexedit#registry#Dispatch('BuildInCommand', 'Hsearch', 'ffffffff')
    call assert_equal(0, exists('b:hexedit_search_last_offset'))

    bwipeout!
    call delete(l:path)
endfunction

function! Test_HsearchClean_ClearsSearchState() abort
    let l:path = tempname() . '.dat'
    call s:WriteBytesFile(l:path, 'aabbccdd')
    execute 'edit ' . fnameescape(l:path)

    call hexedit#registry#Dispatch('BuildInCommand', 'Hsearch', 'ccdd')
    call assert_equal('ccdd', b:hexedit_search_pattern_raw)

    call hexedit#registry#Dispatch('BuildInCommand', 'HsearchClean', '')
    call assert_equal('', b:hexedit_search_pattern_raw)
    call assert_equal(0, exists('b:hexedit_search_last_offset'))

    bwipeout!
    call delete(l:path)
endfunction

function! Test_Hsearch_N_CrossesWindowBoundary() abort
    let l:hex = ''
    for l:i in range(2000)
        let l:hex .= '00'
    endfor
    " plant "deadbeef" at byte offset 50 (inside the initial window) and
    " again at byte offset 1500 (well outside a 400-byte cache window).
    let l:hex = l:hex[0 : 50*2-1] . 'deadbeef' . l:hex[50*2+8 :]
    let l:hex = l:hex[0 : 1500*2-1] . 'deadbeef' . l:hex[1500*2+8 :]

    let l:path = tempname() . '.bin'
    call s:WriteBytesFile(l:path, l:hex)

    let l:saved = [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio]
    let g:hexedit_large_file_threshold = 500
    let g:hexedit_window_size = 200
    let g:hexedit_cache_window_ratio = 2  " cache window = 400 bytes

    execute 'edit ' . fnameescape(l:path)
    let l:m0 = hexedit#registry#CurrentModel()
    call assert_equal(0, l:m0.window_offset)

    call hexedit#registry#Dispatch('BuildInCommand', 'Hsearch', 'deadbeef')
    let l:m1 = hexedit#registry#CurrentModel()
    " first match at 50 is inside the initial window -- no reload needed
    call assert_equal(0, l:m1.window_offset)
    call assert_equal(54, b:hexedit_search_last_offset)

    call hexedit#modes#hexedit#NormalKeyMap('n')
    let l:m2 = hexedit#registry#CurrentModel()
    " second match at 1500 is outside the original [0,400) window -> the
    " cache window must have been reloaded to cover it
    call assert_true(l:m2.window_offset <= 1500 && 1500 < l:m2.window_offset + l:m2.window_length,
                \ printf('window_offset=%d window_length=%d', l:m2.window_offset, l:m2.window_length))
    call assert_equal('d', getline('.')[col('.') - 1])

    bwipeout!
    call delete(l:path)
    let [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio] = l:saved
endfunction

function! Test_Hsearch_FallsBackToBufferSearch_WhenNoBackingFile() abort
    new
    call setline(1, 'aabbccddeeff')
    HexLoad
    call assert_equal('', hexedit#registry#CurrentModel().path)

    call hexedit#registry#Dispatch('BuildInCommand', 'Hsearch', 'ccdd')
    " the legacy buffer-only search should still land somewhere sane on
    " the single hex-dump line without erroring
    call assert_equal(1, line('.'))

    call hexedit#registry#Deactivate()
    bwipeout!
endfunction
