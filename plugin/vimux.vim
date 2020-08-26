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
command VimuxFocusRunner            :call VimuxFocusRunner()
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
    call VimuxRunCommand("(cd " .. shellescape(expand('%:p:h'), 1) .. " && " .. a:command .. " " .. l:file .. ")")
endfunction


function! VimuxRunLastCommand()
  if VimuxHasRunner()
    call VimuxRunCommand(g:VimuxLastCommand)
  else
    call VimuxEchoNoRunner()
  endif
endfunction


function! VimuxRunCommand(command, ...)
  if !VimuxHasRunner()
    call VimuxOpenRunner()
  endif

  call VimuxSendKeys(g:VimuxResetSequence)
  call VimuxSendText(a:command)
  let g:VimuxLastCommand = a:command

  if get(a:, 1, v:false)
    call VimuxSendKeys("Enter")
  endif
endfunction


function! VimuxSendText(text)
  call VimuxSendKeys('"' .. escape(a:text, '\"$`') .. '"')
endfunction


function! VimuxSendKeys(keys)
  if VimuxHasRunner()
    call VimuxTmux("send-keys -t " .. g:VimuxRunnerIndex .. " " .. a:keys)
  else
    call VimuxEchoNoRunner()
  endif
endfunction


function! VimuxOpenRunner()
  let nearestIndex = VimuxNearestIndex()

  if g:VimuxUseNearest && nearestIndex != -1
    let g:VimuxRunnerIndex = nearestIndex
  else
    if g:VimuxRunnerType == "pane"
      let l:command   = "split-window "
      let l:command ..= "-p " .. g:VimuxHeight
      let l:command ..= " -" .. g:VimuxOrientation
      call VimuxTmux(l:command .. " " .. g:VimuxOpenExtraArgs)
    elseif g:VimuxRunnerType == "window"
      call VimuxTmux("new-window " .. g:VimuxOpenExtraArgs)
    endif

    let g:VimuxRunnerIndex = VimuxTmuxIndex()
    call VimuxTmux("last-" .. g:VimuxRunnerType)
  endif
endfunction


function! VimuxCloseRunner()
  if VimuxHasRunner()
    call VimuxTmux("kill-" .. g:VimuxRunnerType .. " -t " .. g:VimuxRunnerIndex)
    unlet g:VimuxRunnerIndex
  else
    call VimuxEchoNoRunner()
  endif
endfunction


function! VimuxTogglePane()
  if VimuxHasRunner()
    if g:VimuxRunnerType == "window"
      let g:VimuxRunnerType = "pane"
      call VimuxTmux("join-pane -s " .. g:VimuxRunnerIndex .. " -t" .. VimuxTmuxIndex() .. " -p " .. g:VimuxHeight)
    elseif g:VimuxRunnerType == "pane"
      let g:VimuxRunnerType = "window"
      call VimuxTmux("break-pane -s " .. g:VimuxRunnerIndex)
    else
      echoerr "Invalid option value: g:VimuxRunnerType = " .. g:VimuxRunnerType
      return
    endif

    " Recover runner index info and return to vim pane.
    let g:VimuxRunnerIndex = VimuxTmuxIndex()
    call VimuxTmux("last-" .. g:VimuxRunnerType)

  else
    call VimuxEchoNoRunner()
  endif
endfunction


function! VimuxZoomRunner()
  if VimuxHasRunner()
    if g:VimuxRunnerType == "pane"
      call VimuxTmux("resize-pane -Z -t " .. g:VimuxRunnerIndex)
    elseif g:VimuxRunnerType == "window"
      call VimuxTmux("select-window -t " .. g:VimuxRunnerIndex)
    endif
  else
    call VimuxEchoNoRunner()
  endif
endfunction


function! VimuxFocusRunner()
  if VimuxHasRunner()
    call VimuxTmux("select-" .. g:VimuxRunnerType .. " -t " .. g:VimuxRunnerIndex)
  else
    call VimuxEchoNoRunner()
  endif
endfunction


function! VimuxInspectRunner()
  if VimuxHasRunner()
    call VimuxTmux("select-" .. g:VimuxRunnerType .. " -t " .. g:VimuxRunnerIndex)
    call VimuxTmux("copy-mode")
    return v:true
  else
    call VimuxEchoNoRunner()
    return v:false
  endif
endfunction


function! VimuxScrollUpInspect()
  if VimuxInspectRunner()
    call VimuxTmux("last-" .. g:VimuxRunnerType)
    call VimuxSendKeys("C-u")
  endif
endfunction


function! VimuxScrollDownInspect()
  if VimuxInspectRunner()
    call VimuxTmux("last-" .. g:VimuxRunnerType)
    call VimuxSendKeys("C-d")
  endif
endfunction


function! VimuxInterruptRunner()
  call VimuxSendKeys("^c")
endfunction


function! VimuxClearRunnerHistory()
  if VimuxHasRunner()
    call VimuxTmux("clear-history -t " .. g:VimuxRunnerIndex)
  else
    call VimuxEchoNoRunner()
  endif
endfunction


function! VimuxPromptCommand(...)
  let command = get(a:, 1, "")
  let l:command = input(g:VimuxPromptString, command)
  call VimuxRunCommand(l:command)
endfunction


function! VimuxTmux(arguments)
  return systemlist(g:VimuxTmuxCommand .. " " .. a:arguments)
endfunction


function! VimuxTmuxIndex()
  return VimuxTmuxProperty(VimuxRunnerIdFormat())
endfunction


function! VimuxNearestIndex()
  let views = VimuxTmux("list-" .. g:VimuxRunnerType .. "s")

  for view in views
    if match(view, "(active)") == -1
      return split(view, ":")[0]
    endif
  endfor

  return -1
endfunction


function! VimuxTmuxProperty(property)
    return VimuxTmux("display -p " .. a:property)[0]
endfunction


function! VimuxHasRunner(index = v:false)
  if !a:index
    if !exists('g:VimuxRunnerIndex')
      return v:false
    endif
    let runner_index = g:VimuxRunnerIndex
  else
    let runner_index = a:index
  endif

  let possibilities = VimuxTmux("list-" .. g:VimuxRunnerType .. "s -F " .. VimuxRunnerIdFormat())

  if index(possibilities, runner_index) == -1
    unlet! g:VimuxRunnerIndex
    return v:false
  endif
  return v:true
endfunction


function! VimuxEchoNoRunner()
  echo "No vimux runner pane/window. Create one with VimuxOpenRunner."
endfunction


function! VimuxRunnerIdFormat()
    return '"#{' .. g:VimuxRunnerType .. '_id}"'
endfunction
