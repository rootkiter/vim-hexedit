" Tests for autoload/hexedit/platform.vim

function! Test_Platform_IsNeovimMatchesHasNvim() abort
    call assert_equal(has('nvim') ? 1 : 0, hexedit#platform#IsNeovim())
endfunction

function! Test_Platform_HasJobSupport() abort
    call assert_equal(1, hexedit#platform#HasJobSupport())
endfunction

function! Test_Platform_HighlightRoundTripNoErrors() abort
    new
    call setline(1, 'hello world')
    let l:ns = hexedit#platform#EnsureNamespace('test_ns', 'ErrorMsg')
    call hexedit#platform#HighlightRange(bufnr('%'), l:ns, 1, 1, 6, 'ErrorMsg')
    call hexedit#platform#ClearNamespace(bufnr('%'), l:ns)
    " Reaching here without an exception is the assertion.
    call assert_equal(1, 1)
    bwipeout!
endfunction

function! Test_Platform_JobStart_RunsAndCapturesStdout() abort
    if !hexedit#platform#HasJobSupport()
        return
    endif
    let g:__hexedit_test_job_out = []
    let g:__hexedit_test_job_done = []
    let l:job = hexedit#platform#JobStart(['echo', 'hexedit-job-ok'], {
                \ 'on_stdout': {lines -> extend(g:__hexedit_test_job_out, lines)},
                \ 'on_exit': {code -> add(g:__hexedit_test_job_done, code)},
                \ })
    call assert_notequal(-1, l:job)
    let l:waited = 0
    while empty(g:__hexedit_test_job_done) && l:waited < 3000
        sleep 20m
        let l:waited += 20
    endwhile
    call assert_equal([0], g:__hexedit_test_job_done)
    call assert_equal(['hexedit-job-ok'], g:__hexedit_test_job_out)
    unlet g:__hexedit_test_job_out
    unlet g:__hexedit_test_job_done
endfunction
