#! /bin/sh
#
# Simple wrapper around the strip awk script to make it easier to call from an ant task
#
##

# Handle being called from a different directory (ie. by ant)...
WD="${0%/*}"

echo "y" | ${WD}/gawk.sh ${WD}/strip.awk -v AWK=1 ${WD}/../parse-commented.awk > ${WD}/../parse.awk
