#!/bin/busybox ash
# aloop-v2.sh - version 20130404,b,stepk
VERSION="20130404,b"
usage () {
local -
}
set -f 
readonly CONFIGFILE="KUAL.cfg" 
readonly PRODUCTNAME="KUAL"
readonly EXTENSIONDIR="/mnt/us/extensions" 
readonly SEPARATOR=`printf "\x01"`
COLORMAX=0 
EXITSTATUS=0
readonly EXITMENU=1 # Kindlet commits suicide (default for all buttons, json "exitmenu":false saves)
readonly SCREAM_LOG="/var/tmp/$PRODUCTNAME.log"
alias scream='echo >&4'
case " $* " in
  *" -l "*)
     opt_log=1; 
     alias log='echo >&2'" ${0##*/}: " 
  ;;
  *) alias log='echo >/dev/null ' 
  ;;
esac
readonly WSP_IFS=`printf "\x20\x09\x0A\x0D"`
readonly NO_WSP=`printf "\x0A\x0D"`
readonly WSP=`printf "\x20\x09"`
readonly QUOTE=`printf "\x22"`
readonly SPC=' '
readonly LT='<'
readonly GT='>'
readonly TAB=`printf "\x09"`
readonly k_action=0x00  
readonly k_priority=0x01 
readonly k_params=0x02
readonly k_exitmenu=0x03
readonly k_hidden=0x04
readonly k_name=0x05 
readonly k_items=0xff # don't change
readonly RESERVED=0xff
readonly NBSP0='&nbsp;'
readonly NBSP1=`printf "\xC2\xA0"` 
readonly MMRK=`printf "\xE2\x96\xB6"`
alias dprintf="printf >&2"
alias decho="echo >&2"
alias sort='/bin/busybox sort' 
alias SORT="/bin/busybox sort -t '$SEPARATOR'"
alias find='/bin/busybox find'
alias sed='/bin/busybox sed'
alias grep='/bin/busybox grep'
alias CUT="/bin/busybox cut -d '$SEPARATOR'"
alias cat='/bin/busybox cat'
alias wc='/bin/busybox wc'
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
readonly MAX_LABEL_LEN=40
XenErrConfig="Config"
XenErrSyntax="Syntax"
XenErrUsage="Usage"
XenErrNoTestApplet="Can't install $PRODUCTNAME test applet"
XenErrTestAppletStuck="Can't uninstall $PRODUCTNAME test applet"
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
    usleep 25000
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
str_repl_chars () {
  local - IFS src=$1 chars=$2 chr=$3
  set -f
  IFS=$chars
  set -- $src
  IFS=$chr
  echo -n "$*"
}
test_applet () {
  local - prnm=`str_repl_chars "$PRODUCTNAME" "${WSP}" _`
  local dir=${EXTENSIONDIR%%:*}/$prnm
  local sh="$dir/test.sh" xml="$dir/config.xml" json="$dir/menu.json"
  cd /var/tmp && rm -f "$sh" "$xml" "$json"
  case "$1" in
  uninstall)
     rmdir "$dir" 2>/dev/null || true
     if [ -d "$dir" ]; then
      echo >&2 "${0##*/}: XenErrTestAppletStuck"
      emit_error 1 XenErrTestAppletStuck
      echo -n ''
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
	{\"name\": \"Test $PRODUCTNAME\", \"priority\": -1000, \"action\": \"test.sh\"}
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
      echo -n ''
    fi
  ;;
  esac
  echo -n "$json"
}
unset XSECT
case " $* " in
*" -x "*) while [[ "$1" != -x ]]; do shift; done; shift;
case "$1" in
0) shift; 
;;
1) shift; screen_msg "$@"; exit ;;
2) shift
  local when=`date -u -Iminutes | sed s/:/./g`
  mv "$SCREAM_LOG" "/mnt/us/documents/$PRODUCTNAME-$when.txt"
  dbus-send --system /default com.lab126.powerd.resuming int32:1
  exit
;;
3) test_applet install; exit 
;;
esac
esac
exec 4> "$SCREAM_LOG"
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
  for x in `printf "%s\n" ${glob}`; do [[ "$x" = "$me" ]] || rm -f "$x" 2>/dev/null; done
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
EMIT_ERROR_COUNT=0
emit_error () {
  local - status=$1 name=$2 len
  shift 2
  local f=$*
  eval "len=\$((MAX_LABEL_LEN - \${#$name}))"
  local x=$f
  while [ ${#x} -gt $len ]; do x=${x#?}; done 
  [ ${#f} -ge ${#x} ] && x=" ..${x#???}"
  eval "x=\"\${$name}$x\""
  >&3 jpath_add_entry_to_menu messages "$x" '[ "$KUAL" ] && $KUAL 2'
  EXITSTATUS=$status # don't run this in a sub-shell!
  EMIT_ERROR_COUNT=$((++EMIT_ERROR_COUNT))
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
    -p=*)  opt_formatter=${opt#*=} ;;
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
init () {
local TIER=1 gotOptions=false KUAL_options='' x
CONFIGPATH=`config_full_path`
SCRIPTPATH=`script_full_path`
if [[ -e "$CONFIGPATH" ]]; then
  if ! source "$CONFIGPATH"; then
    echo "emit_error 1 XenErrConfig \"$CONFIGPATH\""
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
  debuginfo) proc=debug_info ;;
esac
test_applet uninstall >/dev/null
echo "
CONFIGPATH='$CONFIGPATH'
SCRIPTPATH='$SCRIPTPATH'
KUAL_show_KUAL_buttons='$KUAL_show_KUAL_buttons'
KUAL_nofollow='$KUAL_nofollow'
opt_format='$opt_format'
opt_sort='$opt_sort'
opt_log='$opt_log'
opt_execmenu='$opt_execmenu'
opt_engine='$opt_engine'
opt_formatter='$opt_formatter'
proc='$proc'
COLORMAX='$COLORMAX'
"
}
send_config () {
  if [[ -e "$CONFIGPATH" ]]; then
    set -- `wc -l "$CONFIGPATH"`
    echo $((1+$1))
    echo "$VERSION"
    cat "$CONFIGPATH"
  else
    echo 0
  fi
}
unpack () { 
cat << 'UNPACK' 
BEGIN { 
	VERSION="20130404,b"
	NARGV = ARGC
	while (0 < (getline ARGV[++ARGC] < "/dev/stdin")) {
		if (ARGV[ARGC] == "")
			break
	}
	srand()
	RS="n/o/m/a/t/c/h" rand()
	init()
	if (1 == ARGC - NARGV) {
		ARGC = find_menu_fullpathnames(EXTENSIONDIR, ARGV, ARGC)
		if (1 == ARGC - NARGV && "" != SCRIPTPATH) { 
			"/bin/ash '"SCRIPTPATH"' -x 3" | getline 
			if ("" != $0) ARGV[++ARGC] = $0
		}
	}
	BRIEF=1; 
	STREAM=0;
	delete FAILS
	ERRORS = GOODCOUNT = 0 
}
{ 
	reset() 
	SVNJPATHS = 0+NJPATHS
	tokenize($0) 
	if (0 == (status = parse())) { 
		++GOODCOUNT # ++GOODCOUNT leaves serial 0 free for menu 'messages'
		status = jp2np(JPATHS, NJPATHS, GOODCOUNT, FILENAME) 
	} else { 
		while(NJPATHS > SVNJPATHS) {
			delete JPATHS[NJPATHS--]
		}
	}
	if (status) ++ERRORS
}
END { 
	json_emit_self_menu_and_parsing_errors() 
	delete MENUS; NMENUS=0
	if (0 == (status = np2mn(NPATHS, NNPATHS))) {
		delete NPATHS; NNPATHS=0
	} else scream("error (np2mn)")
	if (status) ++ERRORS
	teardown()
	exit(ERRORS)
}
function init(   i) { 
if (""==FORMATTER) FORMATTER="multiline"
if (""==OPT_SORT) OPT_SORT="ABC"
KUAL_show_KUAL_buttons="" # "i j k"... | "0" | "" 
delete COUNTER
COUNTER["nameNull"]=0
if(""==EXTENSIONDIR) EXTENSIONDIR="/mnt/us/extensions" 
if(""==PRODUCTNAME) PRODUCTNAME="KUAL"
if(""==CONFIGFILE) CONFIGFILE=PRODUCTNAME".cfg" 
CONFIGPATH=config_full_path()
SEP="\x01"
SCREAM_LOG="/var/tmp/" PRODUCTNAME ".log"
VALID_KEYS["action"]=K_action=0x00  
VALID_KEYS["priority"]=K_priority=0x01 
VALID_KEYS["params"]=K_params=0x02
VALID_KEYS["exitmenu"]=K_exitmenu=0x03
VALID_KEYS["hidden"]=K_hidden=0x04
VALID_KEYS["name"]=K_name=0x05 
VALID_KEYS["items"]=K_items=0xff # don't change
VALID_KEYS["ERROR"]="??"
RESERVED=0xff
xRESERVED="ff"
FFS="ffffffffffffffffffffffffffffffffffffffffffffffff" 
NBSP0="&nbsp;"
NBSP1="\xC2\xA0" 
MMRK="\xE2\x96\xB6"
MAX_LABEL_LEN=40
XenErrSyntax="Syntax"
TFL="/var/tmp/--" PRODUCTNAME "--" # use a fixed stem, not rand() nor alt PROCINFO["pid"]
}
function teardown(   i) { 
	system("cd /var/tmp && rm -f \"" TFL "\"* 2>/dev/null")
}
function config_full_path(create, # {{{ [create="create"] creates first(EXTENSIONDIR)/CONFIGFILE if it doesn't exist
	i,ary,nary,x) {
	nary = split(EXTENSIONDIR, ary, /;/)
	for (i = 1; i <= nary; i++) {
		cfp = ary[i]"/"CONFIGFILE
		if (0 < (getline x < cfp))
			break
	}
	if ("" != cfp)
		return cfp
	if ("create" == create) {
		cfp=ary[1]"/"CONFIGFILE
		"date" | getline x
		print "# "CONFIGFILE" - created on "x > cfp ; close(cfp)
		return cfp
	}
}
function config_get(configfullpath, 
	ary,nary,slurp,s,p,count) {
	getline slurp < configfullpath
	if ("" != slurp) {
		nary = split(slurp, ary, /\n/)
		for (i = 1; i < nary; i++) {
			if (ary[i] ~ "^\\s*"PRODUCTNAME"_\\w+=") {
				s = ary[i]
				s = substr(s,1+index(s,"_"))
				p = index(s, "=")
				CONFIG[substr(s,1,p-1)] = substr(s,p+1)
				++count
			}
		}
	}
	return 0+count
}
function exec_self_menu() { 
}
function find_menu_fullpathnames(dirs, return_ary, base,  
	pj,nj,follow,slurp,i,ary,nary,menu) {
	follow = "true" == CONFIG["KUAL_nofollow"] ? "" : " -follow"
	gsub(/;/, " ", dirs) 
	"find "dirs follow" -name config.xml 2>/dev/null" | getline slurp
	nary = split(slurp, ary, /\n/)
	for (i=1; i < nary; i++) {
		menu = pathjson = pathxml = ""
		getline slurp < ary[i] 
		if (slurp ~ /<extension>.+<\/extension>/) { 
		    if (match(slurp, /<menu\>[^>]+\<type="json"[^>]*>[^<]+<\/menu>/)) { # type="json"
			    slurp = substr(slurp,RSTART,RLENGTH-7) 
			    menu = substr(slurp,1+index(slurp,">")) 
		    }
		} #else print "slurp("slurp")" > "/dev/stderr" 
		if ("" != menu) {
			if ("^/" !~ menu) { 
				match(ary[i], /^.*\//)
				menu = substr(ary[i],RSTART,RLENGTH) menu 
			}
			if (0 < (getline x < menu))
				return_ary[++base] = menu
		}
	}
	return base
}
function json_emit_self_menu_and_parsing_errors(   json,     
	name,sname,msg,ary,nary) {
	json=json_self_menu() 
	for(name in FAILS) {
		json=json ",{\"priority\": -1000, \"name\": \"" \
			fit_button("."XenErrSyntax" ", shortpathname(name)) \
		       	"\", \"action\": \"[ \\\"$KUAL\\\" ] && $KUAL 2\"}"
	} 
	if (json) { 
		name = PRODUCTNAME
		if (ERRORS)
			name = name "( "ERRORS" )"
		json="{\"items\":[{\"name\":\"" name \
			"\",\"items\":[" \
			substr(json,2) "]}]}"
		delete TOKENS; NTOKENS = ITOKENS = 0
		tokenize(json)
		parse()
		jp2np(JPATHS, NJPATHS, 0, "/var/tmp/.")
	}
}
function json_self_menu (   json, 
	show,b,verb,btnpath) {
	if (0 == (show=KUAL_show_KUAL_buttons)) # "i j k"... | "0" | ""
		return ""
	if ("" == show) show="1 2 99" 
	json = ""
	if (split(show, ary, /\s+/)) {
		for (b in ary) {
			if (1 == ary[b]) {
				verb="Replace"
				if ("" == (btnpath=store_button_filepath()))
					continue
				if (0 < (getline < btnpath".KUAL_bak"))
					verb="Restore"
				json=json ",{\"name\": \"" \
					verb" Store Button" \
				"\", \"action\": \"" \
					"/bin/ash '"SCRIPTPATH"' '-e=1,"verb"'" \
				"\", \"priority\": 1}"
			} else if (2 == ary[b]) {
				verb = OPT_SORT ~ /^ABC|abc$/ ? "123" : "ABC"
				json=json ",{\"name\": \"" \
					"Sort Menu "verb \
				"\", \"action\": \"" \
					"/bin/ash '"SCRIPTPATH"' '-e=2,-s="verb"'" \
				"\", \"priority\": 2}"
			} else if (99 == ary[b]) {
				json=json ",{\"name\": \"" \
					"× Quit" \
				"\", \"action\": \"" \
					"true" \
				"\", \"priority\": 99}"
  			}
  		}
	}
	return json
}
function jp2np(ary, size, serial, menufilepathname,   
	i,x,n,apath,jpath,key,value,level,errors) {
	errors=0
	apath=menufilepathname; sub(/\/[^\/]+$/, "", apath)
	while (jp2np_LAST_SEEN <= size) {
		line=ary[jp2np_LAST_SEEN++]  # {
		if (line ~ /[]}]$/) {
			continue
		}
		x=index(line,"\t")
		jpath=substr(line, 1, x-1)
		value=substr(line, x+1)
		key = match(jpath, /"[^"]+"]$/) ? substr(jpath, 1+RSTART,RLENGTH-3) : "ERROR"
		if (key !~ /^(name|action|params|priority|exitmenu|hidden)$/) {
			continue
		}
		key=VALID_KEYS[key]
		x = jpath
		level = gsub(/"items",/, "&", x)
		if (0 == level) {
			continue
		}
		--level 
		n=npath(jpath, serial)
		gsub(/^"|"$/, "", value)
		if (K_name == key) {
			gsub(NBSP0, NBSP1, value)
		} else if (K_action == key) {
			value=apath ";" value
		} else if (K_params == key) {
			gsub(/\\\"/, "\"", value)
		}
		NPATHS[++NNPATHS]=level SEP n SEP key SEP value
	}
	return errors
}
function np2mn(ary, size,    
	i,slurp,lines,nlines,iline,errors,
	npary,level,npath,key,value,xname,options,
	this_items,select_level,needle,snpath,last_action  ) {
	errors=0
	sort(ary, size, "-s -k2,2 -k1,1 -k3,3")
	if ("" == SORTED_DATA) {
		scream("np2mn can't sort 1")
		++errors
	} else {
		new_item()
		new_submenu()
		snpath="SNPATH"; last_action="SNPATH"
	       	select_level[0] = n_s2n("00") 
		xname = sprintf("%02x", K_name)
		if (0 < (nlines = split(SORTED_DATA,lines, /\n/))) {
			for(iline = 1; iline < nlines; iline++) {
				split(lines[iline], npary, SEP)
				level = npary[1]; npath = npary[2]; key = npary[3]; value = npary[4]
				snpath = n_n2s(npath)
				if (K_action == key) {
					ITEM[key] = value
					last_action = snpath
				} else if (K_name == key) {
					if ("" == value) 
						value = "??"(++COUNTER["nameNull"])
					if (submenuQ(snpath, last_action)) { 
						ITEM[key]=value 
						sortable_tag=select_level[level]
						MENUS[++NMENUS] = work_record( \
							sort_criteria(sortable_tag, OPT_SORT),
							kindlet_options(),
							level":"this_(K_name, snpath), # refers to this."name"
							ITEM[K_name], # VALID_KEYS w/o "items"
							ITEM[K_action] ("" != ITEM[K_params] ? " " : "") ITEM[K_params]  )
						new_item()
					} else { 
						ITEM[key]=value" "MMRK 
          this_items = this_(K_items, snpath) # refers to this."items"
          select_level[level+1] = n_s2n(this_items) 
	  sortable_tag = select_level[level] 
	  needle="^" (level+1) ":" this_items ".." xname "$"
						MENUS[++NMENUS] = work_record( \
							sort_criteria(sortable_tag, OPT_SORT),
							kindlet_options(),
							level":"snpath,
							ITEM[K_name], # VALID_KEYS for a submenu (needle as "action")
							needle)
						new_submenu()
					}
				} else if (K_priority == key || K_params == key || K_exitmenu == key || K_hidden == key) {
					ITEM[key] = value
				} else {
					scream("unexpected key <"key"> (np2mu)")
					++errors
				}
			}
		}
	}
	sort_for_user(MENUS, NMENUS, OPT_SORT)
	if ("" == SORTED_DATA) {
		scream("np2mn can't sort 2")
		++errors
	}
	delete MENUS; NMENUS=0
	NMENUS = sort_criteria_cut(MENUS, OPT_SORT) 
	formatter(MENUS, NMENUS, FORMATTER)
	return errors
}
function kindlet_options(   x) { 
	x = (ITEM[K_exitmenu] ~ /^(0|false)$/ ? "e" : "") \
		(ITEM[K_hidden] ~ /^(1|true)$/ ? "h" : "")
	return ""==x ? "" : x SEP
}
function new_item() { 
	ITEM[K_name]=""; ITEM[K_action]=""; ITEM[K_params]=""; ITEM[K_priority]=0; ITEM[K_exitmenu]=""; ITEM[K_hidden]=""
}
function new_submenu() { 
	ITEM[K_name]=""; ITEM[K_priority]=0; ITEM[K_hidden]=""
}
function sort(ary, nary, sort_options,     tfl,i) { 
	tfl=TFL"-sort" rand()
	for (i=1; i<=nary; i++) {
		print ary[i] > tfl
	}
	close(tfl)
	SORTED_DATA = ""
	"/bin/busybox sort -t \""SEP"\" "sort_options" < \""tfl"\"" | getline SORTED_DATA
}
function sort_criteria(sortable_tag, opt_sort) { # {{{ build sortable data in accordance with user's sorting criteria
	if ("123" == opt_sort) {
		return sortable_tag SEP ITEM[K_priority] SEP 
	} else if ("ABC" == opt_sort || "abc" == opt_sort) {
		return sortable_tag SEP ITEM[K_name] SEP 
	} else return ""
}
function sort_criteria_cut(ary, opt_sort,   
	nary,p,x,i) {
	i = nary = split(SORTED_DATA, ary, /\n/)
	if (opt_sort ~ /^(123|ABC|abc)$/) {
		while (i > 0) {
			x = ary[i]
			p = index(x, SEP)
			p += index(substr(x, p+1), SEP)
			ary[i] = substr(x, p+1)
			--i
		}
	} else { 
	}
	return nary
}
function sort_for_user(ary, nary, opt_sort,    # {{{ 
	cherry,i) {
	cherry = SEP "0:"sprintf("%02x%02x%02x",K_items,0,K_name) SEP
	for (i = 1; i <= nary; i++) {
		if (index(ary[i], cherry)) {
			cherry = ary[i]
			delete ary[i]
			break
		}
	}
	if (i > nary) cherry="" 
	SORTED_DATA=""
	if ("123" == opt_sort) {
		sort(ary, nary, "-s -k1,1 -k2,2n")
	} else if ("ABC" == opt_sort || "abc" == opt_sort) {
		sort(ary, nary, "-s -k1,1 -k2,2")
	} else { # least likely usage, "fake" SORTED_DATA {{{
		SORTED_DATA=MENUS[1]
		for(i=2; i<=NMENUS; i++) {
			SORTED_DATA = SORTED_DATA "\n" MENUS[i]
		}
	}
	if ("" != cherry)
		SORTED_DATA = cherry SORTED_DATA
}
function submenuQ(snpath, last_action) { 
	return substr(snpath,1,length(snpath)-2) == substr(last_action,1,length(last_action)-2)
}
function work_record(sort_criteria, options, lvlsnpath, name, action) { 
	return sprintf("%s%s"SEP"%s%s"SEP"%s"SEP"%s",
		sort_criteria,
		"" == options ? 3 : 4, 
		options,
	       	lvlsnpath, name, action)
}
function npath (jpath, serial,   items,key,snpath,ary,nary,i) {
	items = sprintf("%02x", K_items)
	snpath = sprintf("%s%02x", items, serial) 
	jpath=substr(jpath,2,length(jpath)-2) 
	nary=split(jpath, ary, /\"items\"/)
	key=ary[nary]
	sub(/^.+,/, "", key);
	key=substr(key, 2, length(key)-2) 
	sub(/\".+$/, "", ary[nary]) 
	for(i=3; i<=nary; i++) { # drop <null> and invariant "items",0 [b]
		snpath=snpath items sprintf("%02x", substr(ary[i],2,length(ary[i])-2))
	}
	snpath = snpath sprintf("%02x", VALID_KEYS[key])
	return n_s2n(snpath) 
}
function n_n2s(npath,   x) { 
	x=substr(npath, 3, length(npath)-4) 
	sub(/(ff)+$/, "", x)
	return x
}
function n_s2n(snpath) { # {{{ convert short npath to npath (right-pad with f's)
    return xRESERVED substr(snpath FFS, 1, 44) xRESERVED 
}
function this_(key, snpath) { 
    return substr(snpath,1,length(snpath)-2) sprintf("%02x", key) 
}
function fit_button(left, right,   len,rlen,cut) { 
	len=MAX_LABEL_LEN - length(left)
	if (len < (rlen=length(right))) {
		right=substr(right,rlen-len+1)
		right=" .."substr(right,4)
	}
	return left right
}
function formatter(ary, nary, fmt_name,   fmt,i,x,n) { 
	if ("multiline" == fmt_name) {
		for (i=1; i<nary; i++) {
			x = ary[i]
			gsub(SEP,"\n",x)
			print x
		}
	} else if ("tbl" == fmt_name) {
		fmt="%-3.3s|%-20.20s|%-20.20s|%-33.33s\n"
		for (i=1; i<nary; i++) {
			n = split(ary[i], x, SEP)
			if (n-1 != x[1]) {
				scream("wrong record size <"x[1]"> in record # "i" (formatter)")
				++errors
				print ary[i]
			}
			if (4 == n) {
				printf fmt,   "", x[2], x[3], x[4]
			} else if (5 == n) {
				printf fmt, x[2], x[3], x[4], x[5]
			} else {
				scream("wrong argument count "n" in record # "i" (formatter)")
				++errors
				print ary[i]
			}
		}
	} else if ("tab" == fmt_name) {
		for (i=1; i<nary; i++) {
			x = ary[i]
			gsub(SEP,"\t",x)
			print x
		}
	} else {
		for (i=1; i<nary; i++)
			print ary[i]
	}
}
function shortpathname(pathname,   ary,nary) { 
	return (nary = split(pathname, ary, /\//)) \
		? ary[nary-1] "/" ary[nary] : pathname
}
function store_button_filepath(   KT532) { 
	if ("-" == FILEPATH_STORE_BUTTON) {
		return ""
	} else if ("" != FILEPATH_STORE_BUTTON) {
		return FILEPATH_STORE_BUTTON
	}
	KT532="/usr/share/webkit-1.0/pillow/javascripts/search_bar.js"
	if (0 < (getline < KT532)) {
		return (FILEPATH_STORE_BUTTON = KT532)
	} else {
		FILEPATH_STORE_BUTTON = "-"
		return ""
	}
}
function get_token() { 
	TOKEN = TOKENS[++ITOKENS] 
	return ITOKENS < NTOKENS
}
function parse_array(a1,   idx,ary,ret) { 
	idx=0
	ary=""
	get_token()
	if (TOKEN != "]") {
		while (1) {
			if (ret = parse_value(a1, idx)) {
				return ret
			}
			idx=idx+1
			ary=ary VALUE
			get_token()
			if (TOKEN == "]") {
				break
			} else if (TOKEN == ",") {
				ary = ary ","
			} else {
				report(", or ]", TOKEN ? TOKEN : "EOF")
				return 2
			}
			get_token()
		}
	}
	if (1 != BRIEF) {
		VALUE=sprintf("[%s]", ary)
	} else {
		VALUE=""
	}
	return 0
}
function parse_object(a1,   key,obj) { 
	obj=""
	get_token()
	if (TOKEN != "}") {
		while (1) {
			if (TOKEN ~ /^".*"$/) {
				key=TOKEN
			} else {
				report("string", TOKEN ? TOKEN : "EOF")
				return 3
			}
			get_token()
			if (TOKEN != ":") {
				report(":", TOKEN ? TOKEN : "EOF")
				return 4
			}
			get_token()
			if (parse_value(a1, key)) {
				return 5
			}
			obj=obj key ":" VALUE
			get_token()
			if (TOKEN == "}") {
				break
			} else if (TOKEN == ",") {
				obj=obj ","
			} else {
				report(", or }", TOKEN ? TOKEN : "EOF")
				return 6
			}
			get_token()
		}
	}
	if (1 != BRIEF) {
		VALUE=sprintf("{%s}", obj)
	} else {
		VALUE=""
	}
	return 0
}
function parse_value(a1,a2,   jpath,ret,x) { 
	jpath=(a1!="" ? a1 "," : "") a2 # "${1:+$1,}$2"
	if (TOKEN == "{") {
		if (parse_object(jpath)) {
			return 7
		}
	} else if (TOKEN == "[") {
		if (ret = parse_array(jpath)) {
			return ret
	}
	} else if (TOKEN ~ /^(|[^0-9])$/) {
		report("value", TOKEN!="" ? TOKEN : "EOF")
		return 9
	} else {
		VALUE=TOKEN
	}
	if (! (1 == BRIEF && ("" == jpath || "" == VALUE))) {
		x=sprintf("[%s]\t%s", jpath, VALUE)
		if(0 == STREAM) {
			JPATHS[++NJPATHS] = x
		} else {
			print x
		}
	}
	return 0
}
function parse(   ret) { 
	get_token()
	if (ret = parse_value()) {
		return ret
	}
	if (get_token()) {
		report("EOF", TOKEN)
		return 11
	}
	return 0
}
function report(expected, got) { 
	scream("expected <" expected "> but got <" got "> at input token " ITOKENS, FILENAME)
}
function reset() { 
	TOKEN=""; delete TOKENS; NTOKENS=ITOKENS=0
	VALUE=""
}
function scream(msg, originator) { 
	if ("" == originator)
		originator=PRODUCTNAME
	FAILS[originator] = FAILS[originator] (FAILS[originator]!="" ? "\n" : "") msg
	msg = originator ": " msg
	print msg > "/dev/stderr"
	print msg >> SCREAM_LOG
}
function tokenize(a1,   pq,ESCAPE,CHAR,STRING,NUMBER,KEYWORD,SPACE) { 
	ESCAPE="(\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})"
	CHAR="[^[:cntrl:]\\\"]"
	STRING="\"" CHAR "*(" ESCAPE CHAR "*)*\""
	NUMBER="-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?"
	KEYWORD="null|false|true"
	SPACE="[[:space:]]+"
	pq="/p/r/e/s/e/r/v/e/q/u/o/t/e/" rand() 
	gsub(/\\"/, pq, a1) 
        gsub(STRING "|" NUMBER "|" KEYWORD "|" SPACE "|.", "\n&", a1)
	gsub(pq, "\\\"", a1) 
        gsub("\n" SPACE, "\n", a1)
	sub(/^\n/, "", a1)
	ITOKENS=0 
	return NTOKENS = split(a1, TOKENS, /\n/)
}
UNPACK
}
log "start pid($$)"
readonly TFL="/var/tmp/$PRODUCTNAME-$$"
readonly EMIT="$TFL-emit"
trap handler EXIT HUP INT QUIT TERM KILL
handler () {
  local -
  set +f
  cd /var/tmp && rm -f "$TFL"* 2>/dev/null
  scream "$PRODUCTNAME exit $EXITSTATUS `date`"
  cat "$SCREAM_LOG" >&2
  log "end pid($$)"
}
starter=`init "$@"` 
log "starter($starter)"
proc=':' 
eval "$starter" >/dev/null 
log "proc($proc)"
log "engine version 2"
send_config 
test_applet uninstall >/dev/null
	unpack > "$TFL.awk" &&
	< /dev/null awk -f "$TFL.awk" \
		-v SCRIPTPATH="$SCRIPTPATH" \
		-v FORMATTER=${opt_formatter:-multiline} \
		-v OPT_SORT=$opt_sort \
		-v EXTENSIONDIR="$EXTENSIONDIR"
	t=$?
[ -z "$EXITSTATUS" ] && EXITSTATUS=$t
log "exit status($EXITSTATUS)"
exit $EXITSTATUS
