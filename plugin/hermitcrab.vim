scriptencoding utf-8

let s:cpoptions_bak = &cpoptions
set cpoptions&vim

"if exists('g:hermitcrab_vim')
"	finish
"else
"	let g:hermitcrab_vim = 1
"endif

" utils {{{
function! s:useVariable(name, defaultValue, mustExtend)
	let typeId = type(a:defaultValue)
	let mustExtend
	\	= a:mustExtend && (typeId == type([]) || typeId == type({}))

	if exists(a:name)
		if mustExtend
			execute 'call extend(' . a:name . ', a:defaultValue, "keep")'
		endif
	else
		execute 'let' a:name '=' string(a:defaultValue)
	endif
endfunction
" }}} utils

function! s:getShellNameFromPath(path)
	return fnamemodify(a:path, ':t')
endfunction

function! s:getShellNameFromShellOpt(opt)
	let path = matchstr(a:opt, '\"\zs.\+\ze\"')
	if path == ''
		let path = matchstr(a:opt, '^\S\+')
	endif
	return s:getShellNameFromPath(path)
endfunction

" Initialized g:hermitcrab_shells.
function! s:initConfigureVariable()
let s:defaultOpts = hermitcrab#confirmShell()
call s:useVariable('g:hermitcrab_shells', 
\	{ s:getShellNameFromShellOpt(s:defaultOpts['shell']): s:defaultOpts },
\	1
\ )
endfunction
" When Vim load plugin scripts, some option's values is setted wrong
" value. Specifically, 'shellpipe' and 'shellredir' at version 7.3.46
" for Windows.
" [TODO] un-:autocmd-ized / un-function-ized this process when fix this
" bug(?).
autocmd VimEnter * call s:initConfigureVariable()

function! s:switchShellAtOnce(cmd)
	let name = matchstr(a:cmd, '^\S\+')
	let cmd = matchstr(a:cmd, '^\S\+\s+\zs')
	call hermitcrab#run(name, cmd)
endfunction

command! -nargs=1 -complete=custom,hermitcrab#getCompletion -bar
\	HermitCrabSwitch call hermitcrab#switch(<f-args>)

command! -nargs=1 -complete=custom,hermitcrab#getCompletion
\	HermitCrabRun call s:switchShellAtOnce(<q-args>)

let &cpoptions = s:cpoptions_bak
