scriptencoding utf-8
" This test uses [vimtest](https://github.com/kannokanno/vimtest) test
" framework plugin.
" This test not support the "auto source" feature (see
" ":help vimtest-auto-source") because this tesst code is a small.
" Please manual re-":source"-ing.
"
" Run tests
" 	:VimTest

" Generate UID value.
function! s:generateUID() " {{{
	let s:uid = exists('s:uid') ? s:uid + 1 : 0
	return string(s:uid)
endfunction " }}}

function! s:initValues() " {{{
	" Some options are environment dependeny.
	" [WARNING] Dependent the environment (OS etc.).
	" [WARNING] If tests are completly succeeded on the one environment,
	" [WARNING] but other environments possibly failed tests .
	" [TODO] If the option for shell is added, please adding this array!
	let s:shellOptions = [
	\	{ 'name': 'shell',        'type': type('') },
	\	{ 'name': 'shellcmdflag', 'type': type('') },
	\	{ 'name': 'shellpipe',    'type': type('') },
	\	{ 'name': 'shellslash',   'type': type(1) },
	\	{ 'name': 'shelltype',    'type': type(1) },
	\	{ 'name': 'shellquote',   'type': type('') },
	\	{ 'name': 'shellredir',   'type': type('') },
	\	{ 'name': 'shelltemp',    'type': type(1) },
	\	{ 'name': 'shellxescape', 'type': type('') },
	\	{ 'name': 'shellxquote',  'type': type('') }
	\ ]
	let s:shellOptions = filter(s:shellOptions, 'exists("+" . v:val["name"])')
endfunction " }}}

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

" Compare the file and text assertion.
function! s:vimtest_assertCompareToFile(expectedFilePath, actual) dict " {{{
	call self.equals(
	\	join(readfile(a:expectedFilePath)),
	\	a:actual
	\ )
endfunction " }}}

function! s:refugeVariables(suite)
	let a:suite._refuges = {
	\	'g:hermitcrab_shells': deepcopy(g:hermitcrab_shells)
	\ }

	let a:suite._refuges.shellopts = {}
	for opt in s:shellOptions
		call extend(a:suite._refuges.shellopts, { opt['name'] : eval('&' . opt['name']) })
	endfor
endfunction
function! s:repairVariables(suite)
	let g:hermitcrab_shells = a:suite._refuges['g:hermitcrab_shells']
	
	for name in keys(a:suite._refuges.shellopts)
		execute printf('let &%s="%s"', name, escape(a:suite._refuges.shellopts[name], '"\'))
	endfor
endfunction

function! s:getShellOptions() " {{{
	let options = {}
	for opt in s:shellOptions
		let options[opt['name']] = eval('&' . opt['name'])
	endfor
	return options
endfunction " }}}

function! s:getDefaultShellOptions()
	let options = {}
	for opt in s:shellOptions
		let name = opt['name']
		let currentValue = eval('&' . name)
		execute 'set' name . '&'
		let options[name] = eval('&' . opt['name'])
		execute 'let &' . name ' = currentValue'
	endfor
	return options
endfunction

function! s:generateDummyOptions(shelltype, shellslash, shelltemp) " {{{
	let res = {}
	for opt in s:shellOptions
		let name = opt['name']
		if match(name, '^shell\(type\|slash\|temp\)$') != -1
			let res[name] = eval('a:' . name)
		elseif opt['type'] == type('')
			let res[name] = 'dummy-' . name
		else
			throw "NOT IMPLEMENTED."
		endif
	endfor
	return res
endfunction " }}}

function! s:setDummyOption(name) " {{{
	let origin = deepcopy(g:hermitcrab_shells)
	let dummy = s:generateDummyOptions(!&shelltype, !&shellslash, !&shelltemp)
	call extend(g:hermitcrab_shells, {a:name : dummy})
	return origin
endfunction " }}}

let s:suite = vimtest#new('Always containe same value as the option of the Vim.') " {{{
function! s:suite.startup()
	call s:initValues()
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
	for key in keys(g:hermitcrab_shells)
		if g:hermitcrab_shells[key] == expected
			call self.assert.equals_M(
			\	g:hermitcrab_shells[key], expected, key . ' is different')
			return
		endif
	endfor

	call self.assert.fail(
	\	"Default setting is not found:\n"
	\	. "\tsearched: " . string(expected) . "\n"
	\	. "\tg:hermitcrab_shells: " . string(g:hermitcrab_shells))
endfunction
" }}}

let s:suite = vimtest#new('Tests for :HermitCrabSwitch') " {{{
function! s:suite.startup()
	call s:initValues()
endfunction
function! s:suite.setup()
	call s:refugeVariables(self)
	call s:setDummyOption('DUMMY')
endfunction
function! s:suite.teardown()
	call s:repairVariables(self)
endfunction

function! s:suite.test_HermitCrabSwitch_switchoExistsName()
	let defaultOption = g:hermitcrab_shells[
	\	keys(g:hermitcrab_shells)[0]
	\ ]

	HermitCrabSwitch DUMMY

	let actualOptions = s:getShellOptions()

	call self.assert.equals(g:hermitcrab_shells['DUMMY'], actualOptions)
endfunction

function! s:suite.test_HermitCrabSwitch_switchToNotExistsName()
	let origin = s:getShellOptions()
	
	"call self.assert.throw("hermitcrab.vim\tdescription:DUMMY is not found in g:hermitcrab_shells.")
	let raisedException = 0
	try
		HermitCrabSwitch NOTHING
	catch
		let raisedException = 1
		call self.assert.equals(v:exception, "hermitcrab.vim\tdescription:NOTHING is not found in g:hermitcrab_shells.")
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
function! s:suite.startup()
	call s:initValues()
endfunction
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
	let name = keys(g:hermitcrab_shells)[0]
	" When run a NON EXISTS command, HermitCrabRun is NOT raised an error.
	" This behavior is modeled on :! .
	execute 'HermitCrabRun ' . name . ' notexistscommand'
endfunction
" [FIXME][TODO] Test :HermitCrabSwitchRun. How?
" }}}

let s:suite = vimtest#new('Test for hermitcrab#switch()') " {{{
function! s:suite.startup()
	call s:initValues()
endfunction
function! s:suite.setup()
	call s:refugeVariables(self)
endfunction
function! s:suite.teardown()
	call s:repairVariables(self)
endfunction

" Omitted some tests for hermitcrab#switch(). These tests is same for :HermitCrabSwitch.
function! s:suite.test_hermitcrab_switch_useDictionary()
	let opts = s:generateDummyOptions(!&shelltype, !&shellslash, !&shelltemp)

	call hermitcrab#switch(opts)

	call self.assert.equals(s:getShellOptions(), opts)
endfunction

function! s:suite.test_hermitCrab_switch_useEmptyDictionary()
	" Omitted option's values is used the Vim default value.

	let vimDefault = s:getDefaultShellOptions()
"	let vimDefault = {}
"	for opt in s:shellOptions
"		let name = opt['name']
"		" Get the Vim default values.
"		execute 'let currentValue = &' . name
"		execute 'set' name . '&'
"		execute 'let vimDefault["' . name . '"] = &' . name
"		execute 'let &' . name '= currentValue'
"	endfor

	call hermitcrab#switch({})

	call self.assert.equals(s:getShellOptions(), vimDefault)
endfunction
function! s:suite.test_hermitcrab_switch_setFailureValue()
	let origLang = v:lang
	let origin = s:getShellOptions()
	let expected = {}
	for opt in s:shellOptions
		" The dictionary can not cast to the string.
		let expected[opt['name']] = {}
	endfor

	language messages C

	" Now, vimtest cannot asserts after exception assertion...
	"" Maybe 'using' is typo by ver7.3.46
	"call self.assert.throw("hermitcrab.vim\tdescription:using Dictionary as a String")
	"call hermitcrab#setOptions(expected)
	let raisedException = 0
	try
		call hermitcrab#switch(expected)
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

" Omitted tests for hermitcrab#run(). These tests is same for :HermitCrabSwitch.
let s:suite = vimtest#new('Test for hermitcrab#run()') " {{{
function! s:suite.setup()
	call s:refugeVariables(self)
endfunction
function! s:suite.teardown()
	call s:repairVariables(self)
endfunction

function! s:suite.test_hermitcrab_run_useDictionary()
	let options = s:getShellOptions()

	call hermitcrab#run(
	\	s:generateDummyOptions(!&shelltype, !&shellslash, !&shelltemp),
	\	'vim --version')

	call self.assert.equals(s:getShellOptions(), options)
endfunction

function! s:suite.test_hermitcrab_run_setFailureValue()
	let origLang = v:lang
	let origin = s:getShellOptions()
	let expected = {}
	for opt in s:shellOptions
		" The dictionary can not cast to the string.
		let expected[opt['name']] = {}
	endfor

	language messages C

	" Now, vimtest cannot asserts after exception assertion...
	"" Maybe 'using' is typo by ver7.3.46
	"call self.assert.throw("hermitcrab.vim\tdescription:using Dictionary as a String")
	"call hermitcrab#setOptions(expected)
	let raisedException = 0
	try
		call hermitcrab#run(expected, 'vim --version')
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

let s:suite = vimtest#new('Test for hermitcrab#call()') " {{{
function! s:suite.setup()
	call s:refugeVariables(self)
	let self._command = 'vim --version'
	let self._tmpFileName = tempname()
	let self._commandWithStdin
	\	= printf('vim -u NONE -U NONE -i NONE -c "wq! %s" -',
	\		escape(self._tmpFileName, ' '))
	let self.assert.compareToFile
	\	= function('s:vimtest_assertCompareToFile')
endfunction
function! s:suite.teardown()
	call s:repairVariables(self)
	call delete(self._tmpFileName)
endfunction

" [TODO] hermitcrab#call()'s 3rd argument's test; How do I test it at
" [TODO] environment independent?

function! s:suite.test_hermitcrab_call_useName()
	let origOpts = s:getShellOptions()
	let nowShellName = matchstr(&shell, '\(/\|\\\)\zs[^/\\]\+$')
	call s:setDummyOption('DUMMY')

	" use exists
	let expected = system(self._command)
	let actual   = hermitcrab#call(nowShellName, self._command)
	call self.assert.equals(expected, actual)
	call self.assert.equals(0, v:shell_error)

	" use non-exists
	let raisedError = 0
	try
		let res = hermitcrab#call('DUMMY', self._command)
	catch " Raised error when using non-exists shell.
		let raisedError = 1
	endtry
	if !raisedError
		call self.assert.fail('Not raised error.')
	endif
	call self.assert.equals(origOpts, s:getShellOptions())

	" use 3 arguments.
	" Assertion failed? When you use the Sandbox on your system, please
	" tern off it, and retry!
	let actual = s:generateUID()
	call hermitcrab#call(nowShellName, self._commandWithStdin, actual)
	call self.assert.compareToFile(self._tmpFileName, actual)
	call self.assert.equals(0, v:shell_error)
endfunction

function! s:suite.test_hermitcrab_call_useDictionary()
	let origin = s:getShellOptions()

	" use valid (default) options
	let expected = system(self._command)
	let actual = hermitcrab#call(origin, self._command)
	call self.assert.equals(0, v:shell_error)
	call self.assert.equals(expected, actual)

	" use invalid options
	let raisedError = 0
	let opts = s:generateDummyOptions(
	\	!&shelltype, !&shellslash, !&shelltemp)
	try
		let res = hermitcrab#call(opts, self._command)
	catch
		let raisedError = 1
	endtry
	if !raisedError
		call self.assert.failed('Not raised error.')
	endif
	call self.assert.equals(origin, s:getShellOptions())

	" use 3 arguments.
	" Assertion failed? When you use the Sandbox on your system, please
	" tern off it, and retry!
	let actual = s:generateUID()
	call hermitcrab#call(origin, self._commandWithStdin, actual)
	call self.assert.compareToFile(self._tmpFileName, actual)
	call self.assert.equals(0, v:shell_error)
endfunction
" }}}

let s:suite = vimtest#new('Test for hermitcrab#confirmShell()') " {{{
function! s:suite.startup()
	call s:initValues()
endfunction
function! s:suite.setup()
	call s:refugeVariables(self)
	call s:setDummyOption('DUMMY')
endfunction
function! s:suite.teardown()
	call s:repairVariables(self)
endfunction

function! s:suite.test_hermitcrab_confirmShell()
	call self.assert.equals(
	\	hermitcrab#confirmShell(), s:getShellOptions())

	HermitCrabSwitch DUMMY

	call self.assert.equals(
	\	hermitcrab#confirmShell(), s:getShellOptions())
endfunction
" }}}

let s:suite = vimtest#new('Tests for hermitcrab#getCompletion()')	" {{{
function! s:suite.startup()
	call s:initValues()
endfunction
function! s:suite.test_hermitcrab_getCompletion()
	let names = []
	for name in keys(g:hermitcrab_shells)
		call add(names, name)
	endfor
	let expected = join(names, "\n")

	call self.assert.equals(hermitcrab#getCompletion('','',0), expected)
	" [TODO] Exclude multiple argument complition (like :edit).

	" hermitcrab#getCompletion() is a "custom" completion function. Leave
	" filtering to the Vim.
endfunction
" }}}
