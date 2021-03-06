{execSync, exec} = require 'child_process'
{writeFile, unlink} = require 'fs'
SubAtom = require 'sub-atom'

module.exports =
	#os: process.platform
	#timeout:
		#timeout: 10000
		#killSignal: 'SIGKILL'

	project: atom.project.getDirectories()[0]
	tmp: '/tmp/GitKraken.json'

	id: 'com.axosoft.GitKraken'
	selector: '[class^=status-bar] .git-branch'

	subs: new SubAtom
#-------------------------------------------------------------------------------
	activate: ->

		@subs.add atom.commands.add 'atom-workspace',
			'gitkraken:release': => @open @project

		@subs.add atom.packages.onDidActivateInitialPackages =>
			@subs.add 'status-bar','click', @selector, ({altKey, shiftKey}) =>
				@open @project if altKey or shiftKey

#-------------------------------------------------------------------------------
	open: ({path}) ->
		if atom.config.get 'gitkraken.singleInstance'
			@execGitKrakenSingle path
		else
			projects = @execGitKrakenMulti path

			window.addEventListener 'beforeunload', ->
				exec "kill #{projects[path]}"

#-------------------------------------------------------------------------------
	deactivate: ->
		@subs.dispose()
		window.removeEventListener 'beforeunload'
		unlink @tmp

#-------------------------------------------------------------------------------
	execGitKrakenSingle: (path) ->
		if process.platform == 'darwin'
			exec "pkill GitKraken; sleep .1 && open -Fb #{@id} --args -p '#{path}'" #, @timeout
		else if process.platform == 'linux'
			exec "killall gitkraken; sleep .1 && gitkraken --args -p '#{path}' &> /dev/null &"

#-------------------------------------------------------------------------------
	execGitKrakenMulti: (path) ->
		projects = {}
		try
			projects = require @tmp
			if process.platform == 'darwin'
				execSync "ps #{projects[path]} | grep -q GitKraken && open -b #{@id} --args -p '#{path}'"
			else if process.platform == 'linux'
				execSync "ps #{projects[path]} | grep -q gitkraken"
		catch
			if process.platform == 'darwin'
				pid = execSync "open -nb #{@id} --args -p '#{path}' & echo $!"
			else if process.platform == 'linux'
				proc = exec "nohup gitkraken --args -p '#{path}' &>/dev/null &"
				pid = proc.pid

			projects[path] = (parseInt pid) + 1
			writeFile @tmp, JSON.stringify projects

		projects
