scriptencoding utf-8
" This test uses [vimtest](https://github.com/kannokanno/vimtest) test
" framework plugin.
" This test not support the "auto source" feature (see
" ":help vimtest-auto-source") because this tesst code is a small.
" Please manual re-":source"-ing.
"
" Run tests
" 	:VimTest

let s:isWin = has('win64') || has('win32') || has('win16') || has('win95')
let s:isDos = has('dos32') || has('dos16')

" Some options are environment dependeny.
" [WARNING] Dependent the environment (OS etc.).
" [WARNING] If tests are completly succeeded on the one environment,
" [WARNING] but other environments possibly failed tests .
let s:shellOptionNames = [
\	'shell', 'shellcmdflag', 'shellquote', 'shellredir',
\	'shelltemp', 'shellxquote'
\ ]
if has('quickfix')
	call add(s:shellOptionNames, 'shellpipe')
endif
if s:isWin || s:isDos || has('os2')
	call add(s:shellOptionNames, 'shellslash')
endif
if has('amiga')
	call add(s:shellOptionNames, 'shelltype')
endif

" Print optional description when failing test.
" Please substitute this function's reference to an assert object of
" a vimtest object at setup.
function! s:vimtest_assertEquals_M(expected, actual, failureDesc) dict " {{{
	try
		if a:expected == a:actual
			call self.equals(a:expected, a:actual)
		else
			throw 'diff'
		endif
	catch /^diff$/
		call self.fail(printf('%s: %s != %s',
		\	a:failureDesc, string(a:expected), string(a:actual)))
	endtry
endfunction " }}}

function! s:refugeVariables(suite)
	let a:suite._refuges = {
	\	'g:hermitcrab_options': deepcopy(g:hermitcrab_options)
	\ }

	for name in s:shellOptionNames
		call extend(a:suite._refuges, { name : eval('&' . name) })
	endfor
endfunction
function! s:repairVariables(suite)
	let g:hermitcrab_options = a:suite._refuges['g:hermitcrab_options']
	
	for name in s:shellOptionNames
		execute 'let &' . name . '= a:suite._refuges["' . name . '"]'
	endfor
endfunction

function! s:getShellOptions() " {{{
	let options = {}
	for name in s:shellOptionNames
		let options[name] = eval('&'.name)
	endfor
	return options
endfunction " }}}

function! s:generateDummyOptions(shelltype, shellslash, shelltemp) " {{{
	let opts = {
	\	'shell': 'DUMMY',
	\	'shellcmdflag': 'DUMMYCMDFLAG',
	\	'shellquote': 'DUMMYQUOTE',
	\	'shellredir': 'DUMMYREDIR',
	\	'shelltemp': a:shelltemp,
	\	'shellxquote': 'DUMMYXQUOTE'
	\ }
	if has('quickfix')
		call extend(opts, {'shellpipe': 'DUMMYPIPE'})
	endif
	if s:isWin || s:isDos || has('os2')
		call extend(opts, {'shellslash': a:shellslash})
	endif
	if has('amiga')
		call extend(opts, {'shelltype': a:shelltype})
	endif
	return opts
endfunction " }}}

function! s:setDummyOption(name) " {{{
	let origin = g:hermitcrab_options
	let g:hermitcrab_options = extend(
	\	g:hermitcrab_options,
	\	{ a:name : s:generateDummyOptions(
	\		!&shelltype, !&shellslash, !&shelltemp) }
	\ )
	return origin
endfunction " }}}

let s:suite = vimtest#new('Always containe same value as the option of the Vim.') " {{{
function! s:suite.startup()
	call extend(self.assert, {'equals_M': function('s:vimtest_assertEquals_M')})
endfunction
function! s:suite.setup()
	call s:refugeVariables(self)
endfunction
function! s:suite.teardown()
	call s:repairVariables(self)
endfunction

function! s:suite.test_defaultVariableValues()
	let expected = s:getShellOptions()
	let existsSame = 0
	for key in keys(g:hermitcrab_options)
		if g:hermitcrab_options[key] == expected
			call self.assert.equals_M(
			\	g:hermitcrab_options[key], expected, key . ' is different')
			return
		endif
	endfor

"	call self.assert.true(existsSame)
	call self.assert.fail(
	\	"Default setting is not found:\n"
	\	. "\tsearched: " . string(expected) . "\n"
	\	. "\tg:hermitcrab_options: " . string(g:hermitcrab_options))
endfunction
" }}}

let s:suite = vimtest#new('Tests for :HermitCrabSwitch') " {{{
function! s:suite.setup()
	call s:refugeVariables(self)
	call s:setDummyOption('DUMMY')
endfunction
function! s:suite.teardown()
	call s:repairVariables(self)
endfunction

function! s:suite.test_HermitCrabSwitch_switchToExists()
	let defaultOption = g:hermitcrab_options[
	\	filter(keys(g:hermitcrab_options), "v:val != 'DUMMY'")[0]
	\ ]

	HermitCrabSwitch DUMMY

	let actualOptions = s:getShellOptions()

	call self.assert.equals(g:hermitcrab_options['DUMMY'], actualOptions)
endfunction

function! s:suite.test_HermitCrabSwitch_switchToNotExists()
	let origin = s:getShellOptions()
	
	"call self.assert.throw("hermitcrab.vim\tdescription:DUMMY is not found in g:hermitcrab_options.")
	let raisedException = 0
	try
		HermitCrabSwitch NOTHING
	catch
		let raisedException = 1
		call self.assert.equals(v:exception, "hermitcrab.vim\tdescription:NOTHING is not found in g:hermitcrab_options.")
	finally
		call self.assert.true(raisedException)
	endtry

	call self.assert.equals(origin, s:getShellOptions())
endfunction

function! s:suite.test_HermitCrabSwitch_noArgument()
	let origin = s:getShellOptions()

	call self.assert.throw('E471')

	HermitCrabSwitch

	call self.assert.equals(origin, s:getShellOptions())
endfunction
" }}}

let s:suite = vimtest#new(':HermitCrabSwitchRun command') " {{{
function! s:suite.setup()
	call s:refugeVariables(self)
	call s:setDummyOption('DUMMY')
endfunction
function! s:suite.teardown()
	call s:repairVariables(self)
endfunction

function! s:suite.test_HermitCrabRun_shellOptionsIsNotChange()
	let defaultOption = s:getShellOptions()
	let currentDirectoryPath = expand('<sfile>:p:h')
	lcd <sfile>:p:h

	HermitCrabRun DUMMY vim --version

	let actualOptions = s:getShellOptions()

	call self.assert.equals(defaultOption, actualOptions)

	execute 'lcd' currentDirectoryPath
endfunction

function! s:suite.test_HermitCrabRun_callNotExistsCommand()
	let name = keys(g:hermitcrab_options)[0]
	" When run a NON EXISTS command, HermitCrabRun is NOT raised an error.
	" This behavior is modeled on :! .
	execute 'HermitCrabRun ' . name . ' notexistscommand'
endfunction
" [FIXME][TODO] Test :HermitCrabSwitchRun. How?
" }}}

" Omitted tests for hermitcrab#switch(). These tests is same for :HermitCrabSwitch.
"
" Omitted tests for hermitcrab#run(). These tests is same for :HermitCrabSwitch.

let s:suite = vimtest#new('Test for hermitcrab#getShellOptions()') " {{{
function! s:suite.setup()
	call s:refugeVariables(self)
	call s:setDummyOption('DUMMY')
endfunction
function! s:suite.teardown()
	call s:repairVariables(self)
endfunction

function! s:suite.test_hermitcrab_getShellOptions()
	call self.assert.equals(
	\	hermitcrab#getShellOptions(), s:getShellOptions())

	HermitCrabSwitch DUMMY

	call self.assert.equals(
	\	hermitcrab#getShellOptions(), s:getShellOptions())
endfunction
" }}}

let s:suite = vimtest#new('Test for hermitcrab#setOptions')	" {{{
function! s:suite.startup()
	call extend(self.assert, {'equals_M': function('s:vimtest_assertEquals_M')})
endfunction
function! s:suite.setup()
	call s:refugeVariables(self)
endfunction
function! s:suite.teardown()
	call s:repairVariables(self)
endfunction

function! s:suite.test_hermitcrab_setOptions_setAll()
	let dummyOptions = s:generateDummyOptions(
	\	!&shelltype, !&shellslash, !&shelltemp)

	call hermitcrab#setOptions(dummyOptions)

	for name in s:shellOptionNames
		call self.assert.equals_M(eval('&' . name), dummyOptions[name],
		\	'Failed asserting &' . name)
	endfor
endfunction

function! s:suite.test_hermitcrab_setOptions_NotSet()
	" Omitted options' values is used the Vim default value.
	
	let vimDefault = {}
	for name in s:shellOptionNames
		" Get the Vim default values.
		execute 'let currentValue = &' . name
		execute 'set' name . '&'
		execute 'let vimDefault["' . name . '"] = &' . name
		execute 'let &' . name '= currentValue'
	endfor

	call hermitcrab#setOptions({})

	call self.assert.equals(s:getShellOptions(), vimDefault)
endfunction

function! s:suite.test_hermitcrab_setOptions_setFailureValue()
	let origLang = v:lang
	let origin = s:getShellOptions()
	let expected = {}
	for name in s:shellOptionNames
		" The dictionary can not cast to the string.
		let expected[name] = {}
	endfor

	language messages C

	" Now, vimtest cannot asserts after exception assertion...
	"" Maybe 'using' is typo by ver7.3.46
	"call self.assert.throw("hermitcrab.vim\tdescription:using Dictionary as a String")
	"call hermitcrab#setOptions(expected)
	let raisedException = 0
	try
		call hermitcrab#setOptions(expected)
	catch
		let raisedException = 1
		" Maybe 'using' is a typo by Vim ver7.3.46
		call self.assert.equals(v:exception, "hermitcrab.vim\tdescription:using Dictionary as a String")
	finally
		call self.assert.true(raisedException)
	endtry

	call self.assert.equals(s:getShellOptions(), origin)

	execute 'language messages' origLang
endfunction
" }}}

let s:suite = vimtest#new('Tests for hermitcrab#getCompletion()')	" {{{
function! s:suite.test_hermitcrab_getCompletion()
	let names = []
	for name in keys(g:hermitcrab_options)
		call add(names, name)
	endfor
	let expected = join(names, '\n')

	call self.assert.equals(hermitcrab#getCompletion('','',0), expected)
	" [TODO] Exclude multiple argument complition (like :edit).

	" hermitcrab#getCompletion() is a "custom" completion function. Leave
	" filtering to the Vim.
endfunction
" }}}
