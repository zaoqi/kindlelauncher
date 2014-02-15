#!/bin/sh

# We rely on GNU Awk 4 at the very least.
if [[ "$(env gawk -V 2>/dev/null | grep -e 'GNU Awk' | cut -c 9)" -lt "4" ]] ; then
	echo "* Your GNU Awk version is too old! We need GNU Awk 4 ;)"
	exit 1
fi

exec env gawk -f $*
