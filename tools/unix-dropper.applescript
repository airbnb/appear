#!/usr/bin/env osascript
(*
 * script: unix-dropper.applescript
 * author: Jake Teton-Landis <just.1.jake@gmail.com>
 * date:   2016-08-30
 *
 * when saved as an application (open in Script Editor, then choose
 * File->Export...), this script can be used to process files or folders with a
 * Unix script via drag-and-drop.
 *
 * You can customize the preferences of your Unix script by opening the
 * application the regular way.
 *
 * Your script will be called as a sh function, so you can process $@ using
 * `shift` or something.
 *
 * Heplful documentation for maintainers:
 *   Technical Note TN2065 - do shell script in AppleScript
 *   https://developer.apple.com/library/mac/technotes/tn2065/_index.html
 *
 * Here's the default script that this app will run, creaetd from the default
 * property `user_unix_command`, defined below, as though the dropped files were
 * "first", "second", "third".
 *
 * ```sh
 * #!/bin/sh
 * script-wrapper () {
 * ARG_C='3'
 * ARG_1='first'
 * ARG_2='second'
 * ARG_3='third'
 * say "dropped $ARG_C files. first file: $ARG_0"
 * }
 * # we do this so you can use "$@"
 * # and unix conventions if you're unix-y
 * script-wrapper first second third
 * ```
 *)

property default_command : "say \"dropped $ARG_C files. first file: $ARG_0\""

--- this is a stored user preference.
--- this is the default, but it can be set as a preference in a .plist if this script is saved as an applicication
property user_unix_command : default_command

--- this function runs when the user opens the application by double-clicking it.
--- uer can adjust the user_unix_command by opening the application
on run
	set quit_ to "Quit"
	set reset to "Reset"
	set save_ to "Save"
	repeat
		set ds to doc_string()
		set d_res to display dialog ds buttons {quit_, reset, save_} default button save_ default answer user_unix_command
		if the button returned of d_res is save_ then
			set user_unix_command to the text returned of the result
		end if
		if the button returned of d_res is quit_ then
			return "user quit"
		end if
	end repeat
end run

-- This droplet processes files dropped onto the applet
on open these_items
	set as_strings to {}
	repeat with cur in these_items
		set cur_as_string to (POSIX path of cur) as string
		copy cur_as_string to end of as_strings
	end repeat
	set the_command to unix_script(user_unix_command, as_strings)
	log the_command
	do shell script the_command
end open

--- here's how we end up building the shell script to call
--- the user's shell script with hella sweet args
on build_arg_vars(args)
	set argc to the count of args
	set res to {set_env_var("ARG_C", argc)}

	repeat with i from 1 to the count of args
		set arg to item i of args
		copy set_env_var("ARG_" & i, arg) to end of res
	end repeat
	res
end build_arg_vars

on build_script(user_script, args)
	set fn_name to "wrapper_fn"
	set open_fn to fn_name & " () {"
	set close_fn to "}"
	set call_fn to fn_name & " " & join_list(args, " ")
	set comment to "# we do this so you can use \"$@\"
# and unix conventions if you're unix-y"

	set res to build_arg_vars(args)

	copy open_fn to beginning of res
	copy user_script to end of res
	copy close_fn to end of res
	copy comment to end of res
	copy call_fn to end of res
	res
end build_script

on set_env_var(var, value)

	set res to var & "=" & (the quoted form of ("" & value))
	# display dialog res

	return res

end set_env_var

on join_list(the_list, sep)
	if (count of the_list) is 0 then
		return ""
	end if

	if (count of the_list) is 1 then
		return "" & item 1 of the_list
	end if

	set res to "" & item 1 of the_list

	repeat with i from 2 to the count of the_list
		set el to item i of the_list
		set res to res & sep & el
	end repeat
	res
end join_list

on unix_script(user_command, args)
	join_list(build_script(user_command, args), "
")
end unix_script


-- returns string
on doc_string()
	"Enter a unix command to run when this application should open a file. Your script has several environment variables availible, see below.

Substitutions availible:
\"$@\":  All arguments, quoted
(all sh default environment variables)
$ARG_C:  Total number of arguments
$ARG_1:  First argument
$ARG_2:  Second argument
etc...

Current command:
`" & user_unix_command & "`

Final script, given dropped files {first, second, third}:
```sh
#!/bin/sh
" & unix_script(user_unix_command, {"first", "second", "third"}) & "
```"
end doc_string

--- uncomment to test
-- unix_script("/Users/jake/src/foo $1 a/b $ARG_4 -- \"$@\"", {"foo", "bar"})
