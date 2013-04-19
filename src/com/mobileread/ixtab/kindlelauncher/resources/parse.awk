#!/usr/bin/awk -f
# aloop-v2.awk - version 20130419,a stepk
BEGIN { 
	VERSION="20130419,a"
	ERRORS = BAILOUT = CACHE_SENT = CACHE_INVALID = SERIAL_PARSED_OK = 0
	SELF_BUTTONS_INSERT = SELF_BUTTONS_FILTER = SELF_BUTTONS_APPEND = ""
	if (1 < ARGC) {
		print "usage!" > "/dev/stderr"
		BAILOUT=1
	       	exit 
	}
	while (0 < getline < "/dev/stdin") {
		if (NF) { ARGV[++ARGC]=$0 } else break
	}
	srand() 
	RS="n/o/m/a/t/c/h" substr(rand(),3)
	init()
	if (0 == cache_send(CACHEPATH)) { 
		close("/dev/stdout")
		CACHE_SENT=1
		exit 
	}
	config_send("/dev/stdout")
	if (1 >= ARGC) {
		ARGC = find_menu_fullpathnames(EXTENSIONDIR, ARGV, ARGC-1)
		if (1 > ARGC && "" != SCRIPTPATH) {
			ARGV[ARGC] = ""
			++ERRORS
			++CACHE_INVALID
			SELF_BUTTONS_INSERT = SELF_BUTTONS_INSERT ",+add_ext"
			SELF_BUTTONS_FILTER = SELF_BUTTONS_FILTER ",-sort_menu"
		}
		if("" != ARGV[ARGC]) ++ARGC 
	}
	BRIEF=1; 
	STREAM=0;
	delete FAILS
}
{ 
	reset() 
	SVNJPATHS = 0+NJPATHS
	tokenize($0) 
	if (0 == (status = parse())) { 
		++VALID_PARSED_FILES 
		status = jp2np(JPATHS, NJPATHS, VALID_PARSED_FILES, FILENAME) 
	} else { 
		while(NJPATHS > SVNJPATHS) {
			delete JPATHS[NJPATHS--]
		}
	}
	if (status) ++ERRORS
}
END { 
	if (BAILOUT || CACHE_SENT) {
		teardown()
		exit(BAILOUT)
	}
	json_emit_self_menu_and_parsing_errors(0+PARENT_ERRORS) 
	delete MENUS; NMENUS=0
	if (0 != np2mn(NPATHS, NNPATHS)) {
		scream("error (np2mn)")
		++ERRORS
	} else {
		if (0 != formatter(MENUS, NMENUS, OPT_FMT, "/dev/stdout")) {
			scream(SenCantSendToKindlet)
			++ERRORS
		}
		close("/dev/stdout")
		if (0 != cache_save(CACHEPATH)) {
			scream(SenCantWriteCache)
			++ERRORS
		}
	}
	teardown()
	exit(ERRORS)
}
function init(   x) { 
if ("" == EXTENSIONDIR) EXTENSIONDIR="/mnt/us/extensions" 
if ("" == PRODUCTNAME) PRODUCTNAME="KUAL"
if ("" == CONFIGFILE) CONFIGFILE=PRODUCTNAME".cfg" 
if ("" == (CONFIGPATH = config_full_path())) CONFIGPATH = "/dev/null" 
config_read(CONFIGPATH)
CONFIG["NC bbawk"]="/bin/busybox awk"
CONFIG["NC bbfind"]="/bin/busybox find"
CONFIG["NC bbsort"]="/bin/busybox sort"
if (""==OPT_FMT) OPT_FMT="multiline"
if (""==OPT_SORT) OPT_SORT= "" != (x = config_get("sort_mode")) ? x : "ABC"
delete COUNTER
COUNTER["nameNull"]=0
SEP="\x01"
CACHEPATH = (x = "/var/tmp/" PRODUCTNAME) ".cache"
if (""==SCREAM_LOG) SCREAM_LOG = x ".log"
SCRIPTPATH = x ".sh"
VALID_KEYS["action"]=K_action=0x00  
VALID_KEYS["priority"]=K_priority=0x01 
VALID_KEYS["params"]=K_params=0x02
VALID_KEYS["exitmenu"]=K_exitmenu=0x03
VALID_KEYS["checked"]=K_checked=0x04
VALID_KEYS["reload"]=K_reload=0x05 
VALID_KEYS["hidden"]=K_hidden=0x06 
VALID_KEYS["name"]=K_name=0x07 
VALID_KEYS["items"]=K_items=0xff 
VALID_KEYS["ERROR"]="??"
sK_name=sprintf("%02x", K_name)
xRESERVED=0xff
sRESERVED="ff"
sRESERVED_len=2
NPATH_len=48
FFS="ffffffffffffffffffffffffffffffffffffffffffffffff" 
NBSP0="&nbsp;"
NBSP1="\xC2\xA0" 
MMRK="\xE2\x96\xB6" 
CROSS="\xC3\x97" 
ATTN="\xE2\x97\x8F" 
MAX_LABEL_LEN=40
XenErrSyntax="Syntax"
XenParentErrors="Startup error"
SenCantChangeSortMode="can't change sorting mode"
SenCantFindMenuFiles="can't find menu files"
SenNoExtensionsFound=ATTN" No extensions found"
SenCantSendToKindlet="can't send menu to Kindlet"
SenCantSort="can't sort"
SenCantWriteCache="can't cache menu"
TFL="/var/tmp/--" PRODUCTNAME "--" 
KINDLET["TRAIL"]=1
KINDLET["STATUS"]=2
}
function teardown(   i) { 
	system("cd /var/tmp && rm -f \"" TFL "\"* 2>/dev/null")
}
function cache_save(outfile,   # {{{ << globals CACHE_INVALID,MENUS,NMENUS,CONFIG; return 
	errors) {
	if (CACHE_INVALID) {
		system("rm -f '"CACHEPATH"'")
		return 0
	}
	printf "" >outfile
	errors += config_send(outfile)
	errors += formatter(MENUS, NMENUS, "multiline", outfile)
	if (-1 == close(outfile))
		++errors
	return errors
}
function cache_send(cachepath,   # {{{ << globals MENUS,NMENUS,CONFIG; return 
	slurp) {
	if (0 <= (getline slurp < cachepath))
		close(cachepath)
	if ("" != slurp) {
		printf "%s", slurp
		return 0
	}
	return 1
}
function config_full_path(create, 
	i,ary,nary,x) {
	nary = split(EXTENSIONDIR, ary, /;/)
	for (i = 1; i <= nary; i++) {
		cfp = ary[i]"/"CONFIGFILE
		if (0 <= (getline x < cfp)) {
			close(cfp)
			break
		}
	}
	if ("" != x)
		return cfp
	if ("create" == create) {
		cfp=ary[1]"/"CONFIGFILE
		"date" | getline x
		close("date")
		print "# "CONFIGFILE" - created on "x > cfp
		close(cfp)
		return cfp
	}
	return ""
}
function config_get(key) { 
	return key in CONFIG ? CONFIG[key] : ""
}
function config_read(configfullpath, 
	ary,nary,slurp,k,v,p,count) {
	if (0 <= (getline slurp < configfullpath))
		close(configfullpath)
	if ("" != slurp) {
		nary = split(slurp, ary, /\n/)
		if (nary) --nary 
		for (i = 1; i <= nary; i++) {
			if (ary[i] ~ "^\\s*"PRODUCTNAME"_\\w+=") {
				k = ary[i]
				k = substr(k,1+index(k,"_"))
				p = index(k, "=")
				v = substr(k,p+1)
				gsub(/^"|"$/,"",v) 
				CONFIG[substr(k,1,p-1)] = v
				++count 
			}
		}
	}
	return 0+count
}
function config_send(outfile,   k,n) { 
	for (k in CONFIG)
		if(k !~ /^NC/)
			++n
	printf "%d\n%s\n", 1+n, VERSION >>outfile
	for (k in CONFIG)
		if(k !~ /^NC/)
			print PRODUCTNAME"_"k"=\""CONFIG[k]"\"" >>outfile
}
function escs2chars(s) { 
	if (!match(s,/\\/)) return s
	gsub(/\\\\/,"\x01",s) 
	gsub(/\\\"/,"\"",s)
	gsub(/\\b/,"\b",s)
	gsub(/\\f/,"\f",s)
	gsub(/\\n/,"\n",s)
	gsub(/\\r/,"\r",s)
	gsub(/\\t/,"\t",s)
	gsub(/\x01/,"\\",s) 
	return s
}
function find_menu_fullpathnames(dirs, return_ary, base,  
	pj,nj,follow,depth,paths,slurp,i,ary,nary,menu,cmd) {
	follow = "true" == config_get("nofollow") ? "" : "-follow"
	depth = config_get("search_depth")
	depth =	"-maxdepth " (""==depth ? 2 : 0+depth)
	paths = config_get("search_exclude_paths")
	paths = "-path "dirs"/" (""==paths ? "system" : paths)
	gsub(/;/," -o -path "dirs"/",paths) 
	cmd = config_get("NC bbfind")" "dirs" "follow" "depth" \\( "paths" \\) \\( -prune -type f \\) -o \\( -name config.xml -type f \\) 2>/dev/null"
	cmd | getline slurp
	if (close(cmd)) {
		scream(SenCantFindMenuFiles)
		return base
	}
	nary = split(slurp, ary, /\n/)
	if (nary) --nary 
	for (i=1; i <= nary; i++) {
		menu = pathjson = pathxml = ""
		if (0 <= (getline slurp < ary[i])) 
			close(ary[i])
		if (slurp ~ /<extension>.+<\/extension>/) { 
		    if (match(slurp, /<menu\>[^>]+\<type="json"[^>]*>[^<]+<\/menu>/)) { 
			    slurp = substr(slurp,RSTART,RLENGTH-7) 
			    menu = substr(slurp,1+index(slurp,">")) 
		    }
		}
		if ("" != menu) {
			if ("^/" !~ menu) { 
				match(ary[i], /^.*\//)
				menu = substr(ary[i],RSTART,RLENGTH) menu 
			}
			if (0 <= (getline x < menu)) {
				return_ary[++base] = menu
				close(menu)
			}
		}
	}
	return base
}
function format_action_item(action, params,   
	p,cmd) {
	p = index(action, ";")
	cmd = substr(action,p+1)
	if (cmd in KINDLET) {
		cmd = KINDLET[cmd]
		return substr(action,1,p)"#"cmd";"params
	}
	return (action) ("" != params ? " " : "") (params)
}
function format_action_submenu(level, items_path) { 
	return "^" (level+1) ":" npath_wo_reserved(items_path) ".." sK_name "$"
}
function json_emit_self_menu_and_parsing_errors(parent_errors,     
	json,name,sname,msg,ary,nary) {
	json=json_self_menu(SELF_BUTTONS_INSERT, SELF_BUTTONS_FILTER, SELF_BUTTONS_APPEND) 
	if (parent_errors) {
		++ERRORS
		json=json "," json_error_button(fit_button(ATTN" "XenParentErrors, ""))
	}
	for(name in FAILS) {
		json=json "," json_error_button(fit_button(ATTN" "XenErrSyntax" ", shortpathname(name)))
	} 
	if (json) { 
		name = PRODUCTNAME
		if (ERRORS)
			name = name " " ATTN " " ERRORS
		json="{\"items\":[{\"name\":\"" name \
			"\",\"items\":[" \
			substr(json,2) "]}]}"
		delete TOKENS; NTOKENS = ITOKENS = 0
		tokenize(json)
		parse()
		jp2np(JPATHS, NJPATHS, 0, "/var/tmp/.")
	}
}
function json_error_button(message) {  
	return "{\"priority\": -1000, \"name\": \"" \
		message \
		"\", \"action\": \"TRAIL\", \"params\": \"[more info in "PRODUCTNAME" log]\", \"exitmenu\": false}"
}
function json_self_menu(extra_insert, standard_filter, extra_append,   
	json,show,b,ary,nary,verb,btnpath,bak,x,y,slurp) {
	if (0 == (show = config_get("show_KUAL_buttons"))) 
		return ""
	if ("" == show) show="2 3 99" 
show = "0 " show 
	standard_filter = ","standard_filter","
	ORIGIN = PRODUCTNAME " menu" 
	json = ""
	if (nary = split(extra_insert, ary, /,/)) {
		for (b = 1; b <= nary; b++) {
			if ("+add_ext" == ary[b]) {
				json = json "," json_self_menu_button( \
				     SenNoExtensionsFound, \
				     "TRAIL", "help @ http://bit.ly/UW3v8V", \
				     -200, "false")
  			}
  		}
	}
	if (nary = split(show, ary, /\s+/)) {
		for (b = 1; b <= nary; b++) {
			if (1 == ary[b]) {
			} else if (2 == ary[b] && ! index(standard_filter,",-sort_menu," ) ) {
				verb = OPT_SORT ~ /^ABC|abc$/ ? "123" : "ABC"
x = "BEGIN{nf=1} /^\\\\s*KUAL_sort_mode=/{sub(/=.*/,\\\"=\\\\\\\""verb"\\\\\\\"\\\");nf=0} {print} END{if(nf) print \\\"KUAL_sort_mode=\\\\\\\""verb"\\\\\\\"\\\"}"
x = "awk '"x"' '"CONFIGPATH"'"
x = "s=$("x") && [ 0 != ${#s} ] && echo \\\"$s\\\" >'"CONFIGPATH"'"
x = "[ -r '"CONFIGPATH"' ] || echo \\\"# "CONFIGPATH" - created on `date`\\\" >'"CONFIGPATH"';" x
				json=json "," json_self_menu_button( \
					"Sort menu "verb" on restart", \
					x, \
					"", 2, "false", "true")
			} else if (3 == ary[b]) {
x = "mv '"SCREAM_LOG"' \\\"/mnt/us/documents/"PRODUCTNAME"-`date -u -Iminutes | sed s/:/./g`.txt\\\";dbus-send --system /default com.lab126.powerd.resuming int32:1"
				json=json "," json_self_menu_button( \
					"Save and reset "PRODUCTNAME" log", \
					x, \
					"", 3, "false", "true")
			} else if (99 == ary[b]) {
				json=json "," json_self_menu_button( \
					CROSS" Quit", \
					":", \
					"", 99)
			}
			else if (0 == ary[b]) {
				json=json "," json_self_menu_button( \
					"Clear cache on restart (temp)", \
					"rm -f '"CACHEPATH"'", \
					"", 0, "false", "true")
			}
		}
	}
	return json
}
function json_self_menu_button(name, action, params, priority, exitmenu, checked, reload, hidden) { 
	return "{\"name\": \"" name "\"" \
	", \"action\": \"" action "\"" \
	("" != params ? ", \"params\": \"" params "\"" : "") \
	("" != priority ? ", \"priority\": " priority : "") \
	("" != exitmenu ? ", \"exitmenu\": " exitmenu : "") \
	("" != checked ? ", \"checked\": " checked : "") \
	("" != reload ? ", \"reload\": " reload : "") \
	("" != hidden ? ", \"hidden\": " hidden : "") \
	"}"
}
function jp2np(ary, size, serial, menufilepathname,   
	i,x,npath,apath,jpath,key,value,level,errors) {
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
		if (key !~ /^(name|action|params|priority|exitmenu|hidden|checked|reload)$/) {
			continue
		}
		key=VALID_KEYS[key]
		x = jpath
		level = gsub(/"items",/, "&", x)
		if (0 == level) {
			continue
		}
		--level 
		npath = npath_new(jpath, serial)
		if (2 == gsub(/^"|"$/, "", value)) { 
			value = escs2chars(value) 
		}
		if (K_name == key) {
			gsub(NBSP0, NBSP1, value)
		} else if (K_action == key) {
			value=apath ";" value
		}
		NPATHS[++NNPATHS]=level SEP npath SEP key SEP value
	}
	return errors
}
function np2mn(ary, size,    
	i,slurp,lines,nlines,iline,errors,
	npary,level,npath,key,value,options,
	npath_s_this_items,select_level,needle,snpath,last_action  ) {
	errors=0
	sort(ary, size, "-k2."(1+sRESERVED_len)",2 -k1,1 -k3,3") 
	if ("" == SORTED_DATA) {
		scream("np2mn can't sort 1")
		++errors
	} else {
		sort_criteria_init(OPT_SORT) 
		new_item()
		new_submenu()
	       	select_level[0] = npath_wo_reserved(npath_new("",0))
		if (0 < (nlines = split(SORTED_DATA,lines, /\n/))) {
			for(iline = 1; iline < nlines; iline++) {
				split(lines[iline], npary, SEP)
				level = npary[1]; npath = npary[2]; key = npary[3]; value = npary[4]
				snpath = npath_get_short(npath)
				if (K_action == key) {
					ITEM[key] = value
					last_action = snpath
				} else if (K_name == key) {
					if ("" == value) 
						value = "??"(++COUNTER["nameNull"])
					if (submenu_pathQ(snpath, last_action)) { 
						ITEM[key]=value 
						sortable_tag=select_level[level] 
						MENUS[++NMENUS] = work_record( \
							sortable_record(sortable_tag, OPT_SORT),
							kindlet_options(),
							level,npath_s_this_(K_name, snpath), 
							ITEM[K_name],
							format_action_item(ITEM[K_action], ITEM[K_params]))
						new_item()
					} else { 
						ITEM[key]=value" "MMRK 
						npath_s_this_items = npath_s_this_(K_items, snpath) 
						select_level[level+1] = npath_wo_reserved(npath_padded(npath_s_this_items))
						sortable_tag = select_level[level] 
						MENUS[++NMENUS] = work_record( \
							sortable_record(sortable_tag, OPT_SORT),
							kindlet_options(),
							level,snpath,
							ITEM[K_name],
							format_action_submenu(level, npath_s_this_items))
						new_submenu()
					}
				} else if (K_priority == key || K_params == key || K_exitmenu == key || K_checked == key || K_reload == key || K_hidden == key) {
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
	return errors
}
function kindlet_options(   x) {  # {{{ 
	x = (ITEM[K_exitmenu] ~ /^(0|false)$/ ? "e" : "") \
		(ITEM[K_checked] ~ /^(1|true)$/ ? "c" : "") \
		(ITEM[K_reload] ~ /^(1|true)$/ ? "r" : "") \
		(ITEM[K_hidden] ~ /^(1|true)$/ ? "h" : "")
	return "" == x ? "" : x SEP
}
function menu_children(matcher, ary, nary,  
	i,list) {
	matcher = SEP substr(matcher, 2, length(matcher)-2) SEP 
	for (j = 1; j <= nary; j++) {
		if (ary[j] ~ matcher) {
			list = list " " j
		}
	}
	return substr(list, 2)
}
function new_item() { 
	ITEM[K_name] = ITEM[K_action] = ITEM[K_params] =  ITEM[K_exitmenu] = ITEM[K_checked] = ITEM[K_reload] = ITEM[K_hidden] = ""; ITEM[K_priority] = 0;
}
function new_submenu() { 
	ITEM[K_name] = ITEM[K_hidden] = ""; ITEM[K_priority] = 0;
}
function npath_from_jpath(jpath, serial,   
	items,key,snpath,ary,nary,i) {
	items = sprintf("%02x", K_items)
	snpath = npath_reserved() sprintf("%s%02x", items, serial)
	jpath=substr(jpath,2,length(jpath)-2) 
	nary=split(jpath, ary, /\"items\"/)
	key=ary[nary]
	sub(/^.+,/, "", key);
	key=substr(key, 2, length(key)-2) 
	sub(/\".+$/, "", ary[nary]) 
	for(i=2; i<=nary; i++) { 
		snpath = snpath items sprintf("%02x", substr(ary[i],2,length(ary[i])-2))
	}
	snpath = snpath sprintf("%02x", VALID_KEYS[key])
	return npath_padded(snpath)
}
function npath_new(jpath, serial, 
	key,npath,snpath) {
	key = jpath SEP serial
	if (key in NPATH_MAP)
		return NPATH_MAP[key]
	npath = snpath = npath_from_jpath(jpath, serial)
	sub(/(ff)+$/, "", snpath) 
	return NPATH_MAP[key] = NPATH_MAP[npath_wo_reserved(npath)] = NPATH_MAP[npath_wo_reserved(snpath)] = npath
}
function npath_get(path, 
	upath,npath) {
	upath = npath_wo_reserved(path)
	return upath in NPATH_MAP ? NPATH_MAP[upath] : (npath_reserved() "NON-EXISTENT:npath_get("path")")
}
function npath_get_short(path, 
	upath,snpath) {
	upath = npath_wo_reserved(path)
	if (upath in NPATH_MAP) {
		snpath = NPATH_MAP[upath]
		sub(/(ff)+$/, "", snpath)
		return snpath
	}
	return (npath_reserved() "NON-EXISTENT:npath_get_short("path")")
}
function npath_padded(path) { 
	return substr(path FFS, 1, NPATH_len)
}
function npath_reserved(path) { 
	return "" == path ? sRESERVED : substring(path, 1, sRESERVED_len)
}
function npath_wo_reserved(path,   x) { 
	return substr(path,1+sRESERVED_len)
}
function npath_s_KUAL_menu() { 
	return npath_get_short(npath_new("[\"[items\",0,\"items\",0,\"name\"]", 0))
}
function npath_s_this_(key, snpath) { 
    return substr(snpath,1,length(snpath)-2) sprintf("%02x", key) 
}
function sort(ary, nary, sort_options,   
	tfl,i,cmd,rec) {
	SORTED_DATA = ""
	if (0 == nary) return
	tfl=TFL"-sort" substr(rand(),3)
	for (i=1; i<=nary; i++) {
		if (rec = ary[i]) print rec > tfl
	}
	close(tfl)
	cmd = config_get("NC bbsort")" -t \""SEP"\" "sort_options" < \""tfl"\""
	cmd | getline SORTED_DATA
	if (close(cmd))
		scream(SenCantSort)
}
function sort_criteria_init(opt_sort) { 
	if ("ABC" == toupper(opt_sort)) {
		SORT_CRITERIA=1
		SORT_FIELDS=2
	} else if ("ABC!" == toupper(opt_sort)) {
		SORT_CRITERIA=2
		SORT_FIELDS=2
	} else if ("123" == toupper(opt_sort)) {
		SORT_CRITERIA=3
		SORT_FIELDS=2
	} else {
		SORT_CRITERIA = SORT_FIELDS = 0
	}
}
function sortable_record(sortable_tag, opt_sort) { 
	if (1 == SORT_CRITERIA || 2 == SORT_CRITERIA ) { 
		return sortable_tag SEP ITEM[K_name] SEP 
	} else if (3 == SORT_CRITERIA) { 
		return sortable_tag SEP ITEM[K_priority] SEP 
	}
	return ""
}
function sort_criteria_cut(ary, opt_sort,   
	nary,p,x,i) {
	i = nary = split(SORTED_DATA, ary, /\n/)
	if (0 < SORT_CRITERIA) {
	       if(2 == SORT_FIELDS) {
			while (i > 0) {
				x = ary[i]
				p = index(x, SEP)
				p += index(substr(x, p+1), SEP)
				ary[i] = substr(x, p+1)
				--i
			}
		} else {
			scream("SORT_FIELDS != 2 not implemented")
			++ERRORS
		}
	} else { 
	}
	return nary
}
function sort_for_user(ary, nary, opt_sort,    # {{{ 
	cherry,i,ary0,nary0,non_zero,rec) {
	cherry = SEP "0:" npath_wo_reserved(npath_s_KUAL_menu()) SEP
	for (i = 1; i <= nary; i++) {
		if (index(ary[i], cherry)) {
			cherry = ary[i]
			ary[i] = 0 
			break
		}
	}
	if (i > nary) {
		cherry="" 
		scream("can't select "PRODUCTNAME" menu entry")
	}
	SORTED_DATA=""
	if (1 == SORT_CRITERIA) { 
		nary0 = 0
		non_zero = "" 
		for (i = 1; i <= nary; i++) {
			if (rec = ary[i]) {
				if (rec ~ SEP"0:")
					ary0[++nary0] = rec
				else
					non_zero = non_zero "/" i
			}
		}
		sort(ary0, nary0, "-s -f -k1,1 -k2,2")
		non_zero = non_zero "/"
		for (i = 1; i <= nary; i++) {
			if (index(non_zero, "/"i"/"))
				SORTED_DATA = SORTED_DATA "\n" ary[i]
		}
	} else if (3 == SORT_CRITERIA) { 
		sort(ary, nary, "-s -k1,1 -k2,2n")
	} else if (2 == SORT_CRITERIA) { 
		sort(ary, nary, "-s -f -k1,1 -k2,2")
	} else { 
		SORTED_DATA=MENUS[1]
		for(i=2; i<=NMENUS; i++) {
			SORTED_DATA = SORTED_DATA "\n" MENUS[i]
		}
	}
	if ("" != cherry) {
		SORTED_DATA = cherry "\n" SORTED_DATA
	}
}
function submenu_actionQ(action) { 
	return "^" == substr(action, 1, 1) && "$" == substr(action, length(action))
}
function submenu_pathQ(snpath, last_action,     x,y) { 
	x = npath_wo_reserved(snpath)
	y = npath_wo_reserved(last_action)
	return substr(x,1,length(x)-2) == substr(y,1,length(y)-2)
}
function work_record(sortable_record, options, level,snpath, name, action, 
	lvlsnpath) {
	lvlsnpath = level ":" npath_wo_reserved(snpath)
	return sprintf("%s%s"SEP"%s%s"SEP"%s"SEP"%s",
		sortable_record, 
		"" == options ? 3 : 4, 
		options,
	       	lvlsnpath, name, action)
}
function fit_button(left, right,   len,rlen,cut) { 
	len=MAX_LABEL_LEN - length(left)
	if (len < (rlen=length(right))) {
		right=substr(right,rlen-len+1)
		right=" .."substr(right,4)
	}
	return left right
}
function formatter(ary, nary, fmt_name, outfile,   # {{{ 
	fmt,i,rec,x,n,errors) {
	errors = 0
	if ("multiline" == fmt_name) {
		for (i = 1; i <= nary; i++) {
			if (rec = ary[i]) {
				gsub(SEP,"\n",rec)
				print rec >>outfile
			}
		}
	} else if ("tbl" == fmt_name) {
		fmt="%-3.3s|%-20.20s|%-20.20s|%-33.33s\n"
		for (i = 1; i <= nary; i++) {
		       	if (rec = ary[i]) {
				n = split(rec, x, SEP)
				if (n-1 != x[1]) {
					scream("wrong record size <"x[1]"> in record # "i" (formatter)")
					++errors
					print rec >>outfile 
				}
				if (4 == n) {
					printf fmt,   "", x[2], x[3], x[4]
				} else if (5 == n) {
					printf fmt, x[2], x[3], x[4], x[5]
				} else {
					scream("wrong argument count "n" in record # "i" (formatter)")
					++errors
					print rec >>outfile 
				}
			}
		}
	} else if ("tab" == fmt_name) {
		for (i = 1; i <= nary; i++) {
			if (rec = ary[i]) {
				gsub(SEP,"\t",rec)
				print rec >>outfile
			}
		}
	} else {
		for (i = 1; i <= nary; i++) {
			if (rec = ary[i])
				print rec >>outfile
		}
	}
	return errors
}
function shortpathname(pathname,   ary,nary) { 
	return (nary = split(pathname, ary, /\//)) \
		? ary[nary-1] "/" ary[nary] : pathname
}
function store_button_filepath(   KT532,ret) { 
	if ("-" == FILEPATH_STORE_BUTTON) {
		return ""
	} else if ("" != FILEPATH_STORE_BUTTON) {
		return FILEPATH_STORE_BUTTON
	}
	KT532="/usr/share/webkit-1.0/pillow/javascripts/search_bar.js"
	if (0 <= (getline < KT532)) {
		ret = FILEPATH_STORE_BUTTON = KT532
		close(KT532)
	} else {
		FILEPATH_STORE_BUTTON = "-"
		ret = ""
	}
	return ret
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
function parse_value(a1, a2,   jpath,ret,x) { 
	jpath=(a1!="" ? a1 "," : "") a2
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
function report(expected, got,   i,from,to,context) { 
	from = ITOKENS - 10; if (from < 1) from = 1
	to = ITOKENS + 10; if (to > NTOKENS) to = NTOKENS
	for (i = from; i < ITOKENS; i++)
		context = context sprintf("%s ", TOKENS[i])
	context = context "<<" got ">> "
	for (i = ITOKENS + 1; i <= to; i++)
		context = context sprintf("%s ", TOKENS[i])
	scream("expected <" expected "> but got <" got "> at input token " ITOKENS "\n" context,
	       "" != ORIGIN ? ORIGIN : FILENAME)
}
function reset() { 
	TOKEN=""; delete TOKENS; NTOKENS=ITOKENS=0
	VALUE=""
}
function scream(msg, origin, 
	x) {
	if ("" == origin)
		origin=PRODUCTNAME
	if (! SCREAMED_BEFORE) {
		++SCREAMED_BEFORE
		"date" | getline x
		close("date")
		printf "\n%s: ***** started on %s", PRODUCTNAME, x >> SCREAM_LOG
	}
	FAILS[origin] = FAILS[origin] (FAILS[origin]!="" ? "\n" : "") msg
	msg = origin ": " msg
	print msg >> SCREAM_LOG
}
function tokenize(a1,   pq,pb,ESCAPE,CHAR,STRING,NUMBER,KEYWORD,SPACE) { 
	SPACE="[[:space:]]+"
	gsub(/\"[^[:cntrl:]\"\\]*((\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})[^[:cntrl:]\"\\]*)*\"|-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?|null|false|true|[[:space:]]+|./, "\n&", a1)
	gsub("\n" SPACE, "\n", a1)
	sub(/^\n/, "", a1)
	ITOKENS=0 
	return NTOKENS = split(a1, TOKENS, /\n/)
}
