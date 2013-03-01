Installing
----------

Drop the script anywhere, make it executable, optionally edit it and change
the default value of $EXTENSIONDIR. Run it with /bin/ash.

Using
-----

PLEASE NOTE USAGE, IT'S: /bin/ash /path/to/aloop.sh [options]

# /bin/ash aloop.sh -h 
Usage: aloop.sh [options]
  parse menu files in /mnt/us/extensions:./extensions
  options may also be set in {/mnt/us/extensions:./extensions}/KUAL.cfg as
    KUAL_options="-f=twolevel -s" # (default options)
  when both KUAL_options and command-line options are present they are combined
  in this order, and if conflicts arise the last option wins.

Options: *=active when no options or just --log found in command-line or KUAL.cfg
 -h | --help
 -c=MAX | --colors=MAX   add cyclical color index in [0..MAX] when -f=twolevel
 -e=N[,ARGS] | --execmenu=N[,ARGS] exec backdoor entry N with ,-separated ARGS
*-f=NAME | -format=NAME  select output format, NAME is one of:
   default     default format, also when -f isn't specified, sortable
   debuginfo   dump xml_* and json_* variables
   touchrunner compatible with TouchRunner launcher, sortable
*  twolevel    default + group name, sortable, see also -c
 -l | --log    enable logging to stderr (ignored in $CONFIGFILE)
*-s | --sort   sort output lexicographically (ABC)
 -S | --nsort  sort output by priority (123)
 
Limitations:
. Supports json menus only
. Supports one- or two-level menus only
. A menu entry must not extend across multiple lines. Example of valid entry:
  {"name": "a label", "priority": 3, "action" : "foo.sh", "params": "p1,p2"}
  with or without a trailing comma
. Character codes > 127 can lead to unparsable menu entries
.........
Usage: aloop.sh [options]
  parse menu files in /mnt/us/extensions

Options:
 -h | --help
 -c=MAX | --colors=MAX   add cyclical color index in [0..MAX] when -f=twolevel
 -f=NAME | -format=NAME  select output format, NAME is one of:
   default     default format, also when -f isn't specified, sortable
   debuginfo   dump xml_* and json_* variables
   touchrunner compatible with TouchRunner launcher, sortable
   twolevel    default + group name, sortable, see also -c
 -l | --log    enable logging to stderr
 -s | --sort   sort output by label
 
Limitations:
. Supports json menus only
. Supports one- or two-level menus only
. A menu entry must not extend across multiple lines. Example of a valid entry:
  {"name": "a label", "priority": 3, "action" : "foo.sh", "params": "p1,p2"}
  with or without a trailing comma

Examples
--------

# 1 simple label (without top menu name) + action, unsorted
/bin/ash aloop.sh

# 2 list of parsed values
/bin/ash aloop.sh -f=debuginfo

# 3 if you use the TouchRunner launcher
/bin/ash aloop.sh -f=touchrunner -s >> /mnt/us/touchrunner/commands.txt

# 4 for two-level nested menus, like Komic's, label = menu name + item name
/bin/ash aloop.sh -f=twolevel

# 5 sort the two-level index by menu (top) level name and leave
# sub-items in the same order they appear in their json file
/bin/ash aloop.sh -f=twolevel -s

# 6 prepend a rolling 'color index' which resets to zero every N menus
/bin/ash aloop.sh -f=twolevel -s -c=3

# 7 Use -c=999 if you want a serial index from 0 to 998
/bin/ash aloop.sh -f=twolevel -s -c=999

# 8 two-level index sorted by priority (since version 20130221,a)
/bin/ash aloop.sh -f=twolevel -S

Release history
---------------

--- KT/PW/K3/DX monolithic versions below

20130221,a,stepk
+ read script options from KUAL.cfg, type aloop.sh -h for rules
  (upon config errors the script bails out sensibly)
+ option -S or --nsort sorts menu by priority (json)
+ (tada!) enter the ***KUAL menu***
  with three new spanking functions:
  . Change sort order: lexicographic (ABC), by priority (123)
  . 'Replace/Restore Store Button' (*)
    K5/PW only, tested on 5.3.2 should work on 5.1.2 also
  . Quit KUAL menu
+ expand entity &nbsp; (only) to hard space in json values
+ $EXTENSIONDIR can be a colon-separated list of directories
- fix: didn't launch action when action path included spaces
(*) KUAL menu entries appear at the end of the button list
    regardless of sort order.

20130208,a,stepk
- fix: prevent null label (Audio recorder and player for KT)
- fix: preserve '$' in labels
- fix: failed when config.xml path included spaces
! change: accept all characters in menu labels
  . ':' '|' aren't stripped anymore
  . white space runs are still squeezed to one space

20130201,a,stepk (silent update)
! test applet: changed PRODUCTNAME to "Kindle Unified Launcher"

20130130,a,stepk
! monolithic KT/PW/K3/DX compatible script (busybox level 1.7.2)
! faster on all platforms
+ allow double quotes in json values, i.e., "params":"-a \"foo bar\""
- fix: did not clear command parameters in multi-entry menus, like Helper menu
- all previous fixes up to unreleased version 20130129,a included

20130129,a,stepk (unreleased: poor performance; branched out of 20130128,a)
. todo: backport: allow double quotes in json values
! monolithic KT/PW/K3/DX compatible script (busybox level 1.7.2)
! performace improved relative to interim monolithic mod (twobob)
- fix: mangled multiword label to single word, sanitize()
- fix: missing group menu name in RoadRunner-formatted menu
- minor fix: test_applet()
- minor tweaks

20130128,a,stepk (unreleased)
. begin: allow double quotes in json values; unfinished
! monolithic KT/PW/K3/DX compatible script (busybox level 1.7.2)
- fix: mangled multiword label to single word, compat-K[35].sh sanitize()
- fix: did not compact adjacent spaces sometimes, compat-K3.sh sanitize()
- fix: missing group menu name in TouchRunner-formatted menu
- minor fix: test_applet()
- minor tweaks
= clean up interim monolithic mod (twobob)
= all previous fixes up to 20130127,b,stepk included

--- KT/PW/K3/DX modular versions below

20130127,b,stepk (unreleased)
- fix: compat-K3.sh sanitize()
- fix: compat-K5.sh sanitize()

20130127,a,stepk
! colorizing is now disabled by default use -c=MAXCOLORS to enable, i.e. -c=2
+ modular compatibility layer for K3 busybox ash! Now aloop runs on K3 too.
  K5 module ran roughly 350% faster than K3 module (real time, one sample)
+ option -l | --log
! explicit shebang ash (defensive)
- fix: test applet install loop (defensive)
* minor tweaks and fixes
* tested on K3 and K5 /bin/ash (both running on KT)

--- KT/PW only versions below ---

20130126,b,stepk
- fix: K3 ash compatibility http://www.mobileread.com/forums/showpost.php?p=2397966&postcount=160

20130125,a,stepk
+ auto fix DOS line endings
+ added $PRODUCTNAME="Unified Kindle Launcher"
+ -c=0 disables color index output
+ if no menu items found install a test applet (411)
- fix: bail out on unknown script option
+ documentation: added README-dev.txt

20130124,a,stepk
+ option -h | --help
+ option --format=debuginfo
+ options --format=twolevel and -c=|--colors=N
+ config.xml and menu.json can reside in different folders
! search extensions by config.xml (was by menu.json)
! extract group (top) menu name from json file (was from config.xml)
- silently reject invalid xml/json files
+ documented parser's limitations (corner cases)
* code factorization

20130122,c,stepk
+ options --sort and --format=touchrunner

20130122,a,stepk
= first version
