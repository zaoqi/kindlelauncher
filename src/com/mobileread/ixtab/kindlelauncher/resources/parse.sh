#!/bin/ash -
# aloop.sh - version 20130208,a,stepk
# a.k.a. parse.sh in KUAL git
# Tested on KT 5.1.2 /bin/busybox ash (it's ash not (ba)sh!), version banner:
#   BusyBox v1.17.1 (2012-07-17 16:29:54 PDT) multi-call binary
# and on K3 /bin/busybox sh running on KT 5.1.2, version banner:
#   BusyBox v1.7.2 (2012-09-01 14:15:22 PDT) multi-call binary.
# UTF-8 support untested.

usage () {
echo "Usage: ${0##*/} [options]
  parse menu files in $EXTENSIONDIR"
cat << 'EOT'

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

EOT
}

set -f # prevent pathname expansion

# dev can adjust these four variables:
PRODUCTNAME="Kindle Unified Launcher"
EXTENSIONDIR=/mnt/us/extensions
SEPARATOR=`printf "\x01"`
COLORMAX=0 # for --format=twolevel --colors=
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

alias sort='/bin/busybox sort' # GNU sort needs setting LC_ALL to work the same
alias find='/bin/busybox find' # why not
alias sed='/bin/busybox sed'   #

# usage: result=`str_repl_chars "SRC" "CHARS" CHR`
# replace all occurrences of characters of CHARS in SRC with character CHR
str_repl_chars () {
  local - IFS src=$1 chars=$2 chr=$3
  set -f
  IFS=$chars
  set -- $src
  IFS=$chr
  echo -n "$*"
}

# Usage: json_parse /path/to/menu.json [PROC]
# Stdout: PROC's formatted menu items
# Return: # of successful PROC calls
# Note: json_parse unsets+sets global variables json_*.
# For each input line that matches "action" this function creates a set of sh
# variables named json_N1, json_N2, ... where N1, N2, etc. are json key names.
# And for the input line that matches "name" but not "action" json_parse sets
# variable json_name0, which is the top level menu name, a.k.a. the group.
# Finally json_parse calls function PROC, which outputs a formatted combination
# for json_* (and previously-defined) xml_* variables.
# Note: json_parse() modifies the values of json_name and json_name0 by
# removing $SEPARATOR and squeezing spaces in preparation for making labels.
# Unmodified values are saved in jsonU_name and jsonU_name0 (-f=debuginfo).
json_parse () {
  local - IFS=${WSP_IFS} line menu=$1 proc=$2 count=0
  local CountNulls=0 # $proc may increment it
  shift 2
  local _w='[0-9a-zA-Z_]' _s=`printf "[\x20\x09]"`
  local dquot=`printf "\x22"` x01=`printf "\x01"` lf="`printf '\x0D'`" esc='\\\\\\'
  local json_name0 jsonU_name0 json_name jsonU_name json_action json_params json_priority
  unset vars json_name0 jsonU_name0
  log $menu
  sed -ne "# convert json key:value to shell var=value
	# dispatch
	/\"action\"/b magic # includes key 'name'
	/\"name\"/b magic0  # top-level key 'name'
	b
: magic0
	s/name/name0/ # rename it
	# assert: name0 comes before all other sub-keys
: magic
	# trim opening {[, and closing ]},
	s/^${_s}*[[{,]*${_s}*//
	s/${_s}*[]},]*${_s}*\$//
#p;b
	# mark id:value pairs
	s/\(.*\)/${x01}\1${x01}/
	s/,${_s}*${dquot}/${x01}${x01}${dquot}/g
#p;b
	# split them onto separate lines (multiline pattern space)
	s/${x01}\([^${x01}]\+\)${x01}/\n\1/g
#p;b
	# morph each line into ash variable syntax
	s/${dquot}${_s}*:${_s}*/=/g
	s/\n${dquot}/\njson_/g
#p;b
	p # done
	a EVAL
  " < $menu \
  | sed -ne "# apply escapes and cleanups
	{
		# translate json-escaped interior double quotes
		s/${dquot}/${x01}/ ; s/${dquot}\$/${x01}/
		s/${dquot}/\\\\${x01}/g
		s/${x01}/${dquot}/g
	#p;b
	}
	/json_name.\?=/{ # for each json_name? variable
		# save copy as jsonU_name?
		h; s/^\(.*json\)_\([^=]\+\)=\(.*\)$/\1U_\2=\3/g; p;x
		# clean up original to prepare for making labels
		s/[${SEPARATOR}]//g; s/[${WSP}]\+/ /g}
	}
	# shell-escape special characters that affect doublequoted strings
	s/\([$]\)/${esc}\1/g
#p;b
	p # done
#p;b
  " \
  | {
    while read line; do
#echo $line; continue
      if [[ EVAL = "$line" ]]; then
        unset json_name jsonU_name json_action json_params json_priority
        eval $vars
        unset vars
        [[ -z "$json_action" ]] && continue
        $proc $* && count=$((++count))
      else
        vars="$vars${lf}$line"
      fi
    done
    return $count
  }
}

# Usage: xml_var /path/to/config.xml NAME [NAME ...]
# Note: xml_var unsets+sets all requested global variables xml_NAME...
# xml_var creates one or more variables xml_NAME from an extension's config.xml
# file - the file must include tag "<extension>". Example:
#  xml_var config.xml author menu => xml_author(Mad Hatter) xml_menu(menu.json)
# Limitations:
# . opening and closing XML tags must be on the same line
# . XML values with embedded double quotes not supported
xml_var () {
  local v line xml=$1 valid=0
  shift
  for v in $*; do eval "unset xml_$v"; done
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
  local - v c=0 vars jsonpath=$1 jsonfile=$2
  echo $jsonpath/$jsonfile
#bash only: supports varname expansion and varname reference
#      echo -n "${0##*/} parsed:"
#      for v in ${!xml_*};  do echo -n " $v='${!v}'"; done
#      for v in ${!json_*}; do echo -n " $v='${!v}'"; done
#      for v in ${!jsonU_*}; do echo -n " $v='${!v}'"; done
  
#ash: hardwired variable names
 vars="xml_name json_name0 jsonU_name0
 json_name jsonU_name
 json_action json_params
 json_priority"
 for v in $vars; do
   eval "[[ \"\$$v\" ]] && printf \"%4d $v='%s'\\n\" \$((++c)) \"\$$v\""
 done
}

# default_output displays json_name,action' 'json_params
default_output () {
  local - label=${json_name} apath=$json_action group
  # top level menu name
  [[ "${json_name0}" ]] && group=${json_name0} || group=${xml_name}
  # prevent null labels
  [[ -z "$group" ]] && group=${1##*/}
  [[ -z "$label" ]] && label=$((++CountNulls))
  # fully qualify action path
  [[ -e "$1/$json_action" ]] && apath=$1/$json_action
  
  echo "$group · $label$SEPARATOR$apath $json_params"
# 20130130,a,stepk:
# Prepended "$group · " to conform to twobob's interim script. Consider instead
# using # -f=twolevel to provide the kindlet with group + label as separate
# tokens, which would make sense to build a nested menu GUI, if ever.
}

# touch_runner displays action,json_params,group'.'json_name (separator ';')
touch_runner () {
  local label=$json_name apath=$json_action group
  # top level menu name
  [[ "${json_name0}" ]] && group=${json_name0} || group=${xml_name}
  # prevent null labels
  [[ -z "$group" ]] && group=${1##*/}
  [[ -z "$label" ]] && label=$((++CountNulls))
  # qualify label
  label=`str_repl_chars "$group" . _`.$label
  
  echo "$1$SEPARATOR$apath$SEPARATOR${json_params:-NULL}$SEPARATOR$label"
}

# two_level displays cindex,group,json_name,action' 'json_params
two_level () {
  local label=$json_name apath=$json_action group
  # top level menu name
  [[ "${json_name0}" ]] && group=${json_name0} || group=${xml_name}
  # prevent null labels
  [[ -z "$group" ]] && group=${1##*/}
  [[ -z "$label" ]] && label=$((++CountNulls))
  # fully qualify action path
  [[ -e "$1/$json_action" ]] && apath=$1/$json_action
 
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

# usage: loop [ignorecount]
# find and process all config.xml files and their corresponding json menu files
loop () {
local - IFS=${NO_WSP} f px pj nj count=0 ignorecount=0 t
case $1 in
  ignorecount) ignorecount=1 ;;
esac
for f in $(find $EXTENSIONDIR -name config.xml); do
  log $f
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
    json_parse $pj/$nj $proc $pj $nj || count=$(($? + $count)) # allow -e by || 
  fi
done
log loop counted $count entries
# when extensions dir is empty
[[ 00 = $count$ignorecount ]] && test_applet install && loop ignorecount
return 0
}

# usage: test_applet install|uninstall
# adds/removes a simple test applet in $EXTENSIONDIR
# Installing clears and recreates an existing installation of the test applet
# return: non-zero on creation error
test_applet () {
  local prnm=`str_repl_chars "$PRODUCTNAME" "${WSP}" _`
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
    && echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<extension>
	<information>
		<name>$PRODUCTNAME</name>
		<version>1.0</version>
		<author>stepk</author>
		<id>Test</id>
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

