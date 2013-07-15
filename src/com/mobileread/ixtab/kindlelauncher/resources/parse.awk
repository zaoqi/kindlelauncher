#!/usr/bin/awk -f
# aloop-v2.awk - version 20130708,a stepk
BEGIN {
VERSION="20130716,a"
ERRORS = BAILOUT = CACHE_SENT = IN_MEMORY_CACHE_INVALID = PARSED_OK_COUNTER = 0
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
} else {
config_send("/dev/stdout")
}
if (1 >= ARGC) {
ARGC = find_menu_fullpathnames(EXTENSIONDIR, ARGV, ARGC-1)
if (1 > ARGC && "" != SCRIPTPATH) {
ARGV[ARGC] = ""
++ERRORS
++IN_MEMORY_CACHE_INVALID
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
match(FILENAME, /(\/[^\/]+){2,2}$/)
x = substr(FILENAME, RSTART+1, RLENGTH)
LOADED_EXTENSIONS[substr(x, 1, index(x, "/") - 1)] = 1
} else {
while(NJPATHS > SVNJPATHS) {
delete JPATHS[NJPATHS--]
}
}
if (status) ++ERRORS
}
END {
if (BAILOUT) {
teardown()
exit(BAILOUT)
}
if (CACHE_SENT) {
if (0 != cache_update()) {
scream(SenCantUpdateCache)
++ERRORS
}
teardown()
exit(ERRORS)
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
if (0 != cache_save()) {
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
CONFIG["model"] = get_model()
x = "/bin/busybox "
CONFIG["NCbbawk"] = x"awk"
CONFIG["NCbbfind"] = x"find"
CONFIG["NCbbmd5sum"] = x"md5sum"
CONFIG["NCbbsort"] = x"sort"
if (""==OPT_FMT) OPT_FMT="multiline"
if (""==OPT_SORT) OPT_SORT= "" != (x = config_get("sort_mode")) ? x : "ABC"
delete COUNTER
COUNTER["nameNull"]=0
SEP="\x01"
CACHEPATH = (x = "/var/tmp/" PRODUCTNAME) ".cache"
if (""==SCREAM_LOG) SCREAM_LOG = x ".log"
SCRIPTPATH = x ".sh"
MBXPATH = x ".mbx"
system("rm -f '"MBXPATH"'")
SELF_MENU_NAME = PRODUCTNAME
VALID_KEYS["action"]=K_action=0x00
VALID_KEYS["internal"]=K_internal=0x01
VALID_KEYS["params"]=K_params=0x02
VALID_KEYS["priority"]=K_priority=0x03
VALID_KEYS["if"]=K_if=0x04
VALID_KEYS["exitmenu"]=K_exitmenu=0x05
VALID_KEYS["checked"]=K_checked=0x06
VALID_KEYS["refresh"]=K_refresh=0x07
VALID_KEYS["status"]=K_status=0x08
VALID_KEYS["date"]=K_date=0x09
VALID_KEYS["hidden"]=K_hidden=0x0a
VALID_KEYS["name"]=K_name=0x0b
VALID_KEYS["items"]=K_items=0xff
VALID_KEYS["ERROR"]="??"
sK_name=sprintf("%02x", K_name)
sK_items=sprintf("%02x", K_items)
xRESERVED=0xff
sRESERVED="ff"
sRESERVED_len=2
NPATH_len=48
FFS="ffffffffffffffffffffffffffffffffffffffffffffffff"
NBSP0="&nbsp;"
NBSP1="\xC2\xA0"
CROSS="\xC3\x97"
ATTN="\xE2\x97\x8F"
MAX_LABEL_LEN=40
XenErrSyntax="Syntax"
XenParentErrors="Startup error"
XenNoExtensionsFound=ATTN" No extensions found"
SenCantChangeSortMode="can't change sorting mode"
SenCantFindMenuFiles="can't find menu files"
SenCantHashCache="can't hash cache file"
SenCantSendToKindlet="can't send menu to Kindlet"
SenCantSort="can't sort"
SenCantUpdateCache="can't update cached menu"
SenCantWriteCache="can't cache menu"
TFL="/var/tmp/--" PRODUCTNAME "--"
INTERNAL_ACTIONS["breadcrumb"]="A"
INTERNAL_ACTIONS["status"]="B"
}
function teardown(   i) {
system("cd /var/tmp && rm -f \"" TFL "\"* 2>/dev/null")
}
function cache_file_delete() {
system("rm -f '"CACHEPATH"'")
}
function cache_save(    errors,hash1,hash2,cmd) {
errors = 0
if (IN_MEMORY_CACHE_INVALID) {
cache_file_delete()
return 0
}
cmd = CONFIG["NCbbmd5sum"]" '"CACHEPATH"' 2>/dev/null"
if (-1 < getline hash1 < CACHEPATH) {
close(CACHEPATH)
cmd | getline hash1
if (close(cmd)) {
scream(SenCantHashCache)
hash1 = 0
}
}
printf "" >CACHEPATH
errors += config_send(CACHEPATH)
errors += formatter(MENUS, NMENUS, "multiline", CACHEPATH)
if (-1 == close(CACHEPATH)) {
++errors
} else {
cmd | getline hash2
if (close(cmd)) {
scream(SenCantHashCache)
hash2 = 0
}
}
if (hash1 && hash2 && hash1 != hash2) {
if (! errors) {
print "1 "CACHEPATH >MBXPATH
close(MBXPATH)
}
}
return errors
}
function cache_send(cachepath,
slurp,version) {
if (0 <= (getline slurp < cachepath))
close(cachepath)
if ("" != slurp) {
version = substr(slurp, index(slurp, "\n") + 1)
version = substr(version, 1, index(version, "\n") - 1)
if (version != VERSION) {
cache_file_delete()
return 1
}
printf "%s", slurp
return 0
}
return 1
}
function cache_update(   errors) {
errors = 0
json_emit_self_menu_and_parsing_errors(0+PARENT_ERRORS)
delete MENUS; NMENUS=0
if (0 != np2mn(NPATHS, NNPATHS)) {
scream("error (np2mn)")
++errors
} else {
IN_MEMORY_CACHE_INVALID = 0
if (0 != cache_save()) {
scream(SenCantWriteCache)
++errors
}
}
return errors
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
gsub(/^\s+|\s+$/, "", k)
k = substr(k,1+index(k,"_"))
p = index(k, "=")
v = substr(k,p+1)
if (match(v, /^".*"$/))
v = substr(v, 2, RLENGTH - 2)
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
printf "%d\n%s\n%s\n%d\n", 2, VERSION, MBXPATH, n >>outfile
for (k in CONFIG)
if(k !~ /^NC/)
print k"="CONFIG[k] >>outfile
}
function collate(ary, nary,
maxdepth,depth,i,saved_self_menu_name,
rec_lvlsnpath,rec_level,rec_snpath,rec_name,rec_type,
key,seen,seenary,new_root,
childrenary,nchildrenary,
x,xary,nxary,y,z,trace) {
maxdepth = menu2Dsplit(0, ary, nary)
saved_self_menu_name = ary[1"nm"]
ary[1"nm"] = SELF_MENU_NAME
menu2Dimplode(1, ary, nary)
nchildrenary = children_map(ary, nary, 0, childrenary)
for (depth = 0; depth <= maxdepth; depth++) {
for (i = 1; i <= nary; i++) if (i"ls" in ary) {
rec_level = ary[i"lv"]
if (depth != rec_level)
continue
rec_lvlsnpath = x = ary[i"ls"]
rec_snpath = ary[i"sn"]
rec_type = ary[i"ty"]
if (1 == rec_type) {
rec_name = ary[i"nm"]
key = rec_level "_" rec_name
if (! (key in seenary)) {
seenary[key] = i
continue
}
new_root = 0
nxary = split(seenary[key], xary, " ")
for (z = 1; z <= nxary; z++) {
seen = xary[z]
seen_lvlsnpath = ary[seen"ls"]
seen_level = ary[seen"lv"]
seen_snpath = ary[seen"sn"]
if ((x = substr(substr(rec_snpath, 1, length(rec_snpath)-6), 5)) \
!= (y = substr(substr(seen_snpath, 1, length(seen_snpath)-6), 5))) {
seenary[key] = seenary[key]" "i
} else {
new_root = seen
}
}
if (0 == new_root) {
continue
}
move_node(i, new_root, "", ary, nary, childrenary , key ~ trace)
childrenary[new_root] = childrenary[new_root] " " childrenary[i]
x = ary[new_root"nm"]
y = substr(x, length(x))
if ("+" != y) {
ary[new_root"nm"] = x "+"
menu2Dimplode(seen, ary, nary)
}
ary[i] = ary[i"sn"] = childrenary[i] = 0
}
}
}
x = ary[1"nm"]
y = substr(x, length(x))
ary[1"nm"] = (saved_self_menu_name) ("+" == y ? "+" : "")
menu2Dimplode(1, ary, nary)
}
function move_node(src_i, dst_i, dst_path, ary, nary, childrenary, trace,
offset,sst,dst_snpath, ncary,cary,child, c,x,y,to,len, dbgind) {
offset = calc_snpath_offset(childrenary[dst_i], ary)
sst =	npath_s_this_(K_items, ary[dst_i"sn"])
ncary = split(childrenary[src_i], cary, " ")
for (c = 1; c <= ncary; c++) {
child = cary[c]
dst_snpath = dst_path ? dst_path : ary[dst_i"sn"]
x = substr(dst_snpath, 1, length(dst_snpath) - 2)
to = x sK_items sprintf("%02x", offset + c)
len = length(to)
if (0 == ary[child"ty"]) {
ary[child"st"] = sst substr(ary[child"st"], length(sst) + 1)
ary[child"ls"] = ary[child"lv"] ":" (ary[child"sn"] = to substr(ary[child"sn"], len + 1))
menu2Dimplode(child, ary, nary)
} else {
move_node(child, dst_i, to sK_name, ary, nary, childrenary, trace)
}
}
if (dst_path) {
to = substr(dst_snpath, 1, length(dst_snpath) - 2)
len = length(to)
sst = substr(sst, 1, length(sst) - 4)
ary[src_i"st"] = sst substr(ary[src_i"st"], length(sst) + 1)
ary[src_i"ls"] = ary[src_i"lv"] ":" (ary[src_i"sn"] = to substr(ary[src_i"sn"], len + 1))
if (1 == ary[src_i"ty"]) {
y = ary[src_i"ac"]
ary[src_i"ac"] = substr(y, 1, x = index(y,":")) to substr(y, x + len + 1)
}
menu2Dimplode(src_i, ary, nary)
}
}
function menu2Dsplit(idx, ary, nary,
imin,imax,i,x,y,z,lump,rec,xary,nxary,maxlevel) {
if (idx) {
imin = imax = idx
} else {
imin = 1; imax = nary
}
maxlevel = 0
for (i = imin; i <= imax; i++) if (i in ary) {
nxary = split(ary[i], xary, SEP)
ary[i"st"] = xary[1]
lump = xary[2]
lump = (lump SEP) (x = xary[3])
lump = (lump) (x == 3 ? "" : SEP xary[4])
ary[i"l1"] = lump
ary[i"ls"] = x = xary[nxary - 2]
ary[i"lv"] = z = substr(x, 1, (y = index(x, ":")) - 1)
if (z > maxlevel) maxlevel = z
ary[i"sn"] = substr(x, y + 1)
ary[i"nm"] = xary[nxary - 1]
ary[i"ac"] = x = xary[nxary]
ary[i"ty"] = submenu_actionQ(x) ? 1 : 0
}
return maxlevel
}
function menu2Dimplode(idx, ary, nary,
imin,imax,i) {
if (idx) {
imin = imax = idx
} else {
imin = 1; imax = nary
}
for (i = imin; i <= imax; i++) if (ary[i"sn"]) {
ary[i] = ary[i"st"] SEP ary[i"l1"] SEP ary[i"lv"] ":" ary[i"sn"] SEP ary[i"nm"] SEP ary[i"ac"]
}
return imax
}
function children_map(ary, nary, idx, map,
i,min,max) {
if (0 == idx) {
min = 1
max = nary
} else {
mix = max = idx
}
for (i = min; i <= max; i++) if (i"lv" in ary) {
if (1 == ary[i"ty"])
map[i] = menu_children(ary[i"ac"], ary, nary)
}
return nary
}
function menu_children(matcher, ary, nary,
i,list) {
for (j = 1; j <= nary; j++) {
if (ary[j"ls"] ~ matcher) {
list = list " " j
}
}
return substr(list, 2)
}
function calc_snpath_offset(list, ary,
x,nxary,xary) {
if (list) {
nxary = split(list, xary, " ")
x = get_items_index(xary[nxary], ary)
} else {
x = -1
}
return x
}
function get_items_index(i, ary,
x,y) {
if (! i in ary)
return -1
y = ary[i"ls"]
x = length(y)
x = 0 + ("0x" substr(y, x-3, 2))
return x
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
cmd = config_get("NCbbfind")" "dirs" "follow" "depth" \\( "paths" \\) \\( -prune -type f \\) -o \\( -name config.xml -type f \\) 2>/dev/null"
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
function format_action_internal(internal,
p,keyword,cmd) {
cmd = ""
p = index(internal" "," ")
keyword = substr(internal, 1, p - 1)
if (keyword in INTERNAL_ACTIONS) {
cmd = INTERNAL_ACTIONS[keyword]
internal = substr(internal, p + 1)
cmd = cmd length(internal) "#" internal
}
return cmd
}
function format_action_item(action, params, internal,
p,cmd,x) {
p = index(action, ";")
cmd = substr(action, p+1)
if (x = format_action_internal(internal)) {
		action = "#" x action
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
name = SELF_MENU_NAME
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
"\", \"action\": \":\", \"internal\": \"breadcrumb [more info in "PRODUCTNAME" log]\", \"exitmenu\": false}"
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
XenNoExtensionsFound, \
":", "", "breadcrumb help @ http://bit.ly/kualit", \
-200, "", "e")
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
x, "", \
"", 2, "", "ecsd")
} else if (3 == ary[b]) {
x = "mv '"SCREAM_LOG"' \\\"/mnt/us/documents/"PRODUCTNAME"-`date -u -Iminutes | sed s/:/./g`.txt\\\";dbus-send --system /default com.lab126.powerd.resuming int32:1"
json=json "," json_self_menu_button( \
"Save and reset "PRODUCTNAME" log", \
x, "", \
"", 3, "\"\\\""SCREAM_LOG"\\\" -z!\"", "ecsd")
} else if (99 == ary[b]) {
json=json "," json_self_menu_button( \
CROSS" Quit", \
":", "", \
"", 99)
}
}
}
return json
}
function json_self_menu_button(name, action, params, internal, priority, xif, non_default_options) {
return "{\"name\": \"" name "\"" \
", \"action\": \"" action "\"" \
("" != params ? ", \"params\": \"" params "\"" : "") \
("" != internal ? ", \"internal\": \"" internal "\"" : "") \
("" != priority ? ", \"priority\": " priority : "") \
("" != xif ? ", \"if\": " xif : "") \
(index(non_default_options, "e") ? ", \"exitmenu\": false" : "") \
(index(non_default_options, "c") ? ", \"checked\": true" : "") \
(index(non_default_options, "r") ? ", \"refresh\": true" : "") \
(index(non_default_options, "s") ? ", \"status\": false" : "") \
(index(non_default_options, "d") ? ", \"date\": true" : "") \
(index(non_default_options, "h") ? ", \"hidden\": true" : "") \
"}"
}
function jp2np(ary, size, serial, menufilepathname,
i,x,npath,apath,jpath,key,value,level,errors) {
errors=0
apath=menufilepathname; sub(/\/[^\/]+$/, "", apath)
while (jp2np_LAST_SEEN <= size) {
line=ary[jp2np_LAST_SEEN++]
if (line ~ /[]}]$/) {
continue
}
x=index(line,"\t")
jpath=substr(line, 1, x-1)
value=substr(line, x+1)
key = match(jpath, /"[^"]+"]$/) ? substr(jpath, 1+RSTART,RLENGTH-3) : "ERROR"
if (key !~ /^(name|action|params|internal|priority|if|exitmenu|hidden|checked|refresh|status|date)$/) {
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
i,x,slurp,lines,nlines,iline,errors,
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
x = substr(ITEM[K_action], 1, index(ITEM[K_action],";")-1)
if (RPN_if(ITEM[K_if], x)) {
sortable_tag=select_level[level]
MENUS[++NMENUS] = work_record( \
sortable_record(sortable_tag, OPT_SORT),
kindlet_options(),
level,npath_s_this_(K_name, snpath),
ITEM[K_name],
format_action_item(ITEM[K_action], ITEM[K_params], ITEM[K_internal]))
}
new_item()
} else {
ITEM[key]=value MMRK
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
} else if (K_priority == key || K_params == key || K_internal == key || K_if == key || K_exitmenu == key || K_checked == key || K_refresh == key || K_status == key || K_date == key || K_hidden == key) {
ITEM[key] = value
} else {
scream("unexpected key <"key"> (np2mu)")
++errors
}
}
}
}
if ("false" != config_get("collate"))
collate(MENUS, NMENUS)
sort_for_user(MENUS, NMENUS, OPT_SORT)
if ("" == SORTED_DATA) {
scream("np2mn can't sort 2")
++errors
}
delete MENUS; NMENUS=0
NMENUS = sort_criteria_cut(MENUS, OPT_SORT)
return errors
}
function kindlet_options(   x) {
x = (ITEM[K_exitmenu] ~ /^(0|false)$/ ? "e" : "") \
(ITEM[K_checked] ~ /^(1|true)$/ ? "c" : "") \
(ITEM[K_refresh] ~ /^(1|true)$/ ? "r" : "") \
(ITEM[K_status] ~ /^(0|false)$/ ? "s" : "") \
(ITEM[K_date] ~ /^(1|true)$/ ? "d" : "") \
(ITEM[K_hidden] ~ /^(1|true)$/ ? "h" : "")
return "" == x ? "" : x SEP
}
function new_item() {
ITEM[K_name] = ITEM[K_action] = ITEM[K_params] = ITEM[K_internal] =  ITEM[K_if] = ITEM[K_exitmenu] = ITEM[K_checked] = ITEM[K_refresh] = ITEM[K_status] = ITEM[K_date] = ITEM[K_hidden] = ""; ITEM[K_priority] = 0;
}
function new_submenu() {
ITEM[K_name] = ITEM[K_if] = ITEM[K_hidden] = ""; ITEM[K_priority] = 0;
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
function RPN_if(expr, source,
x,token,nxary,xary) {
if ("" == expr) return 1
RPN_sp = 0
RPN_err = ""
nxary = RPN_tokenize(expr, xary)
for(x = 1; x <= nxary; x++) {
token = xary[x]
if (match(token, /^\".*\"$/))
token = substr(token, 2, RLENGTH - 2)
RPN_eval_bool(token)
if(RPN_err) {
scream(RPN_msg(expr, source, RPN_err))
return 1
}
}
if (1 != RPN_sp) {
scream(RPN_msg(expr, source, "invalid expression"))
return 1
}
return RPN_top()
}
function RPN_eval_bool(token,
x,y,z) {
if (token !~ /^(-e|-ext|-f|-gg?!?|-m|-o|-z!|!|&&|\|\|)$/) {
RPN_push(token)
} else {
x = RPN_stack[RPN_sp]
RPN_pop();
if (token == "!") {
RPN_push(! x)
} else if (token == "-f" || token == "-z!") {
z = isRegularFileEmpty(x)
RPN_push(token == "-f" && -1 != z || token == "-z!" && 0 < z)
} else if (token == "-e") {
RPN_push(!system("test -e \""x"\""))
} else if (token == "-ext") {
RPN_push(x in LOADED_EXTENSIONS)
} else if (token == "-m") {
RPN_push((z = config_get("model")) == x)
} else if (token == "-o") {
RPN_push((z = config_get(y)) == x)
} else {
y = RPN_stack[RPN_sp]
RPN_pop()
if (token == "&&") {
RPN_push(x && y)
} else if (token == "||") {
RPN_push(x || y)
} else if (token ~ "-gg?!?") {
if ( -1 == (z = RPN_grep(x, y, index(token, "!")))) {
if (index(token, "gg")) {
RPN_push(0)
} else {
RPN_err = "not found: \""y"\""
}
} else {
RPN_push(z)
}
} else {
RPN_err = "invalid operator: " + token
}
}
}
}
function RPN_push(x) { RPN_stack[++RPN_sp] = x }
function RPN_pop() { if(RPN_sp > 0) {RPN_sp--} else {RPN_err = "Stack underflow"} }
function RPN_top() { return RPN_sp > 0 ? RPN_stack[RPN_sp] : "--empty stack--" }
function RPN_grep(pattern, file, vflag,
x, xary, nxary, found) {
if (0 < (getline x < file)) {
close(file)
nxary = split(x, xary, /\n/)
if (vflag) {
found = 0
for (x = 1; x <= nxary; x++) {
if (xary[x] ~ pattern) {
found = 1
}
}
return ! found
} else {
for (x = 1; x <= nxary; x++) {
if (xary[x] ~ pattern) {
return 1
}
}
return 0
}
} else {
return -1
}
return split(a1, ary, /\n/)
}
function RPN_msg(expr, source, text) {
return "\""source"\": JSON \"if\": "expr" : "text
}
function RPN_tokenize(a1, ary,
SPACE) {
SPACE="[[:space:]]+"
gsub(/\"[^[:cntrl:]\"\\]*((\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})[^[:cntrl:]\"\\]*)*\"|-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?|-e|-ext|-f|-gg?!?|-m|-o|-z!|!|&&|\|\||[[:space:]]+|./, "\n&", a1)
gsub("\n" SPACE, "\n", a1)
sub(/^\n/, "", a1)
return split(a1, ary, /\n/)
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
cmd = config_get("NCbbsort")" -t \""SEP"\" "sort_options" < \""tfl"\""
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
function sort_for_user(ary, nary, opt_sort,
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
function formatter(ary, nary, fmt_name, outfile,
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
fmt="%-4.4s|%-24.24s|%-20.20s|%-33.33s\n"
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
function get_model(file, line, device) {
if (MODEL) return MODEL
MODEL = "Unknown"
file = "/proc/usid"
while ((getline line < file) > 0) {
device = substr(line, 3, 2)
if (device ~ /^(02)|(03)$/) {
MODEL = "Kindle2"
break
}
else if (device ~ /^(04)|(05)$/) {
MODEL = "KindleDX"
break
}
else if (device ~ /^(09)$/) {
MODEL = "KindleDXG"
break
}
else if (device ~ /^(08)|(06)|(0A)$/) {
MODEL = "Kindle3"
break
}
else if (device ~ /^(0E)|(23)$/) {
MODEL = "Kindle4"
break
}
else if (device ~ /^(0F)|(11)|(10)|(12)$/) {
MODEL = "KindleTouch"
break
}
else if (device ~ /^(24)|(1B)|(1D)|(1F)|(1C)|(20)$/) {
MODEL = "KindlePaperWhite"
break
}
}
close(file)
return MODEL
}
function isRegularFileEmpty (x,
y,z) {
z = (getline y < x)
if (0 <= z) close(x)
return z
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
