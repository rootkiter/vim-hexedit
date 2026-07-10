" hexedit - top-level command dispatch (REQUIREMENTS.md 2.5, 3, 5, 6)
"
" This file only wires commands/autocmd events to the registry + model
" layers; it holds no mode-specific rendering/editing logic itself.

function! hexedit#version() abort
    return '2.0.0'
endfunction

" ---- One-time mode registration -------------------------------------------
" (autoload files execute their top-level code exactly once, on first
" reference, so this acts as a module init.)

call hexedit#registry#Register('hexedit', hexedit#modes#hexedit#Get())
call hexedit#registry#Register('hexstr', hexedit#modes#hexstr#Get())
call hexedit#registry#Register('c_view', hexedit#modes#c_view#Get())
call hexedit#registry#Register('py_view', hexedit#modes#py_view#Get())
call hexedit#registry#Register('format_parse', hexedit#modes#format_parse#Get())

" ---- Internal state-machine transitions (2.5): :Hedit :Hex :H2C :H2Py ----
" These only operate while the state machine is already active; they never
" handle entering from / exiting to plain Vim editing (that is HexLoad's
" and HexDump's job, exclusively).

function! hexedit#Hedit() abort
    call hexedit#registry#Switch('hexedit')
endfunction

function! hexedit#Hex() abort
    call hexedit#registry#Switch('hexstr')
endfunction

function! hexedit#H2C() abort
    call hexedit#registry#Switch('c_view')
endfunction

function! hexedit#H2Py() abort
    call hexedit#registry#Switch('py_view')
endfunction

" ---- State-machine entry point: :HexLoad ----------------------------------

" opts.confirm_fn: optional Funcref(msg) -> confirm()-style return value
" (1 = binary, 2 = text), injectable for tests so this never blocks on a
" real confirm() dialog in a headless run.
function! hexedit#HexLoad(...) abort
    let l:opts = a:0 > 0 ? a:1 : {}
    let l:Confirm_fn = get(l:opts, 'confirm_fn', function('s:DefaultHexLoadConfirm'))
    if hexedit#registry#IsActive()
        echom 'hexedit: this buffer is already inside the plugin state machine'
        return
    endif
    let [l:ok, l:result] = hexedit#model#ParseHexStringLines(getline(1, '$'))
    if !l:ok
        echom 'hexedit: ' . l:result
        return
    endif
    let l:model = hexedit#model#FromPlainHex(l:result)
    if !empty(bufname('%'))
        let l:model.path = fnamemodify(bufname('%'), ':p')
        " Ambiguity only exists when there's a real file that could be
        " overwritten: ask once, up front, whether future saves of this
        " content should write back as binary (decoded bytes) or as text
        " (the hex-string form) -- see REQUIREMENTS.md 6.3.
        let l:msg = printf(
                    \ 'When saving, keep %s in its original (binary) form, or convert it to a hex string?',
                    \ l:model.path)
        let l:model.write_mode = (l:Confirm_fn(l:msg) ==# 2) ? 'text' : 'binary'
    endif
    setlocal binary noeol
    call hexedit#registry#Activate('hexedit', l:model)
endfunction

function! s:DefaultHexLoadConfirm(msg) abort
    return confirm(a:msg, "&Original\n&HexString", 1)
endfunction

" ---- State-machine exit point: :HexDump -----------------------------------

" Exit point: works from ANY active mode (Hedit/Hex/H2C/H2Py/format_parse),
" not just Hex Edit mode -- if the current mode is editable, its buffer
" text is parsed back into the model first (same ViewToBinary step a mode
" switch would do); read-only modes have no buffer-text source of truth,
" so the existing model is used as-is.
function! hexedit#HexDump() abort
    if !hexedit#registry#IsActive()
        echom 'hexedit: not inside the plugin state machine; no need to run :HexDump'
        return
    endif
    let l:cur_mode = hexedit#registry#Get(hexedit#registry#CurrentModeName())
    let l:model = hexedit#registry#CurrentModel()
    if hexedit#registry#IsEditable(l:cur_mode)
        let [l:ok, l:result] = l:cur_mode.ViewToBinary(getline(1, '$'), l:model)
        if !l:ok
            echom 'hexedit: ' . l:result
            return
        endif
        let l:model = l:result
    endif
    if l:model.is_windowed
        echom 'hexedit: in large-file windowed mode, :HexDump only exports the currently loaded window, not the whole file'
    endif
    let l:lines = hexedit#model#ToHexStringLines(l:model)
    call hexedit#registry#Deactivate()
    setlocal modifiable
    silent! call deletebufline('%', 1, '$')
    call setline(1, l:lines)
    setlocal nobinary
    filetype detect
endfunction

" ---- :HGoto {offset} (5.6) -------------------------------------------------

function! hexedit#HGoto(offsetstr) abort
    if !hexedit#registry#IsActive()
        echom 'hexedit: not inside the plugin state machine'
        return
    endif
    let l:model = hexedit#registry#CurrentModel()
    if l:model.path ==# ''
        echom 'hexedit: current content has no associated file; cannot jump by offset'
        return
    endif
    let l:offset = hexedit#ParseOffset(a:offsetstr)
    if l:offset < 0
        echom 'hexedit: invalid offset: ' . a:offsetstr
        return
    endif
    call hexedit#GotoAbsoluteOffset(l:offset)
endfunction

" Shared by :HGoto and :Hsearch/`n` hits (REQUIREMENTS.md 5.7): given an
" already-known, already-validated absolute byte offset, jump to it --
" moving the cursor directly if the offset is already loaded, or
" recentering the cache window first if it isn't. Returns 1 on success, 0
" if the jump was refused (unsaved changes would otherwise be silently
" discarded by a window reload -- REQUIREMENTS.md 5.6).
function! hexedit#GotoAbsoluteOffset(offset) abort
    let l:model = hexedit#registry#CurrentModel()
    if !l:model.is_windowed
        call hexedit#GotoOffsetInBuffer(a:offset)
        return 1
    endif
    if a:offset >= l:model.window_offset && a:offset < l:model.window_offset + l:model.window_length
        call hexedit#GotoOffsetInBuffer(a:offset)
        return 1
    endif
    if &l:modified
        echom 'hexedit: current window has unsaved changes and this jump requires reloading the cache window; :w first, then jump'
        return 0
    endif
    call hexedit#LoadWindowCentered(a:offset)
    return 1
endfunction

function! hexedit#ParseOffset(text) abort
    let l:t = trim(a:text)
    if l:t =~? '^0x\x\+$'
        return str2nr(l:t, 16)
    elseif l:t =~# '^\d\+$'
        return str2nr(l:t, 10)
    endif
    return -1
endfunction

" ---- :Hsearch / :HsearchClean -----------------------------------------

function! hexedit#Hsearch(arg) abort
    call hexedit#registry#Dispatch('BuildInCommand', 'Hsearch', a:arg)
endfunction

function! hexedit#HsearchClean() abort
    call hexedit#registry#Dispatch('BuildInCommand', 'HsearchClean', '')
endfunction

" ---- Auto-trigger (6.1 / 6.2) and large-file windowing (section 5) -------

function! hexedit#CacheWindowSize() abort
    let l:window_size = get(g:, 'hexedit_window_size', 65536)
    let l:ratio = get(g:, 'hexedit_cache_window_ratio', 3)
    return l:window_size * l:ratio
endfunction

function! s:ActivateFromFile(path) abort
    let l:size = getfsize(a:path)
    let l:threshold = get(g:, 'hexedit_large_file_threshold', 1 * 1024 * 1024)
    if l:size >= 0 && l:size > l:threshold
        let l:model = hexedit#model#FromFileWindow(a:path, 0, hexedit#CacheWindowSize())
    else
        let l:model = hexedit#model#FromWholeFile(a:path)
    endif
    call hexedit#registry#Activate('hexedit', l:model)
endfunction

" Takes over reading entirely for files matching g:hexedit_patterns (6.2),
" so a large file is never slurped whole by Vim's own file read -- we
" choose how many bytes to pull via xxd ourselves (section 5.2).
function! hexedit#OnBufReadCmd() abort
    let l:path = fnamemodify(expand('<amatch>'), ':p')
    setlocal binary noeol
    call s:ActivateFromFile(l:path)
endfunction

function! hexedit#OnBufNewFileCmd() abort
    setlocal binary noeol
    let l:model = hexedit#model#Empty()
    if !empty(bufname('%'))
        let l:model.path = fnamemodify(bufname('%'), ':p')
    endif
    call hexedit#registry#Activate('hexedit', l:model)
endfunction

" Fallback for requirement 6.1: files opened via an explicit -b/++bin flag
" (or :set binary) on a name that does NOT match g:hexedit_patterns. Vim
" will already have read the whole file raw into the buffer by the time
" this fires (BufReadPost runs after the read, and there is no filename
" pattern to intercept ahead of time for an arbitrary name) -- that one
" full read cannot be avoided here. We still rebuild the model with a
" fresh, possibly-windowed xxd read straight from disk and replace the
" buffer content immediately, so ongoing rendering/editing/writing gets
" the large-file benefits even though the initial read did not.
function! hexedit#OnBufReadPost() abort
    if &l:binary !=# 1
        return
    endif
    if hexedit#registry#IsActive()
        return
    endif
    let l:path = fnamemodify(bufname('%'), ':p')
    if !filereadable(l:path)
        return
    endif
    call s:ActivateFromFile(l:path)
endfunction

function! hexedit#OnBufNewFile() abort
    if &l:binary !=# 1
        return
    endif
    if hexedit#registry#IsActive()
        return
    endif
    call hexedit#OnBufNewFileCmd()
endfunction

" ---- :w interception while the state machine is active --------------------

function! hexedit#OnBufWriteCmd() abort
    if !hexedit#registry#IsActive()
        silent execute 'noautocmd write ' . fnameescape(expand('<afile>'))
        return
    endif
    let l:cur_name = hexedit#registry#CurrentModeName()
    let l:cur_mode = hexedit#registry#Get(l:cur_name)
    let l:model = hexedit#registry#CurrentModel()
    if hexedit#registry#IsEditable(l:cur_mode)
        let [l:ok, l:result] = l:cur_mode.ViewToBinary(getline(1, '$'), l:model)
        if !l:ok
            echom 'hexedit: ' . l:result
            return
        endif
        let l:model = l:result
        let b:hexedit_state.model = l:model
    endif
    let [l:ok, l:msg] = hexedit#model#Save(l:model)
    if !l:ok
        echom 'hexedit: ' . l:msg
        return
    endif
    call hexedit#registry#MarkSaved()
endfunction

" ---- Event dispatch (autocmd glue) ----------------------------------------

function! hexedit#OnCursorMoved() abort
    call hexedit#registry#Dispatch('OnCursorMoved')
    call s:MaybeSlideWindow()
endfunction

function! hexedit#OnCursorMovedI() abort
    call hexedit#registry#Dispatch('OnCursorMovedI')
endfunction

function! hexedit#OnInsertEnter() abort
    call hexedit#registry#Dispatch('OnInsertEnter')
endfunction

function! hexedit#OnInsertLeave() abort
    call hexedit#registry#Dispatch('OnInsertLeave')
endfunction

function! hexedit#OnTextChanged() abort
    call hexedit#registry#Dispatch('OnTextChanged')
endfunction

function! hexedit#OnInsertCharPre() abort
    call hexedit#registry#Dispatch('OnInsertCharPre')
endfunction

" ---- Large-file window sliding (5.3) --------------------------------------
"
" Simplification vs. the full spec: the "visible window" and "cache window"
" are collapsed into one -- the buffer always shows exactly the currently
" loaded cache window, and Vim's own scrolling moves within it. This avoids
" needing a virtual/partial-buffer rendering scheme that Vimscript has no
" good primitive for. See REQUIREMENTS.md follow-up notes.
"
" Safety rule: never auto-slide (and thus never discard-and-reread from
" disk) while the buffer has unsaved changes -- silent data loss would
" otherwise be possible. The user must :w (or manually :HGoto) to continue
" past the edge while edits are pending.
function! s:MaybeSlideWindow() abort
    if !hexedit#registry#IsActive()
        return
    endif
    if hexedit#registry#CurrentModeName() !=# 'hexedit'
        return
    endif
    if &l:modified
        return
    endif
    let l:model = hexedit#registry#CurrentModel()
    if !l:model.is_windowed || l:model.window_length <= 0
        return
    endif
    if !exists('b:hexedit_line_offset_number')
        return
    endif
    let l:pos = b:hexedit_line_offset_number
    let l:ratio = (l:pos - l:model.window_offset) * 1.0 / l:model.window_length
    let l:near_start = l:model.window_offset <=# 0
    let l:near_end = (l:model.window_offset + l:model.window_length) >=# l:model.total_size
    if l:ratio < 0.3 && !l:near_start
        call hexedit#LoadWindowCentered(l:pos)
    elseif l:ratio > 0.7 && !l:near_end
        call hexedit#LoadWindowCentered(l:pos)
    endif
endfunction

function! hexedit#LoadWindowCentered(pos) abort
    let l:model = hexedit#registry#CurrentModel()
    let l:cache_size = hexedit#CacheWindowSize()
    let l:half = l:cache_size / 2
    let l:offset = max([0, a:pos - l:half])
    if l:offset + l:cache_size > l:model.total_size
        let l:offset = max([0, l:model.total_size - l:cache_size])
    endif
    " Align the window start to the file's own octets_per_line grid (e.g.
    " a multiple of 0x10 for the default 16 bytes/line), not just wherever
    " "pos - half" happened to land. Otherwise a given file offset would
    " render in a different column depending on which window happened to
    " load it, instead of the fixed column a real hex dump always uses.
    " hexedit#model#FromFileWindow clamps the length on its own if this
    " pushes offset+cache_size past EOF, so the tail of the file is still
    " reached exactly, just possibly in a slightly shorter last window.
    if l:model.octets_per_line > 0
        let l:offset -= l:offset % l:model.octets_per_line
    endif
    let l:new_model = hexedit#model#FromFileWindow(l:model.path, l:offset, l:cache_size, {
                \ 'group_octets_num': l:model.group_octets_num,
                \ 'octets_per_line': l:model.octets_per_line,
                \ 'low_up': l:model.low_up,
                \ })
    let b:hexedit_state.model = l:new_model
    call hexedit#registry#RenderCurrent()
    call hexedit#registry#MarkSaved()
    call hexedit#GotoOffsetInBuffer(a:pos)
endfunction

function! hexedit#GotoOffsetInBuffer(pos) abort
    let l:model = hexedit#registry#CurrentModel()
    if l:model.octets_per_line <= 0
        return
    endif
    let l:rel = a:pos - l:model.window_offset
    if l:rel < 0
        let l:rel = 0
    endif
    let l:line = l:rel / l:model.octets_per_line + 1
    let l:maxline = line('$')
    if l:line > l:maxline
        let l:line = l:maxline
    endif
    call cursor(l:line, 1)
    call hexedit#OnCursorMoved()
    " Hex Edit mode's line layout is the only one whose column geometry is
    " known here; land exactly on the target byte's hex digit rather than
    " just the start of its line. Other modes (hexstr/c_view/py_view) keep
    " the coarser line-1 placement above -- their layouts aren't line-per-
    " fixed-byte-count, so there's no equivalent "exact column" to compute.
    if hexedit#registry#CurrentModeName() ==# 'hexedit'
        call hexedit#modes#hexedit#GotoByteInLine(l:rel % l:model.octets_per_line)
    endif
endfunction
