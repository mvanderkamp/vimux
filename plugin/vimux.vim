if exists("g:loaded_vimux") || &cp
  finish
endif
let g:loaded_vimux = 1

command -nargs=* VimuxRunCommand :call VimuxRunCommand(<args>)
command VimuxRunLastCommand :call VimuxRunLastCommand()
command VimuxOpenRunner :call VimuxOpenRunner()
command VimuxCloseRunner :call VimuxCloseRunner()
command VimuxZoomRunner :call VimuxZoomRunner()
command VimuxInspectRunner :call VimuxInspectRunner()
command VimuxScrollUpInspect :call VimuxScrollUpInspect()
command VimuxScrollDownInspect :call VimuxScrollDownInspect()
command VimuxInterruptRunner :call VimuxInterruptRunner()
command -nargs=? VimuxPromptCommand :call VimuxPromptCommand(<args>)
command VimuxClearRunnerHistory :call VimuxClearRunnerHistory()
command VimuxTogglePane :call VimuxTogglePane()

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

  let l:autoreturn = 1
  if exists("a:1")
    let l:autoreturn = a:1
  endif

  let resetSequence = _VimuxOption("g:VimuxResetSequence", "q C-u")
  let g:VimuxLastCommand = a:command

  call VimuxSendKeys(resetSequence)
  call VimuxSendText(a:command)

  if l:autoreturn == 1
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

  if _VimuxOption("g:VimuxUseNearest", 1) == 1 && nearestIndex != -1
    let g:VimuxRunnerIndex = nearestIndex
  else
    let extraArguments = _VimuxOption("g:VimuxOpenExtraArgs", " ")
    if _VimuxRunnerType() == "pane"
      let height = _VimuxOption("g:VimuxHeight", 20)
      let orientation = _VimuxOption("g:VimuxOrientation", "v")
      call _VimuxTmux("split-window -p ".height." -".orientation." ".extraArguments)
    elseif _VimuxRunnerType() == "window"
      call _VimuxTmux("new-window ".extraArguments)
    endif

    let g:VimuxRunnerIndex = _VimuxTmuxIndex()
    call _VimuxTmux("last-"._VimuxRunnerType())
  endif
endfunction

function! VimuxCloseRunner()
  if _VimuxHasRunner()
    call _VimuxTmux("kill-"._VimuxRunnerType()." -t ".g:VimuxRunnerIndex)
    unlet g:VimuxRunnerIndex
  else
    call _VimuxEchoNoRunner()
  endif
endfunction

function! VimuxTogglePane()
  if _VimuxHasRunner()
    if _VimuxRunnerType() == "window"
      call _VimuxTmux("join-pane -d -s ".g:VimuxRunnerIndex." -p "._VimuxOption("g:VimuxHeight", 20))
      let g:VimuxRunnerType = "pane"
    elseif _VimuxRunnerType() == "pane"
      let g:VimuxRunnerIndex = _VimuxTmux("break-pane -d -t ".g:VimuxRunnerIndex." -P -F "._VimuxRunnerIdFormat())[0]
      let g:VimuxRunnerType = "window"
    endif
  else
    call _VimuxEchoNoRunner()
  endif
endfunction

function! VimuxZoomRunner()
  if _VimuxHasRunner()
    if _VimuxRunnerType() == "pane"
      call _VimuxTmux("resize-pane -Z -t ".g:VimuxRunnerIndex)
    elseif _VimuxRunnerType() == "window"
      call _VimuxTmux("select-window -t ".g:VimuxRunnerIndex)
    endif
  else
    call _VimuxEchoNoRunner()
  endif
endfunction

function! VimuxInspectRunner()
  if _VimuxHasRunner()
    call _VimuxTmux("select-"._VimuxRunnerType()." -t ".g:VimuxRunnerIndex)
    call _VimuxTmux("copy-mode")
    return v:true
  else
    call _VimuxEchoNoRunner()
    return v:false
  endif
endfunction

function! VimuxScrollUpInspect()
  if VimuxInspectRunner()
    call _VimuxTmux("last-"._VimuxRunnerType())
    call VimuxSendKeys("C-u")
  endif
endfunction

function! VimuxScrollDownInspect()
  if VimuxInspectRunner()
    call _VimuxTmux("last-"._VimuxRunnerType())
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
  let command = a:0 == 1 ? a:1 : ""
  let l:command = input(_VimuxOption("g:VimuxPromptString", "Command? "), command)
  call VimuxRunCommand(l:command)
endfunction

function! _VimuxTmux(arguments)
  let l:command = _VimuxOption("g:VimuxTmuxCommand", "tmux")
  return systemlist(l:command." ".a:arguments)
endfunction

function! _VimuxTmuxIndex()
  return _VimuxTmuxProperty(_VimuxRunnerIdFormat())
endfunction

function! _VimuxNearestIndex()
  let views = _VimuxTmux("list-"._VimuxRunnerType()."s")

  for view in views
    if match(view, "(active)") == -1
      return split(view, ":")[0]
    endif
  endfor

  return -1
endfunction

function! _VimuxRunnerType()
  return _VimuxOption("g:VimuxRunnerType", "pane")
endfunction

function! _VimuxOption(option, default)
  if exists(a:option)
    return eval(a:option)
  else
    return a:default
  endif
endfunction

function! _VimuxTmuxProperty(property)
    return _VimuxTmux("display -p ".a:property)[0]
endfunction

function! _VimuxHasRunner(index = v:false)
  if a:index == v:false
    if !exists('g:VimuxRunnerIndex')
      return v:false
    endif
    let runner_index = g:VimuxRunnerIndex
  else
    let runner_index = a:index
  endif

  let panes = _VimuxTmux("list-"._VimuxRunnerType()."s -F "._VimuxRunnerIdFormat())

  if index(panes, runner_index) == -1
    if exists('g:VimuxRunnerIndex')
      " It should not exist, so remove it.
      unlet g:VimuxRunnerIndex
    endif
    return v:false
  endif
  return v:true
endfunction

function! _VimuxEchoNoRunner()
  echo "No vimux runner pane/window. Create one with VimuxOpenRunner."
endfunction

function! _VimuxRunnerIdFormat()
    return '"#{'._VimuxRunnerType().'_id}"'
endfunction
