<a name="clua"></a>
cLua
====

A Conditional Lua compiler!

Currently on version: `2.0.0`

Now available through [MPT](http://www.computercraft.info/forums2/index.php?/topic/16097-mpt-minecraft-packaging-tool/)! (currently on version 2.0.0-p42; support discontinued)

<a name="table-of-contents"></a>
### Table of Contents
<!-- MarkdownTOC -->

- [cLua](#clua)
    - [Table of Contents](#table-of-contents)
    - [What does it do?](#what-does-it-do)
    - [Why'd you make it?](#whyd-you-make-it)
    - [How do I use it?](#how-do-i-use-it)
    - [When should I use it?](#when-should-i-use-it)
    - [When shouldn't I use it?](#when-shouldnt-i-use-it)
    - [How do I install it?](#how-do-i-install-it)
        - [Using pastebin](#using-pastebin)
        - [Using MPT](#using-mpt)
        - [How do I uninstall it?](#how-do-i-uninstall-it)
            - [If you installed using MPT](#if-you-installed-using-mpt)
            - [If you installed using Pastebin](#if-you-installed-using-pastebin)
        - [What's next?](#whats-next)
        - [What if there's an issue?](#what-if-theres-an-issue)
        - [Can you add...?](#can-you-add)
        - [Known bugs](#known-bugs)
        - [I'd like to submit a library...](#id-like-to-submit-a-library)
        - [Important notes!](#important-notes)
- [Changelog](#changelog)

<!-- /MarkdownTOC -->

<a name="what-does-it-do"></a>
### What does it do?
cLua allows you to create modular CC Programs and release them as a single file, without needing to copy-paste them into a release file.

<a name="whyd-you-make-it"></a>
### Why'd you make it?
I felt inspired after seeing [@SquidDev](https://github.com/squiddev/)'s [Pre-Processor Includes](http://www.computercraft.info/forums2/index.php?/topic/18959-ppi-pre-processor-includes/), so I decided to make a conditional compiler.

<a name="how-do-i-use-it"></a>
### How do I use it?
It works just like the preprocessor in C++. It scans for preprocessor directives (PPDs), and performs commands based on them.

The current PPDs are:

```
#INCLUDE file FROM dir -- Copies the contents of the specified file to that point in the file. Use `~' as a shortcut to the library folder. Use '?here' as a shortcut to the current directory. Use `?there' as a shortcut to the output directory.
#DEFINE flag -- Sets flag at a given point. cLua keeps track of these flags to prevent infinite loops, so I recommend using something like #DEFINE <filename> at the start of each file.
#IFDEF flag ... #ENDIFDEF -- Only copies the code between #IFDEF and ENDIFDEF if flag has been set.
#IFNDEF flag ... #ENDIFNDEF -- Only copies the code between #IFNDEF and #ENDIFNDEF if flag has not been set.
#IFVAR variable ... #ENDIFVAR -- Only copies the code between #IFVAR and #ENDIFVAR if variable is defined.
#IFNVAR variable ... #ENDIFNVAR -- Only copies the code between #IFNVAR and #ENDIFNVAR if variable is not defined.
#SNIPPET -- Ignores all directives until the end of the file. Use at the start of a file if you want to be able to #INCLUDE it several times.
#EXEC code -- Executes arbitrary Lua code. Should not be used to set variables.
#LICENSE license [vars] -- Adds the specified license to the .licensing file for the current file.
#SETDYNAMICVAR variable:value ... -- adds a value the the list VAR.
#DYNAMIC-INCLUDE delim1 delim2 [text] ... -- Inserts a line into the current file, replacing text between delim1 and delim2 with its value in VAR.
```


To compile a program, use the following syntax:

```
clua <input> <output> [--help] [-?] [--log] [--version] [--dry-run] [--exec:<code> ...] [--dyn:<var>=<val>[;<var>=<val>...] ...] [--define:<flag>[;<flag>...] ...] [--quiet] [--silent] [--verbose] [--devel] [--no-debug] [--no-trim] [--self-update] [--to-path:<path>] [--from-path:<path>]
--help, -? - Display this help message and exit.
--log - Enables logging.
--version - Print version info and exit.
--dry-run - Runs through the compilation, but doesn't modify the output file.
--exec:<code> - Executes arbitrary code before compilation. Use ++ instead of spaces, or include the entire option in double quotes (").
--dyn:<var>=<val>[;<var>=<val>...] - Equivelent to #DYNAMIC-INCLUDE
--define:<flag>[;<flag>...] - Equivelent to #DEFINE.
--quiet - Do not print most messages.
--silent - Only print errors.
--verbose - Prints ALL messages.
--devel - Allows logging of DEVEL level messages. Useful only for debugging. Much slower than normal, especially for large programs. Not recommended.
--no-debug - Don't log DEBUG level messages.
--self-update - Downloads and runs the latest cLua installer, then reboots.
--no-trim - Prevents the trimming of empty lines when writing the output.
--to-path:/path/ - Specifies where to output the compiled program and license.
--from-path:/path/ - Specifies where to look for the main source file.
```

Don't worry about including clua's path when you call it; the installer takes care of that for you.

<a name="when-should-i-use-it"></a>
### When should I use it?
cLua really shines in large projects where managing code becomes a hassle, because multiple independent phases of a program get forced into a single massive file.
It's also really useful when you use the same code in multiple projects; just write that code in a separate file, and `#INCLUDE` it.

<a name="when-shouldnt-i-use-it"></a>
### When shouldn't I use it?
cLua is NOT a replacement for `os.loadAPI()`. Use [PPI](http://www.computercraft.info/forums2/index.php?/topic/18959-ppi-pre-processor-includes/) for that. (Don't worry, we're compatible!)
cLua does not support more than one level of recursion. Loop detection would need way too much work to fix this, so it'll probably never change.

<a name="how-do-i-install-it"></a>
### How do I install it?
<a name="using-pastebin"></a>
#### Using pastebin
Simply type:

```
pastebin run zPMasvZ2
```

to install it.

If that doesn't work, type:

```
pastebin get zPMasvZ2 clua-inst
clua-inst
```
The installer will ask you where you'd like it installed; I recommend using `/clua`, but it's really a matter of preference.

To update, just run:
```
clua --self-update
```

<a name="using-mpt"></a>
#### Using MPT
Simply run
```
mpt ppa add skwerlman
mpt install clua
```



<a name="how-do-i-uninstall-it"></a>
### How do I uninstall it?
Step one: let me know why (assuming its an issue with the program itself). I'm always looking for feedback about the quality of programs, and knowing what people like or dislike is essential to creating a good program.
Step two: Depends on how it was installed.
<a name="if-you-installed-using-mpt"></a>
#### If you installed using MPT
Simply run:

```
mpt remove clua
mpt install clua-uninstall
mpt remove clua-uninstall
```

<a name="if-you-installed-using-pastebin"></a>
#### If you installed using Pastebin
First, delete the folder where cLua was installed.
Next, run `edit /startup`
Look through startup for the line `-- BEGIN CLUA GLOBALS`. It should be near the top.
Delete all of the lines from that one until the line `-- END CLUA GLOBALS`.


<a name="whats-next"></a>
### What's next?
I'm going to start working on a collection of libraries which will be included with cLua, and will be easily available.

My current To-Do list (in no particular order):
* Add `#ELSE` directive
* Add `#ELSEIF` directive
* Add `#ELSEIFN` directive
* Fix everything in the 'Known Bugs' section
* Update to the current CC

My top three priorities ATM (most to least important):
  1. Add `#ELSE`, `#ELSEIF`, and `#ELSEIFN`
  2. ???
  3. ???


<a name="what-if-theres-an-issue"></a>
### What if there's an issue?
If you encounter a bug, typo, or other problem with the code, create a new issue [here](https://github.com/skwerlman/Clua/issues).
If you'd like to make a suggestion, create an issue with `[suggestion]` in the title.

I coded this in CC 1.63, but with the intention of it being backwards compatible with CC 1.5. If it isn't, let me know [here](https://github.com/skwerlman/Clua/issues)!

<a name="can-you-add"></a>
### Can you add...?
Let me know in the comments.
If it's a good idea (and I can figure out how to implement it) I'll add it.
One thing will never happen, though: a GUI.

<a name="known-bugs"></a>
### Known bugs
None, at the moment. Help me find some!

<a name="id-like-to-submit-a-library"></a>
### I'd like to submit a library...
If you'd like to submit a library for inclusion in the cLua library, send me a PM with a link to the code. If it's good enough, I'll include it.

<a name="important-notes"></a>
### Important notes!
The cLua installer will inject code into the existing startup file. If there is no startup file, it will create one.
The code inserted includes several global variable definitions, and one `shell.setAlias()` command.
This code is inserted at the top of the startup file, and should have no effect on the function of rest of the startup file.
As of version 1.3.0, the injected code will look something like this:

```
-- BEGIN CLUA GLOBALS
-- FILE MODIFIED BY CLUA-INSTALL
-- cLua Copyright 2014 Skwerlman
CLUA_VERSION = '1.3.0'
CLUA_HOME = '/clua/'
CLUA = CLUA_HOME..'clua.lua'
CLUA_LIB = CLUA_HOME..'lib'
CLUA_LIB_LIST = {}
CLUA_LOG = CLUA_HOME..'clua.log'
CLUA_LUAMAN = false
shell.setAlias('clua', CLUA)
-- END CLUA GLOBALS
```

When rerunning the installer (such as when upgrading to a new version), all code between `-- BEGIN CLUA GLOBALS` and `-- END CLUA GLOBALS` will be removed from the file, and replaced with the newer info.

If you'd like to override any of these values, I recommend doing so after `-- END CLUA GLOBALS` so that the changes aren't overwritten.

cLua is [semantically versioned](http://semver.org/).

cLua is released under GPLv2. A copy of the license is available [here](LICENSE).

-----

<a name="changelog"></a>
Changelog
=========
* 2.0.0
  * BUGFIX: Nested block-type directives now behave as expected
  * BUGFIX: Line numbers are no longer distorted by block-type directives
  * BUGFIX: `EXEC` no longer crashes when reporting certain crashes
  * BUGFIX: Handles failure to open log more gracefully (more improvements to come)
  * CHANGE: `--silent` now prevents ALL output except errors
  * CHANGE: `GPLv2` now lists author in `MODULE` line
  * CHANGE: `--define` now supports multiple flags per option, separated by semicolons
  * CHANGE: because of a change in the versioning system, we've moved to version 2.0.0
  * CHANGE: `LICENSE` no longer errors when a file is given more than one license; it throws a warning instead
  * CHANGE: `DEVEL` logging is slightly less verbose
  * NEW: self testing suite added (not automatically downloaded; available on the github)
  * NEW: `--no-trim` option
  * NEW: `--dyn` option
  * NEW: `--from-path` option
  * NEW: `--to-path` option
  * NEW: Add full support for nested directives
* 1.5.0
  * BUGFIX: `EXEC`, `IFVAR`, `IFNVAR`, and `--exec` now have read-only access to certain internal functions and vars
  * BUGFIX: `EXEC`, `IFVAR`, `IFNVAR`, and `--exec` now have read-only access to `_G`
  * BUGFIX: Various typos fixed
  * BUGFIX: cLua now reports faulty environments rather than simply crashing
  * CHANGE: all code now wrapped in pcall to allow for prettier errors
  * CHANGE: libraries now call `EXEC log()` instead of `EXEC print()`
  * CHANGE: added correct licensing info to `LUABIT`
  * CHANGE: all libraries are now formatted the same way
  * CHANGE: logging output is now cleaner
  * NEW: 3 new directives
    * `#SETDYNAMICVAR`
    * `#DYNAMIC-INCLUDE`
    * `#LICENSE`
  * NEW: 1 new library
    * `RANDOM`
  * NEW: 3 new licenses
    * `GPLv3`
    * `MIT`
    * `UNKNOWN` -- used when I don't know which license to use
  * NEW: cLua now generates a `.licensing` file during compilation
* 1.4.0
  * BUGFIX: `IFVAR` and `IFNVAR` now actually receive the correct input
  * BUGFIX: `IFDEF`, `IFNDEF`, `IFVAR`, and `IFNVAR` now always find the end of their block
  * BUGFIX: cLua now handles invalid source files gracefully
  * BUGFIX: more efficient option parsing
  * BUGFIX: updater now skips asking where to install if it detects a current install
  * CHANGE: timer now measures in ticks and seconds instead of delta gametime
  * CHANGE: better timer formatting
  * CHANGE: better overall formatting
  * CHANGE: all libraries now have credit headers
  * CHANGE: usage info is now displayed using `textutils.pagedPrint()`
  * NEW: adjustable logging
  * NEW: 10 new command line options
    * `--help`
    * `-?`
    * `--version`
    * `--dry-run`
    * `--quiet`
    * `--silent`
    * `--verbose`
    * `--devel`
    * `--no-debug`
    * `--self-update`
  * NEW: 2 new libraries
    * `JSON`
    * `SPLASH`
* 1.3.0
  * BUGFIX: Fixed a crash caused by the `--exec` option
  * BUGFIX: When a crash occurs during option parsing but after logging is enabled, it now creates a new log file
  * CHANGE: Logging now supports multiline strings
  * CHANGE: Various minor logging changes
  * NEW: Add `#EXEC` directive
  * NEW: Add `#IFVAR` directive
  * NEW: Add `#IFNVAR` directive
  * NEW: Add `#ENDIFVAR` directive
  * NEW: Add `#ENDIFNVAR` directive
  * NEW: Errors in the `--exec` option now reference the specific option that caused the issue
* 1.2.0
  * NEW: Add command line args
    * `--log` - Enables logging
    * `--exec:<code>` - Executes arbitrary code before compilation
    * `--define:<flag>` - Equivalent to `#DEFINE`
  * NEW: Add two libraries to pastebin version (they were already in MPT version):
    * `CRC32` - A high-speed hashing API
    * `LUABIT` - A bitwise API capable of handling 32-bit integers
  * NEW: Add compilation timing
* 1.1.1
  * BUGFIX: Line numbers in logs (should) now reference the line in the source instead of their source table key.
  * BUGFIX: `#SNIPPET` no longer claims to ignore itself
  * CHANGE: fixed a typo ('beacause' ==> 'because')
  * CHANGE: significantly less console spam (no effect on logging verbosity)
  * CHANGE: `#ELSE`, `#ELSEIF`, and `#ELSEIFN` now have their own error messages, since the main loop should never encounter them
  * NEW: enabled `FROM` shortcut. Use as `#INCLUDE library FROM ~` to load a standard library. Standard libraries are currently only available through MPT.
  * MPT Version Only:
    * BUGFIX: no longer crashes under X System (we're now injecting into the kernel instead of startup; I'm working on re-enabling the alias)
    * NEW: now includes two libraries
* 1.1.0
  * BUGFIX: `#IFDEF` and `#IFNDEF` no longer destroy the line after their closing directive
  * CHANGE: minor directive recognition optimization
  * CHANGE: minor `#IFDEF` and `#IFNDEF` optimization
  * CHANGE: file trimming is now ~2x faster (I merged two loops)
  * CHANGE: better logging
  * NEW: Set `CLUA_LIB` global and create `/<clua-root>/lib` folder (prep for library support)
  * NEW: add `#SNIPPET` directive
  * NEW: don't error on `#ELSE`, `#ELSEIF`, `#ELSEIFN` (Planned directives)
  * NEW: strip trailing whitespace (may prevent issues with newer directive recognition)
* 1.0.0
  * Initial public release
