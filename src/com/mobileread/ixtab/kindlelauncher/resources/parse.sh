#!/bin/ash -
# aloop.sh - version 20130226,b,stepk
usage () {
local -
}
set -f 
CONFIGFILE="KUAL.cfg" 
PRODUCTNAME="KUAL"
EXTENSIONDIR="/mnt/us/extensions" 
SEPARATOR=`printf "\x01"`
COLORMAX=0 
EXITSTATUS=0
FORMATTER="formatter" # $1:''(\n,default) 'tbl'(table) 'tab'(\t)
case " $* " in
  *" -l "*)
     opt_log=1; 
     alias log='echo >&2'" ${0##*/}: " 
  ;;
  *) alias log='echo >/dev/null ' 
  ;;
esac
WSP_IFS=`printf "\x20\x09\x0A\x0D"`
NO_WSP=`printf "\x0A\x0D"`
WSP=`printf "\x20\x09"`
QUOTE=`printf "\x22"`
SPACE=' '
LT='<'
GT='>'
NBSP0='&nbsp;' ; NBSP1=`printf "\xC2\xA0"` 
alias sort='/bin/busybox sort' 
alias SORT="/bin/busybox sort -t '$SEPARATOR'"
alias find='/bin/busybox find'
alias sed='/bin/busybox sed'
alias grep='/bin/busybox grep'
alias CUT="/bin/busybox cut -d '$SEPARATOR'"
enTestApplet="              WELCOME TO $PRODUCTNAME

$PRODUCTNAME IS INSTALLED. PLEASE ADD SOME EXTENSIONS"
enStoreButtonReplaced="
STORE BUTTON REPLACED
PLEASE RESTART YOUR KINDLE
FOR CHANGES TO TAKE EFFECT"
enStoreButtonRestored="
STORE BUTTON RESTORED
PLEASE RESTART YOUR KINDLE
FOR CHANGES TO TAKE EFFECT"
enStoreButtonUnchanged="
STORE BUTTON UNCHANGED
ANOTHER APP ALREADY HOLDS IT"
XenErrNotInstalled="$PRODUCTNAME incomplete install." 
XenErrConfig="config"
XenErrUsage="usage"
XenErrNoTestApplet="can't install the test applet"
XenErrTestAppletStuck="can't uninstall the test applet"
screen_msg () {
  local - IFS=${WSP_IFS} msg caps col row=8 line i wo=0
  case "$1" in -lm=[0-9]|-lm=[0-9][0-9]) col=${1#-lm=} ; shift ;; esac
  case "$1" in -wo) wo=1 ; shift ;; esac
  msg="$@"
  caps=`eips -i 2>/dev/null` || return 
  set -- ${caps#*Variable framebuffer info}
  if [[ 0 = $wo ]]; then
    local xres=$2 
    eips -d l=00,w=$xres,h=104 -x 0 -y 148 2>/dev/null 1>&2
    eips -d l=ff,w=$xres,h=100 -x 0 -y 150 2>/dev/null 1>&2
  fi
  IFS=${NO_WSP}
  i=0
  printf "%s\n" "$msg" | while read line; do
    [[ $((++i)) -le 4 ]] || break
    case "$line" in
      -*) line=${line##-} ;; 
    esac
    eips ${col:-5} $((row++)) "${line}" 2>/dev/null 1>&2
  done
}
unset XSECT
case " $* " in
*" -x "*) while [[ "$1" != -x ]]; do shift; done; shift;
case "$1" in
0) shift; 
;;
1) shift; screen_msg "$@"; exit
;;
esac
esac
script_full_path () {
  local pth=$(2>/dev/null cd "${0%/*}" >&2; pwd -P)
  [[ "-p" = "$1" ]] || pth=$pth/${0##*/}
  echo -n "$pth" 
}
config_full_path () {
  local - IFS=: p cfp= a1=$1
  for p in $EXTENSIONDIR; do
    [[ -e "$p/$CONFIGFILE" ]] && { cfp="$p/$CONFIGFILE"; break; }
  done
  if [[ -n "$cfp" ]]; then
    echo -n "$cfp"
  elif [[ create = "$a1" ]]; then
    set -- $EXTENSIONDIR
    cfp="$1/$CONFIGFILE"
    echo "# $CONFIGFILE - created on `date`" > "$cfp" && echo -n "$cfp"
  fi
}
clean_up_previous_runs () {
  local - IFS pth=${1%/*}
  set +f
  case "$pth/" in */tmp/*|*/temp/*) true ;; *) return ;; esac
  local x me=$1 name=${1##*/} suf glob
  suf="${name##*.}"; [[ -n "$suf" ]] && suf=".$suf"
  glob="$pth/${name%-*}-*${suf}" 
  log "clean-up glob($glob)=\"`echo ${glob}`\""
  IFS=${NO_WSP}
  for x in `printf "%s\n" ${glob}`; do [[ "$x" = "$me" ]] || rm "$x"; done
}
str_repl_chars () {
  local - IFS src=$1 chars=$2 chr=$3
  set -f
  IFS=$chars
  set -- $src
  IFS=$chr
  echo -n "$*"
}
json_parse () {
  local - IFS=${WSP_IFS} line menu=$1 proc=$2 count=0
  local CountNulls=0 
  shift 2
  local _w='[0-9a-zA-Z_]' _s=`printf "[\x20\x09]"`
  local dquot=`printf "\x22"` x01=`printf "\x01"` lf="`printf '\x0D'`" esc='\\\\\\'
  local json_name0 jsonU_name0 json_name jsonU_name json_action json_params json_priority json_priority0
  unset vars json_name0 jsonU_name0 json_priority0
  log $menu
  sed -ne "# convert json key:value to shell var=value
	# dispatch
	/\"action\"/b magic # includes keys 'name' and 'priority'
	/\"\(name\|priority\)\"/b magic0  # top-level keys 'name' or 'priority'
	b
: magic0
	s/\(name\|priority\)/\10/ # rename key
	# assert: name0 and priority0 come before all other sub-keys
: magic
	# trim opening {[, and closing ]},
	s/^${_s}*[[{,]*${_s}*//
	s/${_s}*[]},]*${_s}*\$//
#p;b
	# mark id:value pairs
	s/\([^${x01}]\+\)/${x01}\1${x01}/
	s/,${_s}*${dquot}/${x01}${x01}${dquot}/g
#p;b
	# split them onto separate lines (formatter pattern space)
	s/${x01}\([^${x01}]\+\)${x01}/\n\1/g
#p;b
	# morph each line into ash variable syntax
	s/${dquot}${_s}*:${_s}*/=/g
	s/\n${dquot}/\njson_/g
#p;b
	p # done
	a EVAL
  " < $menu \
  | sed -ne "# apply escapes and clean-ups
	{
		# translate json-escaped interior double quotes
		s/${dquot}/${x01}/ ; s/${dquot}\$/${x01}/ # suspend exterior quotes
		s/${dquot}/\\\\${x01}/g
		s/${x01}/${dquot}/g # restore exterior quotes
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
	# expand known character entities
	s/${NBSP0}/${NBSP1}/g
#p;b
	p # done
  " \
  | {
    while read line; do
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
xml_var () {
  local v line xml=$1 valid=0
  shift
  for v in $*; do eval "unset xml_$v"; done
  while read line; do
    case $line in
    *"<extension>"*) valid=1 ;; 
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
debug_info () {
  case $1 in backdoor) shift; set_backdoor_args "$@";; esac
  local - IFS=${WSP_IFS} v c=0 vars jsonpath=$1 jsonfile=$2
  echo $jsonpath/$jsonfile
 vars="xml_name json_name0 jsonU_name0 json_priority0
 json_name jsonU_name
 json_action json_params
 json_priority"
 for v in $vars; do
   eval "[[ \"\$$v\" ]] && printf \"%4d $v='%s'\\n\" \$((++c)) \"\$$v\""
 done
}
set_backdoor_args() {
  json_name0=$3
  json_priority0=$4
  json_priority=$5
  json_name=$6
  json_action=$7
  json_params=$8
}
one_level () {
  case $1 in backdoor) shift; set_backdoor_args "$@";; esac
  local - label=${json_name} apath=$json_action group action_path=$1 priority=''
  [[ "${json_name0}" ]] && group=${json_name0} || group=${xml_name}
  [[ -z "$group" ]] && group=${1##*/}
  [[ -z "$label" ]] && label=$((++CountNulls))
  [[ -e "$action_path/$json_action" ]] && apath=\"$action_path/$json_action\"
  [[ 123 = "$opt_sort" ]] && priority="${json_priority0:-0}$SEPARATOR${json_priority:-0}$SEPARATOR"
  echo "$TIER$SEPARATOR${priority}2$SEPARATOR$group · $label$SEPARATOR$apath $json_params"
}
touch_runner () {
  case $1 in backdoor) shift; set_backdoor_args "$@";; esac
  local label=$json_name action=$json_action group action_path=$1 priority=''
  [[ "${json_name0}" ]] && group=${json_name0} || group=${xml_name}
  [[ -z "$group" ]] && group=${1##*/}
  [[ -z "$label" ]] && label=$((++CountNulls))
  label=`str_repl_chars "$group" . _`.$label
  [[ 123 = "$opt_sort" ]] && priority="${json_priority0:-0}$SEPARATOR${json_priority:-0}$SEPARATOR"
  echo "$TIER$SEPARATOR$priority$action_path$SEPARATOR$action$SEPARATOR${json_params:-NULL}$SEPARATOR$label"
}
two_level () {
  case $1 in backdoor) shift; set_backdoor_args "$@";; esac
  local label=$json_name apath=$json_action group action_path=$1 priority=''
  [[ "${json_name0}" ]] && group=${json_name0} || group=${xml_name}
  [[ -z "$group" ]] && group=${1##*/}
  [[ -z "$label" ]] && label=$((++CountNulls))
  [[ -e "$action_path/$json_action" ]] && apath=\"$action_path/$json_action\"
  [[ 123 = "$opt_sort" ]] && priority="${json_priority0:-0}$SEPARATOR${json_priority:-0}$SEPARATOR"
  echo "$TIER$SEPARATOR${priority}3$SEPARATOR$group$SEPARATOR$label$SEPARATOR$apath $json_params"
}
colorize () {
  local IFS=${NO_WSP} cindex=-1 cstate='' line meta group
  while read line; do
    IFS=${SEPARATOR} ; set -- $line ; meta=$1 group=$2 ; IFS=${NO_WSP}
    shift 1 
    if [[ "$cstate" != "$group" ]]; then
      cstate=$group
      cindex=$(( ($cindex + 1) % $COLORMAX ))
    fi
    echo "$((++meta))$SEPARATOR$cindex$SEPARATOR$*"
  done
}
loop () {
local - IFS=:${NO_WSP} TIER=2 f px pj nj count=0 ignorecount=0 t list 
case $1 in
  ignorecount) ignorecount=1 ;;
esac
for f in $(find $EXTENSIONDIR -name config.xml 2>&-); do
  log $f
  xml_var $f name menu
  [[ "$xml_menu" ]] || continue 
  case "${xml_menu##*.}" in
    json) ;; 
    *) continue ;; 
  esac
  px=${f%/*} 
  case "$xml_menu" in
    /*) pj=${xml_menu%/*}
    ;;
    *) 
       pj=$px/${xml_menu}
       pj=${pj%/*}
    ;;
  esac
  nj=${xml_menu##*/} 
  if [[ -f $pj/$nj ]]; then
    json_parse $pj/$nj $proc $pj $nj || count=$(($? + $count)) 
  fi
done
log loop counted $count entries
[[ 00 = $count$ignorecount ]] && test_applet install && loop ignorecount
[[ 0 = $ignorecount ]] && emit_self_menu 
return 0
}
emit_self_menu() {
  local - IFS=${WSP_IFS} TIER=3 c0=$count
  local verb=Replace btnpath=`store_button_filepath`
  if [[ -e "$btnpath" ]]; then
    [[ -e "$btnpath.KUAL_bak" ]] && verb=Restore
    $proc backdoor \
    "${SCRIPTPATH%/*}" '(backdoor)' \
    "$PRODUCTNAME" 1000 0 "$verb Store Button" \
    "/bin/ash" "\"$SCRIPTPATH\" \"-e=1,$verb\"" \
    && count=$((++count))
  fi
  local order0 order1 opt
  case "$opt_sort" in
    abc)   menu1=123; opt1=-s=123 ; menu2=ABC; opt2=-s=ABC ;;
    123)   menu1=abc; opt1=-s=abc ; menu2=ABC; opt2=-s=ABC ;;
    ABC|*) menu1=123; opt1=-s=123 ; menu2=abc; opt2=-s=abc ;;
  esac
  $proc backdoor \
  "${SCRIPTPATH%/*}" '(backdoor)' \
  "$PRODUCTNAME" 1000 0 "Sort Menu \"$menu1\"" \
  "/bin/ash" "\"$SCRIPTPATH\" \"-e=2,$opt1\"" \
  && count=$((++count))
  $proc backdoor \
  "${SCRIPTPATH%/*}" '(backdoor)' \
  "$PRODUCTNAME" 1000 0 "Sort Menu \"$menu2\"" \
  "/bin/ash" "\"$SCRIPTPATH\" \"-e=2,$opt2\"" \
  && count=$((++count))
  TIER=3.99
  $proc backdoor \
  "/dev/null/sic" '(backdoor)' \
  "$PRODUCTNAME" 1000 99 "Quit" \
  "true" "" \
  && count=$((++count))
  log "$(($count - $c0)) self-menu entries added"
}
exec_self_menu() {
  local - IFS=,
  set -- $*
  IFS=${WSP_IFS}
  case $1 in
  1) 
    local verb=$2 btnpath=`store_button_filepath` bak
    [[ -e "$btnpath" ]] || return 
    bak=$btnpath.KUAL_bak 
    case $verb in
      Restore) [[ -e "$bak" ]] || return 
        mntroot rw && mv -f "$bak" "$btnpath"
        mntroot ro
        screen_msg "$enStoreButtonRestored" 
      ;;
      Replace) [[ -e "$bak" ]] && return 
        local needle='app://com.lab126.store'
        if ! grep -q -m 1 -F "$needle" "$btnpath"; then
          screen_msg "$enStoreButtonUnchanged"
          return
        fi
        local repl=`KUAL_filepath`
        [[ -e "$repl" ]] || return 
        if mntroot rw && mv "$btnpath" "$bak"; then
          sed -e "s~\([\"']\)$needle\(['\"]\)~\1file://$repl\2~" "$bak" > "$btnpath"
          mntroot ro
          screen_msg "$enStoreButtonReplaced" 
        fi
      ;;
    esac
  ;;
  2) 
    local opt=$2 config=`config_full_path create` newtext='' line found=0
    local _s=`printf "[\x20\x09]"` dquot=`printf "\x22"`
    IFS=${NO_WSP}
    newtext=$( 
      sed -e "
/^${_s}*KUAL_options=/ {
	# delete existing sort option(s)
	s/${_s}-s=.*\>//g
	s/-s=.*\>${_s}//g
	s/-s=.*${dquot}/${dquot}/
}
      " "$config" \
    | {
    while read line; do
        case $line in 
          *KUAL_options=\"\") echo "KUAL_options=\"$opt\"" ; found=1
        ;; 
          *KUAL_options=\"*\") echo "${line%?} $opt\"" ; found=1
        ;; 
          *KUAL_options=*) echo "KUAL_options=\"${line#KUAL_options=} $opt\"" ; found=1
        ;; 
          *) echo "$line"
        ;;
        esac
      done
      [[ 0 = $found ]] && echo KUAL_options=\"$opt\"
      }
    ) 
    [[ 0 != ${#newtext} ]] && echo "$newtext" > "$config"
  ;;
  99) 
  ;;
  esac
}
store_button_filepath() {
  local KT532=/usr/share/webkit-1.0/pillow/javascripts/search_bar.js
  [[ -e "$KT532" ]] && echo -n "$KT532"
}
KUAL_filepath() {
  local -
  set +f
  set -- `echo /mnt/us/documents/KindleLauncher*.azw2`
  [[ -e "$1" ]] && echo -n "$1"
}
test_applet () {
  local - prnm=`str_repl_chars "$PRODUCTNAME" "${WSP}" _`
  local dir=${EXTENSIONDIR%%:*}/$prnm
  local sh="$dir/test.sh" xml="$dir/config.xml" json="$dir/menu.json"
  [[ -d "$dir" ]] && rm -f "$sh" "$xml" "$json" && rmdir "$dir"
  case "$1" in
  uninstall)
    if [[ -d "$dir" ]]; then
      echo >&2 "${0##*/}: XenErrTestAppletStuck"
      emit_error 1 XenErrTestAppletStuck
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
      emit_error 1 XenErrNoTestApplet
\"items\": [
	{
		\"name\": \"$NBSP0$PRODUCTNAME\",
		\"priority\": 1000,
		\"items\": [
			{\"name\": \"${NBSP0}Test $PRODUCTNAME\", \"priority\": 0, \"action\": \"test.sh\"}
		]
	}
]
}" > "$json" \
    && echo "#/bin/ash -
[[ \"\$KUAL\" ]] && exec \$KUAL 1 -lm=3 \"$enTestApplet\" || eips 2 38 \"$XenErrNotInstalled\"
" > "$sh" \
    && chmod +x "$sh" && log "test applet installed"
    }
    then
      echo >&2 "${0##*/}: $XenErrNoTestApplet"
      emit_error 1 XenErrNoTestApplet
      return 1
    fi
  ;;
  esac
  return 0
}
formatter () {
  local - IFS=$SEPARATOR fmt nl line
  case $1 in
    =) fmt="%s" ;; 
    tbl) fmt="%-2.2s|%-20.20s|%-25.25s|%-25.25s" ;;
    tab) fmt="%s\t" ;;
    *) [[ -n "$1" ]] && fmt=$1 || fmt='%s\n' ;;
  esac
  nl="${fmt%\\n}" ; [[ "$nl" = "$fmt" ]] && nl='\n' || unset nl
  while read line; do
    printf "$fmt" $line
    printf "$nl"
  done
}
emit_error () {
  local TIER=$1 name=$2 msg
  shift 2
  eval "msg=\"\${$name} $*\"" 
  $proc backdoor /dev/null/sic '(backdoor)' '!err!' 0 0 "$msg" true ''
  EXITSTATUS=1
}
get_options () {
local - opt status=0 x
unset opt_execmenu opt_format opt_sort
for opt in "$@"; do
  case "$opt" in
    -c=*) x=${opt#*=}
       case "$x" in [0-9]|[0-9][0-9]|[0-9][0-9][0-9]) COLORMAX=$(($x)) ;; esac ;;
    -e=*) opt_execmenu=${opt#*=} ;;
    -f=*) x=${opt#*=}
      case "$x" in
        onelevel|twolevel|touchrunner|debuginfo) opt_format=$x ;;
        *)
          echo >&2 "${0##*/}: invalid option '-f=$x': using default options"
          echo "emit_error 1 XenErrUsage \"-f=$x invalid, defaults used\""
        ;;
      esac
    ;;
    -h|--help) usage >&2; exit ;;
    -l) ;; 
    -p=*) FORMATTER="formatter \"${opt#*=}\"" ;;
    -s=*)  x=${opt#*=}
      case "$x" in
        123|abc|ABC) opt_sort=$x ;;
        *)
          echo >&2 "${0##*/}: invalid option '-s=$x': using default options"
          echo "emit_error 1 XenErrUsage \"-s=$x invalid, defaults used\""
        ;;
      esac
    ;;
    *)
      echo >&2 "${0##*/}: invalid option '$opt': using default options"
      echo "emit_error 1 XenErrUsage \"$opt invalid, defaults used\""
      status=1
    ;;
  esac
done
return $status
}
sortx () {
local - t byname=''
case "$opt_sort" in
  abc|ABC)
    case $proc in
      one_level) echo "| SORT -f -k 1,1n -k 3,3 -s | CUT -f 2-" ;;
      touch_runner) echo "| SORT -f -k 1,1n -k 5,5 -s | CUT -f 2-" ;;
      two_level) [[ 0 -lt $COLORMAX ]] && t=' | colorize' || t=''
        [[ ABC = $opt_sort ]] && byname="-k 4,4" 
        echo "| SORT -f -k 1,1n -k 3,3 $byname -s | CUT -f 2-$t"
      ;;
    esac
  ;;
  123)
    case $proc in
      one_level) echo "| SORT -f -k 1,1n -k 2,2n -s | CUT -f 4-" ;; 
      touch_runner) echo "| SORT -f -k 1,1n -k 2,2n -s | CUT -f 4-" ;;   
      two_level) [[ 0 -lt $COLORMAX ]] && t=' | colorize' || t=''
        echo "| SORT -f -k 1,1n -k 2,2n -k 5,5 -k 3,3n -s | CUT -f 4-$t" 
      ;;
    esac
  ;;
  *)
    case $proc in
      two_level) [[ 0 -lt $COLORMAX ]] && t='| colorize' || t=''
      echo "|CUT -f 2-$t"
    ;;
      *) echo "|CUT -f 2-"
    esac
  ;;
esac
}
init () {
local TIER=1 gotOptions=false KUAL_options='' x
CONFIGPATH=`config_full_path`
SCRIPTPATH=`script_full_path`
if [[ -e "$CONFIGPATH" ]]; then
  if ! source "$CONFIGPATH"; then
    echo "emit_error 1 XenErrConfig \"$CONFIGPATH\""
    echo "emit_error 3 XenErrConfig \"$CONFIGPATH\""
    KUAL_options='' 
  fi
fi
until [[ true = "$gotOptions" ]]; do
  if [[ \( 0 = $# -a -z "$KUAL_options" \) -o \( 1 = $# -a -n "$opt_log" -a -z "$KUAL_options" \) ]]; then
    set -- -f=twolevel -s=abc 
  else
    set -- $KUAL_options "$@"
  fi
  if get_options "$@"; then
    gotOptions=true
  else
    KUAL_options=''
    set -- ${opt_log+-l}
  fi
done
[[ -z "$opt_format" ]] && opt_format=twolevel 
[[ -e "$CONFIGPATH" -a -n "$opt_log" ]] && log "found $CONFIGPATH
`cat $CONFIGPATH`"
log "system `uname -rsnm`"
log "run options: $opt_format $opt_sort ($*)"
clean_up_previous_runs "$SCRIPTPATH"
if [[ "$opt_execmenu" ]]; then
  exec_self_menu $opt_execmenu
  exit $?
fi
case "$opt_format" in
  twolevel) proc=two_level; COLORIDX=-1 ; COLORSTATE="" ;;
  onelevel) proc=one_level ;;
  touchrunner) proc=touch_runner; SEPARATOR=';' ;;
  debuginfo) proc=debug_info ;;
esac
test_applet uninstall
echo "
CONFIGPATH='$CONFIGPATH'
SCRIPTPATH='$SCRIPTPATH'
opt_format='$opt_format'
opt_sort='$opt_sort'
opt_log='$opt_log'
opt_execmenu='$opt_execmenu'
proc='$proc'
COLORMAX='$COLORMAX'
FORMATTER='$FORMATTER'
"
}
log "start pid($$)"
starter=`init "$@"` 
log "starter($starter)"
proc=':' 
eval "$starter" >/dev/null 
log "proc($proc)"
to_user="`sortx` | $FORMATTER"
log "to_user($to_user)"
eval "{ $starter; loop; } $to_user"
t=$?
[[ -z "$EXITSTATUS" ]] && EXITSTATUS=$t
log "exit status($EXITSTATUS)"
exit $EXITSTATUS
