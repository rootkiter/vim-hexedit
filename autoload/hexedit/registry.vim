" hexedit#registry - mode registry & dispatch (REQUIREMENTS.md 2.3, 2.4, 2.5)
"
" A "mode object" is a Dict implementing:
"   Name()                    -> String, unique mode id (e.g. 'hexedit')
"   FileType()                -> String, &filetype to set while active
"   BinaryToView(model)       -> List of lines               [Renderable, required]
"   ViewToBinary(lines,model) -> [ok(0/1), model_or_errmsg]  [Editable, optional]
"   OnEnter()                 -> optional, install mappings/hooks
"   OnLeave()                 -> optional, uninstall mappings/hooks
"   <EventName>(...)          -> optional per-event hooks (OnCursorMoved, etc.)
"
" A mode is read-only iff it has no ViewToBinary key (REQUIREMENTS 2.3).
"
" Per-buffer state lives in b:hexedit_state = {'mode_name': ..., 'model': ...}.
" Its existence (non-empty) marks the plugin state machine as active for
" that buffer (REQUIREMENTS 2.5): the four switch commands only operate
" while it is active; :HexLoad creates it, :HexDump destroys it.

let s:modes = {}

function! hexedit#registry#Register(name, modeobj) abort
    let s:modes[a:name] = a:modeobj
endfunction

function! hexedit#registry#Get(name) abort
    return get(s:modes, a:name, v:null)
endfunction

function! hexedit#registry#Names() abort
    return keys(s:modes)
endfunction

function! hexedit#registry#IsEditable(modeobj) abort
    return has_key(a:modeobj, 'ViewToBinary')
endfunction

function! hexedit#registry#Reset() abort
    let s:modes = {}
endfunction

" ---- Per-buffer state -----------------------------------------------------

function! hexedit#registry#IsActive() abort
    return exists('b:hexedit_state') && !empty(b:hexedit_state)
endfunction

function! hexedit#registry#CurrentModeName() abort
    return hexedit#registry#IsActive() ? b:hexedit_state.mode_name : ''
endfunction

function! hexedit#registry#CurrentModel() abort
    return hexedit#registry#IsActive() ? b:hexedit_state.model : {}
endfunction

" Entry point: activate the state machine in the current buffer with the
" given model, immediately rendering `mode_name`. Does NOT call any
" ViewToBinary (there is nothing to parse from yet) -- this is the state
" machine's entry path (:HexLoad / auto-trigger), see REQUIREMENTS 2.5.
function! hexedit#registry#Activate(mode_name, model) abort
    let l:mode = hexedit#registry#Get(a:mode_name)
    if l:mode is v:null
        echom 'hexedit: unknown mode ' . a:mode_name
        return 0
    endif
    let b:hexedit_state = {'mode_name': '', 'model': a:model, 'saved_hex': a:model.plain_hex}
    call s:Render(l:mode, a:mode_name, a:model)
    " Vim/Neovim quirk: when this activation is happening inside a
    " BufReadCmd handler, replacing buffer content via deletebufline()+
    " setline() (as s:Render does) leaves the cursor on the *last* line
    " once :edit finishes, not line 1 -- confirmed empirically, not
    " something s:Render itself does. Force a sane starting position only
    " here, on first entry; s:Render is also used for mode switches and
    " window-slide reloads, where resetting the cursor would be wrong.
    call cursor(1, 1)
    call s:InstallWriteHook()
    return 1
endfunction

" Exit point: tear down the state machine, restoring the buffer to a plain
" filetype. Does not touch buffer content -- callers (e.g. :HexDump) render
" the final text themselves before calling this. See REQUIREMENTS 2.5.
function! hexedit#registry#Deactivate() abort
    if !hexedit#registry#IsActive()
        return
    endif
    let l:mode = hexedit#registry#Get(b:hexedit_state.mode_name)
    if l:mode isnot v:null && has_key(l:mode, 'OnLeave')
        call l:mode.OnLeave()
    endif
    call s:RemoveWriteHook()
    unlet b:hexedit_state
endfunction

" Buffer-scoped (never global!) BufWriteCmd, so :w on unrelated buffers is
" never affected. Installed only while the state machine is active in this
" buffer (REQUIREMENTS 2.5), removed on Deactivate() / :HexDump.
function! s:InstallWriteHook() abort
    execute 'augroup hexedit_write_' . bufnr('%')
    autocmd!
    autocmd BufWriteCmd <buffer> call hexedit#OnBufWriteCmd()
    augroup END
endfunction

function! s:RemoveWriteHook() abort
    execute 'augroup hexedit_write_' . bufnr('%')
    autocmd!
    augroup END
endfunction

" Internal transition: switch the buffer from its current mode to
" `target_name`, going through Canonical Model as required by
" REQUIREMENTS 2.4. Only valid while the state machine is active.
" Returns 1 on success, 0 on failure (validation error, shown via echom).
function! hexedit#registry#Switch(target_name) abort
    if !hexedit#registry#IsActive()
        echom 'hexedit: no active mode in this buffer; use :HexLoad first'
        return 0
    endif
    let l:target = hexedit#registry#Get(a:target_name)
    if l:target is v:null
        echom 'hexedit: unknown mode ' . a:target_name
        return 0
    endif

    let l:model = b:hexedit_state.model
    let l:cur_name = b:hexedit_state.mode_name
    let l:cur_mode = l:cur_name ==# '' ? v:null : hexedit#registry#Get(l:cur_name)

    if l:cur_mode isnot v:null && hexedit#registry#IsEditable(l:cur_mode)
        let [l:ok, l:result] = l:cur_mode.ViewToBinary(getline(1, '$'), l:model)
        if !l:ok
            echom 'hexedit: ' . l:result
            return 0
        endif
        let l:model = l:result
    endif

    if l:cur_mode isnot v:null && has_key(l:cur_mode, 'OnLeave')
        call l:cur_mode.OnLeave()
    endif

    let b:hexedit_state.model = l:model
    call s:Render(l:target, a:target_name, l:model)
    return 1
endfunction

" Marks the current model's bytes as the "last saved" baseline (e.g. after
" a successful :w, or after a large-file window reload freshly read from
" disk -- both cases where the buffer should read as unmodified even though
" s:Render() just called setline()). Re-syncs &modified immediately.
function! hexedit#registry#MarkSaved() abort
    if !hexedit#registry#IsActive()
        return
    endif
    let b:hexedit_state.saved_hex = b:hexedit_state.model.plain_hex
    call s:SyncModified()
endfunction

" Re-renders the current mode from b:hexedit_state.model as-is, without any
" ViewToBinary step. Used when the model was replaced wholesale from an
" external source (e.g. a large-file window reload, REQUIREMENTS 5.3)
" rather than derived from the current buffer text.
function! hexedit#registry#RenderCurrent() abort
    if !hexedit#registry#IsActive()
        return
    endif
    let l:mode = hexedit#registry#Get(b:hexedit_state.mode_name)
    call s:Render(l:mode, b:hexedit_state.mode_name, b:hexedit_state.model)
endfunction

function! s:Render(mode, mode_name, model) abort
    let l:lines = a:mode.BinaryToView(a:model)
    " Always render with a modifiable buffer, then let the *target* mode's
    " editability -- not whatever the previous mode left behind -- decide
    " the final state. (Previously this restored the pre-render state,
    " which left the buffer stuck non-modifiable after switching from a
    " read-only view back into an editable one.)
    setlocal modifiable
    silent! call deletebufline('%', 1, '$')
    call setline(1, l:lines)
    let &l:filetype = a:mode.FileType()
    let b:hexedit_state.mode_name = a:mode_name
    let b:hexedit_state.model = a:model
    if !hexedit#registry#IsEditable(a:mode)
        setlocal nomodifiable
    endif
    if has_key(a:mode, 'OnEnter')
        call a:mode.OnEnter()
    endif
    " setline()/deletebufline() above unconditionally mark the buffer
    " modified, regardless of whether the underlying bytes actually
    " changed (e.g. just switching between :Hedit/:Hex/:H2C/:H2Py with no
    " edits made). Recompute &modified from whether the model's bytes
    " actually differ from the last-saved snapshot instead of trusting
    " that side effect.
    call s:SyncModified()
endfunction

function! s:SyncModified() abort
    let l:saved = get(b:hexedit_state, 'saved_hex', b:hexedit_state.model.plain_hex)
    let &l:modified = (b:hexedit_state.model.plain_hex !=# l:saved)
endfunction

" Generic event dispatch to the current mode object, mirroring the old
" hexedit#ProcessEvent. Silently a no-op if inactive or the mode doesn't
" implement that event.
function! hexedit#registry#Dispatch(event, ...) abort
    if !hexedit#registry#IsActive()
        return
    endif
    let l:mode = hexedit#registry#Get(b:hexedit_state.mode_name)
    if l:mode is v:null || !has_key(l:mode, a:event)
        return
    endif
    call call(l:mode[a:event], a:000)
endfunction
