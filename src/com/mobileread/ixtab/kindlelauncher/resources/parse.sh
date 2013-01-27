#!/bin/sh
EXTENSIONDIR=/mnt/us/extensions/
FILES=$EXTENSIONDIR*
labeltext=""
stamper=""
temp=""
seperator="¬"
dirsuffix="/"
prettyseperator=":"

for f in $FILES; do
FILES2=$f/menu.json
for j in $FILES2; do

## Parse the JSON best we can using a shell. Ditch various bit we aren't concerned with. Only return the action nodes' values

for z in $(sed -ne 's/^.*"\(action\)"\(\s*:\s*\)"\([^"]\+\)".*$/\1\2\3/p' < $j); do

## reinverted logic required, less horrific. skip ACTION: label headers.
if [ $z  == "action:"  ]
then
continue
fi

## better clear the params results if we have any
holder=""
for params in $(cat $j | grep $z \
| sed -e 's/[{}]/''/g' \
| awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' \
| sed 's/\"\:\"/\|/g;s/[\,]/ /g;s/\"//g'| grep "params")
do

## and populate the param results if we have any
paramholder="$holder""`echo $params | sed 's/params://g'` "
done

## check the matching config.xml exist and do a prefixed label if we find the value
	if [ -e $f/config.xml ]
	then

	## create a unique "tidy label" suffix - one per command to discern buttons easily - trim off as much as we can from the name
	temp=$(echo $z | sed "s-$f--g")
	thisstamper=$(cat $f/config.xml | grep "<name>" | sed 's/<name>//g;s/<\/name>//g;s/^[ \t]*//;s/[ \t]*$//')
	
	##make a tidy label based on the config name paramater
	labeltext="$thisstamper"":""$temp"
	else
	labeltext=$(echo $f | sed "s-$EXTENSIONDIR--g")
	echo "error! mangle happened ¬ ./menu-error"
	fi

## make a determination about appending prefixes to the calls to make them valid.
## then create a complete call structured
##
## Name: suffix ¬ commands <param1> <paramN> ...
##
## Todo parse this data in java to make a simplified way to access the old data.
if [ -e `echo $z | sed 's/ action: //g'` ]
then
echo "$labeltext ""¬""`echo $z | sed 's/ action: //g'`$holder"
else
stamper=$(cat $f/config.xml | grep "<name>" | sed 's/<name>//g;s/<\/name>//g;s/^[ \t]*//;s/[ \t]*$//')
tamper="`echo "$z" | sed 's/ action: //g'`"
echo $stamper "$prettyseperator" "$z" "$seperator" "$f""$dirsuffix""$tamper" "$paramholder"
fi
# meh
holder=""
paramholder=""
done
done
done

