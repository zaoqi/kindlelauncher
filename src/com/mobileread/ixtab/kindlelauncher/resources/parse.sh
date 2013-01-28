#!/bin/ash -
# aloop.sh - last update 20130127,a,stepk
# Tested on KT 5.1.2 /bin/busybox ash (it's ash not (ba)sh!), version banner:
#   BusyBox v1.17.1 (2012-07-17 16:29:54 PDT) multi-call binary
# and on K3 /bin/busybox sh running on KT 5.1.2, version banner:
#   BusyBox v1.7.2 (2012-09-01 14:15:22 PDT) multi-call binary.
# UTF-8 support untested.

usage () {
echo "Usage: ${0##*/} [options]
  parse menu files in $EXTENSIONDIR
  system: `uname -rsnm`"
cat << 'EOT'

Options:
 -h | --help
 -c=MAX | --colors=MAX   : max cyclical index when -f=twolevel (default 0=off)
 -f=NAME | -format=NAME   : select output format, NAME is one of:
   default     default format, also when -f isn't specified, sortable
   debuginfo   dump xml_* and json_* variables
   touchrunner compatible with TouchRunner launcher, sortable
   twolevel    default + group name and color index, sortable, see also -c
 -l | --log    : enable logging to stderr
 -s | --sort   : sort output by label
 
Limitations:
. Supports json menus only
. Supports one- or two-level menus only
. A menu entry must not extend across multiple lines. Example of a valid entry:
  {"name": "a label", "priority": 3, "action" : "foo.sh", "params": "p1,p2"}
  with or without a traling comma

EOT
}

set -f # prevent pathname expansion

# dev can adjust these four variables:
PRODUCTNAME="Unified Kindle Launcher"
EXTENSIONDIR=/mnt/us/extensions
SEPARATOR=`printf "\x01"`
COLORMAX=0 # for two_level() when --colors

case " $* " in
  *" -l "* | *" --log "*)
     opt_log=1; 
     alias log='echo >&2'" ${0##*/}: " # enabled
  ;;
  *) alias log='echo >/dev/null ' # disabled
  ;;
esac
log "system `uname -rsnm`"

# knc1's magic with minimal busybox syntax:
# IFS settings used for string parsing and auto-fixing DOS line endings.
# Whitespace == :Space:Tab:Line Feed:Carriage Return:
WSP_IFS=`printf "\x20\x09\x0A\x0D"`
# No Whitespace == :Line Feed:Carriage Return:
NO_WSP=`printf "\x0A\x0D"`
# Whitespace == :Space:Tab:
WSP=`printf "\x20\x09"`
# Quote == :Double Quote:
QUOTE=`printf "\x22"`

SPACE=' '
LT='<'
GT='>'

# usage: script_full_path [-p]
script_full_path () {
  # no need to worry about symlinks are they aren't allowed in /mnt/us
  local pth=$(2>/dev/null cd "${0%/*}" >&2; pwd -P)
  [[ "-p" = "$1" ]] || pth=$pth/${0##*/}
  echo -n "$pth" 
}

# usage: result=`str_replacechars SRC CHARS CHR`
# replace all occurrences of characters of CHARS in SRC with character CHR
str_replacechars () {
  local - IFS src=$1 chars=$2 chr=$3
  set -f
  IFS="$chars"
  set -- $src
  IFS="$chr"
  echo -n "$*"
}

#BBVER=`busybox_version`
#[[ 0 = $? ]] || exit 1
#log running K$BBVER busybox binary
alias sort='/bin/busybox sort' # GNU sort needs setting LC_ALL to work the same
alias find='/bin/busybox find' # why not

# source model-specific compatibility layer. Caveat: ash forgets function
# definitions sourced from within functions, so don't
#load=`script_full_path -p`/compat-K$BBVER.sh
#. "$load"
# NOW SOURCED INLINE...########################################################
#
# compat-K3.sh - SOURCED INLINE - last update 20130127,a,stepk
# Compatibility layer for busybox ash version
#   BusyBox v1.7.2 (2012-09-01 14:15:22 PDT) multi-call binary.
#
# json_var creates sh variable json_NAME from $1
json_var () {
  local IFS=${NO_WSP} x=$*
#echo "json_var_1($#)($x)"
  x=json_${x#?}
  x=`echo -n "$x" | sed "s/${QUOTE}//; s/[${WSP}]\+:/:/; s/:[${WSP}]\+/:/; s/:/=/;"`
#echo "json_var_2 x($x)"
  eval $x
}
#
#
# sanitize and shorten labels, improve readability
sanitize() {
  local r=$*
  r=`echo -n "$r" | sed "s/[\|${SEPARATOR}]//g; s/[:;]/ /g; s/[${WSP}]+/ /;"`
  echo -n "$r"
}
###################################################################################



# json_oline parses $1, a json object consisting of key/value pairs on a single
# line, like {"id":"value",...} 
json_oline () {
  local IFS implode prev s x v line=$1
    unset implode prev s
    line=${line#[\{\[]} # ltrim { and [ - [ isn't valid json but I've seen this typo in helper/menu.json
    until [[ "$s" = "$line" ]]; do
      s=$line
      line=${s%%[${WSP}\}\],]} # rtrim
    done
    # process comma-separated list of key/value pairs
    IFS=,
    for x in $line; do
      x=${x## } # cases '"id":"v"' / '"id":"v1' / 'v2"' (last 2 for "id":"v1,v2")
#echo "X($x)"
      case "$x" in
      ${QUOTE}*)
        [[ "$implode" ]] && json_var $implode && unset implode
        [[ "$prev" ]] && json_var $prev
        prev=$x
#echo "PREV($x)"
      ;;
      *)
        implode=${implode}${implode:+,}$x
#echo "IMP($implode)"
      ;;
      esac
    done
    if [[ "$prev" -a "$implode" ]]; then
#echo "FINPREVIMP($prev,$implode)"
      json_var $prev,$implode
    elif [[ "$implode" ]]; then
#echo "FINIMP($implode)"
      json_var $implode
    elif [[ "$prev" ]]; then
#echo "FINPREV($prev)"
      json_var $prev
    fi
}

# usage: json_parse /path/to/menu.json [PROC]
# stdout: PROC's formatted menu items
# return: # of successful PROC calls
# Note: unset variables json_* before calling json_parse
# For each input line that matches "action" this function creates a set of
# sh variables named json_N1, json_N2, ... where N1, N2, etc. are json key
# names.
# And for input line that matches "name" but not "action" it creates sh
# variable json_name_ (mind the dangling underscore), which is the top level
# menu name.
# Finally it calls function PROC, which outputs a formatted combination of
# of json_* (and previously-defined) xml_* variables to stdout.
json_parse () {
  local IFS=${WSP_IFS} line menu=$1 proc=$2 count=0
  shift 2     
  while read line; do
    line=${line##[${SPC}]}
    line=${line%%[${SPC}]}
    case $line in
    *"action"*)
      IFS=${NO_WSP}
      json_oline $line
      IFS=${WSP_IFS}
      # at this point any nice json file has already entered "name" below, so
      # we can call $proc with all variables defined
      $proc $* && count=$((++count))
    ;;
    # "name" must follow "action", it's the top menu name
    *"name"*)
      IFS=${NO_WSP}
      json_oline "{${line%,}}"
      IFS=${WSP_IFS}
      json_name_=$json_name
    ;;          
    esac
done < $menu
return $count
}

# usage: xml_var /path/to/config.xml NAME [NAME ...]
# xml_var creates one or more variables xml_NAME from an extension's config.xml
# file - the file must include tag "<extension>". Example:
#  xml_var config.xml author menu => xml_author(Mad Hatter) xml_menu(menu.json)
# Note: unset variables xml_NAME before calling xml_var
# Limitations:
# . opening and closing XML tags must be on the same line
# . XML value must not include double quotes
xml_var () {
  local line xml=$1 valid=0
  shift
  while read line; do
    case $line in
    *"<extension>"*) valid=1 ;; # it's an extension's xml file
    *) for v in $*; do
         case $line in
         *${LT}$v${GT}* | *${LT}$v${SPACE}*)
           line=${line#*${LT}$v}
           line=${line#*${GT}}
           line=${line%${LT}/$v${GT}*}
           [[ 1 = $valid ]] && eval "xml_$v=\$(printf %s \"$line\")"
           break
         ;;
         esac
       done
    ;;
    esac
  done < $xml
}

# dump xml_* and json_* variables
debug_info () {
#available in genuine bash only, prints all xml_* and json_* variables
#      local v
#      echo -n "${0##*/} parsed:"
#      for v in ${!xml_*};  do echo -n " $v(${!v})"; done
#      for v in ${!json_*}; do echo -n " $v(${!v})"; done
#      echo
  
#ash: variable names are hardwired
#The following variables are available; $1 is the extension's dir fullpath
 echo -n "path($1)"
 echo -n " xml_name($xml_name) json_name_($json_name_)"
 echo -n " json_name($json_name) json_action($json_action) json_params($json_params) json_priority($json_priority)"
 echo
}

# default_output displays json_name,action' 'json_params
default_output () {
  local label=$json_name apath=$json_action group
  # fully qualify action path
  [[ -e "$1/$json_action" ]] && apath=$1/$json_action
  # top level menu name
  label=`sanitize $label`
  
  echo "$xml_name · $label$SEPARATOR$apath $json_params"
}

# touch_runner displays action,json_params,group'.'json_name (separator ';')
touch_runner () {
  local label=$json_name apath=$json_action group
  # top level menu name
  [[ "${json_name_}" ]] && group=${json_name_} || group=${xml_name}
  # qualify label
  label=`str_replacechars "$group" '.' '_'` # was ${group//.}.$label
  label=`sanitize $label`
  
  echo "$1$SEPARATOR$apath$SEPARATOR${json_params:-NULL}$SEPARATOR$label"
}

# two_level displays cindex,group,json_name,action' 'json_params
two_level () {
  local label=$json_name apath=$json_action group
  # top level menu name
  [[ "${json_name_}" ]] && group=${json_name_} || group=${xml_name}
  # fully qualify action path
  [[ -e "$1/$json_action" ]] && apath=$1/$json_action
  label=`sanitize $label`
  group=`sanitize $group`
 
  echo "$group$SEPARATOR$label$SEPARATOR$apath $json_params"
}

# prepend cyclical color index when -f=twolevel
colorize () {
  # global COLORMAX SEPARATOR
  local IFS=${NO_WSP} cindex=-1 cstate='' line group
  while read line; do
    IFS=${SEPARATOR} ; set $line ; group=$1 ; IFS=${NO_WSP}
    if [[ "$cstate" != "$group" ]]; then
      cstate=$group
      cindex=$(( ($cindex + 1) % $COLORMAX ))
    fi
    echo "$cindex$SEPARATOR$line"
  done
}

# usage loop [ignorecount]
# find and process all config.xml files and their corresponding json menu files
loop () {
local f px pj nj count=0 ignorecount=0 t
case $1 in
  ignorecount) ignorecount=1 ;;
esac
for f in $(find $EXTENSIONDIR -name config.xml); do
  unset xml_name xml_menu
  xml_var $f name menu
#echo "xml_name($xml_name) xml_menu($xml_menu)"
  [[ "$xml_menu" ]] || continue # not an extension's config.xml file
  case "${xml_menu##*.}" in
    json) ;; # ok
    *) continue ;; # don't know how to handle this menu type
  esac
  px=${f%/*} # px path to config.xml
  # pj path to json menu
  case "$xml_menu" in
    /*) pj=${xml_menu%/*}
    ;;
    *) # is relative
       pj=$px/${xml_menu}
       pj=${pj%/*}
    ;;
  esac
  nj=${xml_menu##*/} # nj json menu filename
  if [[ -f $pj/$nj ]]; then
    unset json_name json_name_ json_action json_params json_priority
    json_parse $pj/$nj $proc $pj
    count=$(( $? + $count ))
  fi
done
# when extensions dir is empty
[[ 00 = $count$ignorecount ]] && test_applet install && loop ignorecount
return 0
}

# usage" test_applet install|uninstall
# adds/removes a simple test applet in $EXTENSIONDIR
# Installing clears and recreates an existing installation of the test applet
# return: non-zero on creation error
test_applet () {
  local prnm=`str_replacechars "$PRODUCTNAME" "${WSP}" '_'`
  local dir=$EXTENSIONDIR/$prnm
  local sh="$dir/test.sh" xml="$dir/config.xml" json="$dir/menu.json"
  [[ -d "$dir" ]] && rm -f "$sh" "$xml" "$json" && rmdir "$dir"
  case "$1" in
  uninstall)
    if [[ -d "$dir" ]]; then
      echo >&2 "${0##*/}: can't uninstall test applet"
      return 1
    fi
    log "test applet uninstalled"
  ;;
  install)
    mkdir -p "$dir"
    if ! { [[ -d "$dir" ]] \
    && echo "<?xml version="1.0" encoding="UTF-8"?>
<extension>
	<information>
		<name>$PRODUCTNAME</name>
		<version>1.0</version>
		<author>stepk</author>
		<id>Test $PRODUCTNAME</id>
	</information>
	<menus>
		<menu type=\"json\">menu.json</menu>
	</menus>
</extension>" > "$xml" \
    && echo "{
\"items\": [
	{
		\"name\": \"$PRODUCTNAME\",
		\"priority\": 1,
		\"items\": [
			{\"name\": \"Test $PRODUCTNAME\", \"priority\": 0, \"action\": \"test.sh\"}
		]
	}
]
}" > "$json" \
    && echo "#/bin/sh -
exec /usr/bin/lipc-set-prop com.lab126.appmgrd start app://com.lab126.booklet.settings?diagnosticMode=\;411
" > "$sh" \
    && chmod +x "$sh" && log "test applet installed"
    }
    then
      echo >&2 "${0##*/}: can't install test applet"
      return 1
    fi
  ;;
  esac
  return 0
}

# main
main () {
# global opt_format opt_sort
local opt proc pipe t
# parse script options
# Note: both long AND short options require = to set option values
for opt in $*; do
  case $opt in
    -c=*|--colors=*) opt=${opt#*=}
       case $opt in [0-9]|[0-9][0-9]|[0-9][0-9][0-9]) COLORMAX=$(($opt)) ;; esac ;;
  	-f=*|--format=*) opt_format=${opt#*=} ;;
    -h|--help) usage; exit ;;
    -l|--log) ;; # pre-parsed near top of file
    -s|--sort) opt_sort=label ;;
    *)
      echo >&2 "${0##*/}: unknown option $opt"
      exit 1
    ;;
  esac
done

case "$opt_format" in
  touchrunner) proc=touch_runner; SEPARATOR=';' ;;
  twolevel) proc=two_level; COLORIDX=-1 ; COLORSTATE="" ;;
  debuginfo) proc=debug_info ;;
  default|'') proc=default_output ;;
  *) echo 2>&1 ${0##*/}: unknown format \"$opt_format\"; usage; exit 1 ;;
esac

pipe=loop

if [[ "$opt_sort" = label ]]; then
  case $proc in
    default_output) pipe="$pipe | sort -f -s" ;;
    touch_runner) pipe="$pipe | sort -f -t \"\$SEPARATOR\" -k 4,4 -s" ;;
    two_level) [[ 0 -lt $COLORMAX ]] && t=' | colorize' || t=''
      pipe="$pipe | sort -f -t \"\$SEPARATOR\" -k 1,1 -s$t"
       ;;
  esac
else
  case $proc in
    two_level) [[ 0 -lt $COLORMAX ]] && t=' | colorize' || t=''
      pipe="$pipe$t"
       ;;
  esac
fi

test_applet uninstall
log "$pipe"
eval $pipe
log "exit($?)"
}

main $*
