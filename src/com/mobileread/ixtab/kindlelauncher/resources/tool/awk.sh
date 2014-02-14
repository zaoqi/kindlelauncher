#!/bin/sh

# this is just a simple wrapper. But it gets around the problem
# that awk may be in /bin, or /usr/bin, or anywhere else

exec `which awk` -f $*
