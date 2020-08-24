if exists("g:loaded_vimux") || &cp
  finish
endif
let g:loaded_vimux = 1

let g:VimuxHeight        = get(g:, "VimuxHeight",        20)
let g:VimuxOpenExtraArgs = get(g:, "VimuxOpenExtraArgs", " ")
let g:VimuxOrientation   = get(g:, "VimuxOrientation",   "v")
let g:VimuxPromptString  = get(g:, "VimuxPromptString",  "Command? ")
let g:VimuxResetSequence = get(g:, "VimuxResetSequence", "q C-u")
let g:VimuxRunnerType    = get(g:, "VimuxRunnerType",    "pane")
let g:VimuxTmuxCommand   = get(g:, "VimuxTmuxCommand",   "tmux")
let g:VimuxUseNearest    = get(g:, "VimuxUseNearest",    1)

command -nargs=* VimuxRunCommand    :call VimuxRunCommand(<args>)
command VimuxRunLastCommand         :call VimuxRunLastCommand()
command VimuxOpenRunner             :call VimuxOpenRunner()
command VimuxCloseRunner            :call VimuxCloseRunner()
command VimuxZoomRunner             :call VimuxZoomRunner()
command VimuxInspectRunner          :call VimuxInspectRunner()
command VimuxScrollUpInspect        :call VimuxScrollUpInspect()
command VimuxScrollDownInspect      :call VimuxScrollDownInspect()
command VimuxInterruptRunner        :call VimuxInterruptRunner()
command -nargs=? VimuxPromptCommand :call VimuxPromptCommand(<args>)
command VimuxClearRunnerHistory     :call VimuxClearRunnerHistory()
command VimuxTogglePane             :call VimuxTogglePane()

function! VimuxRunCommandInDir(command, useFile)
    let l:file = ""
    if a:useFile ==# 1
        let l:file = shellescape(expand('%:t'), 1)
    endif
    call VimuxRunCommand("(cd ".shellescape(expand('%:p:h'), 1)." && ".a:command." ".l:file.")")
endfunction

function! VimuxRunLastCommand()
  if _VimuxHasRunner()
    call VimuxRunCommand(g:VimuxLastCommand)
  else
    call _VimuxEchoNoRunner()
  endif
endfunction

function! VimuxRunCommand(command, ...)
  if !_VimuxHasRunner()
    call VimuxOpenRunner()
  endif

  let l:autoreturn = get(a:, 1, 1)
  let g:VimuxLastCommand = a:command

  call VimuxSendKeys(g:VimuxResetSequence)
  call VimuxSendText(a:command)

  if l:autoreturn
    call VimuxSendKeys("Enter")
  endif
endfunction

function! VimuxSendText(text)
  call VimuxSendKeys('"'.escape(a:text, '\"$`').'"')
endfunction

function! VimuxSendKeys(keys)
  if _VimuxHasRunner()
    call _VimuxTmux("send-keys -t ".g:VimuxRunnerIndex." ".a:keys)
  else
    call _VimuxEchoNoRunner()
  endif
endfunction

function! VimuxOpenRunner()
  let nearestIndex = _VimuxNearestIndex()

  if g:VimuxUseNearest && nearestIndex != -1
    let g:VimuxRunnerIndex = nearestIndex
  else
    if g:VimuxRunnerType == "pane"
      let height = g:VimuxHeight
      let orientation = g:VimuxOrientation
      call _VimuxTmux("split-window -p ".height." -".orientation." ".g:VimuxOpenExtraArgs)
    elseif g:VimuxRunnerType == "window"
      call _VimuxTmux("new-window ".g:VimuxOpenExtraArgs)
    endif

    let g:VimuxRunnerIndex = _VimuxTmuxIndex()
    call _VimuxTmux("last-".g:VimuxRunnerType)
  endif
endfunction

function! VimuxCloseRunner()
  if _VimuxHasRunner()
    call _VimuxTmux("kill-".g:VimuxRunnerType." -t ".g:VimuxRunnerIndex)
    unlet g:VimuxRunnerIndex
  else
    call _VimuxEchoNoRunner()
  endif
endfunction

function! VimuxTogglePane()
  if _VimuxHasRunner()
    if g:VimuxRunnerType == "window"
      let g:VimuxRunnerType = "pane"
      call _VimuxTmux("join-pane -d -s ".g:VimuxRunnerIndex." -p ".g:VimuxHeight)
    elseif g:VimuxRunnerType == "pane"
      let g:VimuxRunnerType = "window"
      let g:VimuxRunnerIndex = _VimuxTmux("break-pane -d -s ".g:VimuxRunnerIndex." -P -F "._VimuxRunnerIdFormat())[0]
    else
      echoerr "Invalid option value: g:VimuxRunnerType = " .. g:VimuxRunnerType
    endif
  else
    call _VimuxEchoNoRunner()
  endif
endfunction

function! VimuxZoomRunner()
  if _VimuxHasRunner()
    if g:VimuxRunnerType == "pane"
      call _VimuxTmux("resize-pane -Z -t ".g:VimuxRunnerIndex)
    elseif g:VimuxRunnerType == "window"
      call _VimuxTmux("select-window -t ".g:VimuxRunnerIndex)
    endif
  else
    call _VimuxEchoNoRunner()
  endif
endfunction

function! VimuxInspectRunner()
  if _VimuxHasRunner()
    call _VimuxTmux("select-".g:VimuxRunnerType." -t ".g:VimuxRunnerIndex)
    call _VimuxTmux("copy-mode")
    return v:true
  else
    call _VimuxEchoNoRunner()
    return v:false
  endif
endfunction

function! VimuxScrollUpInspect()
  if VimuxInspectRunner()
    call _VimuxTmux("last-".g:VimuxRunnerType)
    call VimuxSendKeys("C-u")
  endif
endfunction

function! VimuxScrollDownInspect()
  if VimuxInspectRunner()
    call _VimuxTmux("last-".g:VimuxRunnerType)
    call VimuxSendKeys("C-d")
  endif
endfunction

function! VimuxInterruptRunner()
  call VimuxSendKeys("^c")
endfunction

function! VimuxClearRunnerHistory()
  if _VimuxHasRunner()
    call _VimuxTmux("clear-history -t ".g:VimuxRunnerIndex)
  else
    call _VimuxEchoNoRunner()
  endif
endfunction

function! VimuxPromptCommand(...)
  let command = get(a:, 1, "")
  let l:command = input(g:VimuxPromptString, command)
  call VimuxRunCommand(l:command)
endfunction

function! _VimuxTmux(arguments)
  return systemlist(g:VimuxTmuxCommand." ".a:arguments)
endfunction

function! _VimuxTmuxIndex()
  return _VimuxTmuxProperty(_VimuxRunnerIdFormat())
endfunction

function! _VimuxNearestIndex()
  let views = _VimuxTmux("list-".g:VimuxRunnerType."s")

  for view in views
    if match(view, "(active)") == -1
      return split(view, ":")[0]
    endif
  endfor

  return -1
endfunction

function! _VimuxTmuxProperty(property)
    return _VimuxTmux("display -p ".a:property)[0]
endfunction

function! _VimuxHasRunner(index = v:false)
  if !a:index
    if !exists('g:VimuxRunnerIndex')
      return v:false
    endif
    let runner_index = g:VimuxRunnerIndex
  else
    let runner_index = a:index
  endif

  let panes = _VimuxTmux("list-".g:VimuxRunnerType."s -F "._VimuxRunnerIdFormat())

  if index(panes, runner_index) == -1
    unlet! g:VimuxRunnerIndex
    return v:false
  endif
  return v:true
endfunction

function! _VimuxEchoNoRunner()
  echo "No vimux runner pane/window. Create one with VimuxOpenRunner."
endfunction

function! _VimuxRunnerIdFormat()
    return '"#{'.g:VimuxRunnerType.'_id}"'
endfunction
