scriptencoding utf-8

let s:cpoptions_bak = &cpoptions
set cpoptions&vim

" utils {{{
" exceptions {{{
let s:pluginName = 'hermitcrab.vim'
" Raise an exception string like 'Labeled Tab Separated Value'.
" format:
" 	(pluginName)\tdescription:(description)
function! s:raiseException(...) " {{{
	" Vim's exception string formats are:
	" 	Vim:E000:foobar
	" 	Vim(hoge):foobar
	" 	Vim(hoge):E000:foobar

	let msg = (a:0 == 0) ? v:exception : a:1
	if msg =~# '^Vim'
		" Delete the Vim exception string's header
		let msg = matchstr(msg, '^Vim\%(([^)]\+)\)\?\%(:E\d\+\)\?:\s*\zs.*$')
	endif

	return printf("%s\tdescription:%s", s:pluginName, msg)
endfunction " }}}
" }}}
" }}}

" Option names that need initializing.
" [TODO] If the option for shell is added, please adding this array!
function! s:generateOptionNamesList() " {{{
	let opts = [
	\	'shell', 'shellcmdflag', 'shellpipe', 'shellquote', 'shellredir',
	\	'shellslash', 'shelltemp', 'shelltype', 'shellxescape',
	\	'shellxquote'
	\ ]

	return filter(opts, 'exists("+" . v:val)')
endfunction " }}}
let s:optionNames = s:generateOptionNamesList()

function! hermitcrab#confirmShell()
	let opts = {}
	for optName in s:optionNames
		execute 'let opts["' . optName . '"] = &' . optName
	endfor
	
	return opts
endfunction

function! s:setOptions(param)
	let origin = hermitcrab#confirmShell()

	try
		" set to default
		for name in s:optionNames
			execute 'set' name . '&'
		endfor

		" overwite
		for key in keys(a:param)
			execute 'let &' . key '="' . escape(a:param[key], '\') . '"'
		endfor
	catch
		" rollback
		call s:setOptions(origin)
		throw s:raiseException()
	endtry
endfunction

function! hermitcrab#switch(arg)
	try
		let opts = (type(a:arg) == type({}))
		\	? a:arg : g:hermitcrab_shells[a:arg]
	catch /^Vim\%((\a\+)\)\=:E716/
		throw s:raiseException(a:arg . ' is not found in g:hermitcrab_shells.')
	endtry

	call s:setOptions(opts)
endfunction

function! hermitcrab#run(name, cmd)
	let originOpts = hermitcrab#confirmShell()

	try
		call hermitcrab#switch(a:name)
		execute '!' a:cmd
	finally
		call s:setOptions(originOpts)
	endtry
endfunction

function! hermitcrab#call(opt, ...)
	let originOpts = hermitcrab#confirmShell()

	try
		call hermitcrab#switch(a:opt)
		let res = eval(printf("system('%s' %s)",
		\	a:1,
		\	(a:0 > 1) ? ", '" . a:2 . "'" : ''
		\ ))
	finally
		call s:setOptions(originOpts)
	endtry

	return res
endfunction

function! hermitcrab#getCompletion(argLead, cmdline, cursorPos)
	return join(keys(g:hermitcrab_shells), '\n')
endfunction

let &cpoptions = s:cpoptions_bak
