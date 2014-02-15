#!/bin/sh

# We rely on GNU Awk 4 at the very least.
if [[ "$(env awk -V 2>/dev/null | head -n 1 | sed -re 's/^(GNU Awk )([[:digit:]])([[:digit:].]*?)(,)(.*?)$/\2/')" -lt "4" ]] ; then
	echo "* Your GNU Awk version is too old! We need GNU Awk 4 ;)"
	exit 1
fi

exec env gawk -f $*
