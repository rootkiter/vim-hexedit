" Regression tests: &modified must accurately reflect whether the model's
" bytes differ from what's on disk, not just "did setline() run" -- setline
" ()/deletebufline() unconditionally mark a buffer modified even when the
" content written is identical, and this plugin calls them on every mode
" render (switches, window reloads), not just on real user edits.

function! s:WriteBytesFile(path, hexcontent) abort
    call system(['sh', '-c', 'xxd -r -p > ' . shellescape(a:path)], a:hexcontent)
endfunction

function! Test_Modified_FreshOpen_NotModified() abort
    let l:path = tempname() . '.dat'
    call s:WriteBytesFile(l:path, 'aabbccdd')
    execute 'edit ' . fnameescape(l:path)
    call assert_equal(0, &l:modified)
    bwipeout!
    call delete(l:path)
endfunction

function! Test_Modified_SwitchingModesWithoutEdits_StaysUnmodified() abort
    let l:path = tempname() . '.dat'
    call s:WriteBytesFile(l:path, 'aabbccdd')
    execute 'edit ' . fnameescape(l:path)

    Hex
    call assert_equal(0, &l:modified)
    H2C
    call assert_equal(0, &l:modified)
    H2Py
    call assert_equal(0, &l:modified)
    Hedit
    call assert_equal(0, &l:modified)

    bwipeout!
    call delete(l:path)
endfunction

function! Test_Modified_ActualEdit_IsReflected() abort
    let l:path = tempname() . '.dat'
    call s:WriteBytesFile(l:path, 'aabbccdd')
    execute 'edit ' . fnameescape(l:path)

    let l:model = hexedit#registry#CurrentModel()
    let l:model.plain_hex = 'ffbbccdd'
    let b:hexedit_state.model = l:model
    call hexedit#registry#RenderCurrent()
    call assert_equal(1, &l:modified)

    " switching modes while there IS a real edit should keep showing modified
    Hex
    call assert_equal(1, &l:modified)

    bwipeout!
    call delete(l:path)
endfunction

function! Test_Modified_ClearedAfterSave() abort
    let l:path = tempname() . '.dat'
    call s:WriteBytesFile(l:path, 'aabbccdd')
    execute 'edit ' . fnameescape(l:path)

    let l:model = hexedit#registry#CurrentModel()
    let l:model.plain_hex = 'ffbbccdd'
    let b:hexedit_state.model = l:model
    call hexedit#registry#RenderCurrent()
    call assert_equal(1, &l:modified)

    write
    call assert_equal(0, &l:modified)
    call assert_equal('ffbbccdd', hexedit#registry#CurrentModel().plain_hex)

    bwipeout!
    call delete(l:path)
endfunction

function! Test_Modified_LargeFileWindowReload_StaysUnmodified() abort
    let l:hex = repeat('41', 2000)
    let l:path = tempname() . '.bin'
    call s:WriteBytesFile(l:path, l:hex)

    let l:saved = [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio]
    let g:hexedit_large_file_threshold = 500
    let g:hexedit_window_size = 200
    let g:hexedit_cache_window_ratio = 2

    execute 'edit ' . fnameescape(l:path)
    call assert_equal(0, &l:modified)

    call hexedit#GotoAbsoluteOffset(1500)
    call assert_equal(0, &l:modified)

    bwipeout!
    call delete(l:path)
    let [g:hexedit_large_file_threshold, g:hexedit_window_size, g:hexedit_cache_window_ratio] = l:saved
endfunction

function! Test_Modified_OnTextChanged_NoOpDoesNotDirty() abort
    " Directly exercises the no-op guard in OnTextChanged: firing it when
    " the cursor sits somewhere that requires no correction (e.g. the addr
    " column) must not itself mark the buffer modified.
    let l:path = tempname() . '.dat'
    call s:WriteBytesFile(l:path, 'aabbccdd')
    execute 'edit ' . fnameescape(l:path)
    call assert_equal(0, &l:modified)

    call cursor(1, 1)
    call hexedit#registry#Dispatch('OnTextChanged')
    call assert_equal(0, &l:modified)

    bwipeout!
    call delete(l:path)
endfunction
