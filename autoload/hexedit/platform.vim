" hexedit#platform - Vim/Neovim adaptation layer (REQUIREMENTS.md 2.6)
"
" All highlight and async-job access from the rest of the plugin must go
" through this file. Nothing else in the plugin may call job_start/jobstart,
" prop_add/nvim_buf_set_extmark, etc. directly.

let s:is_nvim = has('nvim')

function! hexedit#platform#IsNeovim() abort
    return s:is_nvim
endfunction

function! hexedit#platform#HasJobSupport() abort
    return s:is_nvim || (has('job') && has('channel'))
endfunction

" ---- Async job control -----------------------------------------------

" cmd: List of [program, arg1, arg2, ...] (no shell involved).
" opts: {
"   'on_stdout': funcref(lines_list),
"   'on_exit':   funcref(exit_code),
" }
" Returns a job handle usable with JobStop(), or -1 if async is unsupported
" (caller must fall back to synchronous hexedit#platform#SystemList()).
function! hexedit#platform#JobStart(cmd, opts) abort
    if !hexedit#platform#HasJobSupport()
        return -1
    endif
    let l:OnStdout = get(a:opts, 'on_stdout', v:null)
    let l:OnExit = get(a:opts, 'on_exit', v:null)

    if s:is_nvim
        let l:buf = []
        let l:cb = {
                    \ 'stdout_buf': l:buf,
                    \ 'on_stdout_fn': l:OnStdout,
                    \ 'on_exit_fn': l:OnExit,
                    \ }
        function! l:cb.on_stdout(job_id, data, event) abort
            if type(self.on_stdout_fn) == v:t_func
                call add(self.stdout_buf, a:data)
            endif
        endfunction
        function! l:cb.on_exit(job_id, code, event) abort
            if type(self.on_stdout_fn) == v:t_func
                let l:lines = []
                for l:chunk in self.stdout_buf
                    call extend(l:lines, l:chunk)
                endfor
                " nvim delivers a trailing empty string per flush; drop empties at end
                while len(l:lines) > 0 && l:lines[-1] ==# ''
                    call remove(l:lines, -1)
                endwhile
                call self.on_stdout_fn(l:lines)
            endif
            if type(self.on_exit_fn) == v:t_func
                call self.on_exit_fn(a:code)
            endif
        endfunction
        return jobstart(a:cmd, l:cb)
    else
        let l:state = {'lines': [''], 'on_stdout_fn': l:OnStdout, 'on_exit_fn': l:OnExit}
        function! l:state.out_cb(channel, msg) abort
            let self.lines[-1] .= a:msg
        endfunction
        function! l:state.exit_cb(job, status) abort
            if type(self.on_stdout_fn) == v:t_func
                call self.on_stdout_fn(self.lines)
            endif
            if type(self.on_exit_fn) == v:t_func
                call self.on_exit_fn(a:status)
            endif
        endfunction
        return job_start(a:cmd, {
                    \ 'out_cb': l:state.out_cb,
                    \ 'exit_cb': l:state.exit_cb,
                    \ 'out_mode': 'nl',
                    \ })
    endif
endfunction

function! hexedit#platform#JobStop(job) abort
    if a:job is 0 || a:job is -1 || a:job is v:null
        return
    endif
    if s:is_nvim
        silent! call jobstop(a:job)
    else
        silent! call job_stop(a:job)
    endif
endfunction

" Synchronous fallback / simple case: run cmd (List), return stdout as a List
" of lines. Used when async is unsupported or unnecessary.
function! hexedit#platform#SystemList(cmd) abort
    return systemlist(a:cmd)
endfunction

" ---- Highlighting -------------------------------------------------------

let s:vim_prop_types_defined = {}

" Ensure a highlight namespace/type named `name` exists, linked to hlgroup.
" Returns an opaque ns handle to pass into HighlightRange()/ClearNamespace().
function! hexedit#platform#EnsureNamespace(name, hlgroup) abort
    if s:is_nvim
        return nvim_create_namespace('hexedit_' . a:name)
    else
        if !has_key(s:vim_prop_types_defined, a:name)
            if empty(prop_type_get(a:name))
                call prop_type_add(a:name, {'highlight': a:hlgroup})
            endif
            let s:vim_prop_types_defined[a:name] = a:hlgroup
        endif
        return a:name
    endif
endfunction

" 1-indexed line, 1-indexed inclusive start col, exclusive end col (byte offsets)
function! hexedit#platform#HighlightRange(bufnr, ns, lnum, col_start, col_end, hlgroup) abort
    if a:col_end <= a:col_start
        return
    endif
    if s:is_nvim
        call nvim_buf_set_extmark(a:bufnr, a:ns, a:lnum - 1, a:col_start - 1, {
                    \ 'end_col': a:col_end - 1,
                    \ 'hl_group': a:hlgroup,
                    \ })
    else
        call prop_add(a:lnum, a:col_start, {
                    \ 'length': a:col_end - a:col_start,
                    \ 'type': a:ns,
                    \ 'bufnr': a:bufnr,
                    \ })
    endif
endfunction

function! hexedit#platform#ClearNamespace(bufnr, ns) abort
    if s:is_nvim
        call nvim_buf_clear_namespace(a:bufnr, a:ns, 0, -1)
    else
        silent! call prop_remove({'type': a:ns, 'bufnr': a:bufnr, 'all': 1}, 1, line('$'))
    endif
endfunction
