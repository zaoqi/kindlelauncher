#! /bin/sh
#
# Simple wrapper around the strip awk script to make it easier to call from an ant task
#
##

# Handle being called from a different directory (ie. by ant)...
WD="${0%/*}"

echo "y" | sh ${WD}/awk.sh ${WD}/strip.awk -v AWK=1 ${WD}/../parse-commented.awk > ${WD}/../parse.awk
echo "FIXME!!! overwriting parse.awk with known good version"
cp ${WD}/../parse.awk.ok ${WD}/../parse.awk