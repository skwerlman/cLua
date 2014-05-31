Clua
====

Conditional Lua Combiner!

###What does it do?
Clua allows you to create modular CC Programs and release them as a single file.

###Why'd you make it?
I felt inspired after seeing http://www.computercraft.info/forums2/index.php?/topic/18959-ppi-pre-processor-includes/, so I decided to make a conditional compiler.

###How do I use it?
It works just like the preprocessor in C++. It scans for preprocessor directives (PPDs), and performs commands based on them. The current PPDs are:
* #INCLUDE _file_ FROM _dir_: Copies th contents of the specified file to that point in the file.
* #DEFINE _flag_: Sets _flag_ at a given point. The CLua keeps track of these flags to prevent infinite loops, so I reccommend you use them in each file.
* #IFDEF _flag_ ... #ENDIFDEF: Only copies the code between #IFDEF and ENDIFDEF if _flag_ has been set.
* #IFNDEF _flag_ ... #ENDIFNDEF: Only copies the code between #IFNDEF and #ENDIFNDEF if _flag_ has **not** been set.

###How do I install it?
Download CLua-install.lua onto the CC computer where you'd like to use CLua, and then run it.

Alternitively, you can type ```pastebin get  CLua-install.lua``` and then ```CLua-install.lua``` to install it.

The installer will ask you where you'd like it installed; I reccommend using ```/clua```, but it's really a matter of preference.

###What's next?
I plan to add a couple more PPDs over the next few days, and after that, I'm going to start working on a collection of libraries which will be included with CLua, and will be easily available.
