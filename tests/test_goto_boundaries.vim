" Regression tests: G / gg must jump to the end/start of the whole FILE in
" large-file windowed mode, not just the end/start of whatever window is
" currently loaded.
"
" As elsewhere, `:normal!` bypasses buffer-local key mappings entirely, so
" these call the underlying functions directly -- exactly what the
" `nnoremap <buffer> G ...` / `nnoremap <buffer> gg ...` mappings invoke.

function! s:WriteBytesFile(path, hexcontent) abort
    call system(['sh', '-c', 'xxd -r -p > ' . shellescape(a:path)], a:hexcontent)
endfunction

function! Test_GotoFileEnd_Windowed_JumpsToLastByte() abort
    let l:path = tempname() . '.bin'
    call s:WriteBytesFile(l:path, repeat('41', 2000))
    let l:saved = [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio]
    let g:hexedit_large_file_threshold = 500
    let g:hexedit_window_size = 200
    let g:hexedit_cache_window_ratio = 2

    execute 'edit ' . fnameescape(l:path)
    call assert_equal(0, hexedit#registry#CurrentModel().window_offset)

    call hexedit#modes#hexedit#GotoFileEnd()
    let l:m = hexedit#registry#CurrentModel()
    call assert_equal(2000, l:m.window_offset + l:m.window_length)
    call assert_true(l:m.window_offset <= 1999 && 1999 < l:m.window_offset + l:m.window_length)

    bwipeout!
    call delete(l:path)
    let [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio] = l:saved
endfunction

function! Test_GotoFileStart_Windowed_JumpsToByteZero() abort
    let l:path = tempname() . '.bin'
    call s:WriteBytesFile(l:path, repeat('41', 2000))
    let l:saved = [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio]
    let g:hexedit_large_file_threshold = 500
    let g:hexedit_window_size = 200
    let g:hexedit_cache_window_ratio = 2

    execute 'edit ' . fnameescape(l:path)
    call hexedit#modes#hexedit#GotoFileEnd()
    call assert_true(hexedit#registry#CurrentModel().window_offset > 0)

    call hexedit#modes#hexedit#GotoFileStart()
    call assert_equal(0, hexedit#registry#CurrentModel().window_offset)
    call assert_equal(1, line('.'))

    bwipeout!
    call delete(l:path)
    let [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio] = l:saved
endfunction

function! Test_GotoFileEnd_NonWindowed_FallsBackToNativeG() abort
    let l:path = tempname() . '.dat'
    call s:WriteBytesFile(l:path, repeat('41', 40))
    execute 'edit ' . fnameescape(l:path)
    call assert_equal(0, hexedit#registry#CurrentModel().is_windowed)

    call hexedit#modes#hexedit#GotoFileEnd()
    call assert_equal(line('$'), line('.'))

    bwipeout!
    call delete(l:path)
endfunction

function! Test_GotoFileStart_NonWindowed_FallsBackToNativeGG() abort
    let l:path = tempname() . '.dat'
    call s:WriteBytesFile(l:path, repeat('41', 40))
    execute 'edit ' . fnameescape(l:path)
    call cursor(line('$'), 1)

    call hexedit#modes#hexedit#GotoFileStart()
    call assert_equal(1, line('.'))

    bwipeout!
    call delete(l:path)
endfunction

function! Test_GotoFileEnd_RefusesWithUnsavedChanges() abort
    let l:path = tempname() . '.bin'
    call s:WriteBytesFile(l:path, repeat('41', 2000))
    let l:saved = [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio]
    let g:hexedit_large_file_threshold = 500
    let g:hexedit_window_size = 200
    let g:hexedit_cache_window_ratio = 2

    execute 'edit ' . fnameescape(l:path)
    setlocal modified
    call hexedit#modes#hexedit#GotoFileEnd()
    call assert_equal(0, hexedit#registry#CurrentModel().window_offset)

    bwipeout!
    call delete(l:path)
    let [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio] = l:saved
endfunction
