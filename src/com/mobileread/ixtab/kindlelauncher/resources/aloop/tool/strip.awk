#!/bin/awk -f

function prnt(txt,pre,cmp)
# local pre,cmp
{
#debug#	if(pre) printf ("%4d::%s::\t%s\n\t\t", NR, pre, cmp)
	print txt
}

BEGIN	{
WARNING="=== Non-greedy shell script comment stripper ==="\
"\nThe following input syntax WILL result in incorrect output, so rid your"\
"\nscript of such syntax before stripping it - You have been warned!"\
"\n1) Hash comments within multi-line strings"\
"\n	x=\"that is NOT"\
"\n	# a comment"\
"\n	but it will still be deleted (incorrectly)\""
"\n"
"\nSuspend stripping by enclosing a block within /: SSTR/,/: RSTR/"
"\nStrip a whole block by enclosing it within /: BSTR/,/: ESTR/" 
	print WARNING >"/dev/stderr"

	CONTINUATION=0
	SUSPENDED=0
}
# suspend stripping
{
	if ($0 ~ /^\s*: RSTR\s*$/) { SUSPENDED=0; next }
	else if ($0 ~ /^\s*: SSTR\s*$/) { SUSPENDED=1; next }
	else if (SUSPENDED) { print; next }
}
# forced stripping
/^\s*: BSTR\s*$/,/^\s*: ESTR\s*$/ {
	next
}
# commented continuation line isn't a continuation
/\\$/ && /^\s*#/ {
	next
}
# continuation line
/\\$/ {
	CONTINUATION=1
	print; next
}
# white line
/^\s*$/	{
	if (CONTINUATION) { # unless after continuation
		print
		CONTINUATION=0
	}
	next
}
# all other lines
{
	CONTINUATION=0
}
# full comment line
/^\s*#/ {
	if (2>=NR) print # unless shebang and version info comment
	next
}
# in-line comment not in string nor in variable substitution
/#/ && ! ( /["']/ || /\${/ ) {
	match($0,/#[^#]*$/) # non-greedy => look for tail comment
	s=substr($0,1,RSTART-1)
	t=substr($0,RSTART+1,RLENGTH-1) # $0 == s"#"t
	r1=substr(s,length(s),1)
	if (r1 == "$") {
		prnt($0,"kp0",$0); # $#
		next
	}
	prnt(s,"not",$0);
	next
}
/was-#-above/ && ! ( /["']/ || /\${/ ) { # UNMATCHED, greedy => unsafe
	match($0,/^[^#]+/)
	s=substr($0,RSTART,RLENGTH)
	t=substr($0,RSTART+RLENGTH+1) # $0 == s"#"t
	r1=substr(s,RLENGTH,1)
	if (r1 == "$") {
		prnt($0,"kp0",$0); # $#
		next
	}
	prnt(s,"not",$0);
	next
}
# in-line comment possibly in string or in variable substitution
/#/ {
	match($0,/#[^#]*$/) # non-greedy => look for tail comment
	s=substr($0,1,RSTART-1)
	t=substr($0,RSTART+1,RLENGTH-1) # $0 == s"#"t
	r1=substr(s,length(s),1)
	if (r1 == "$") {
		prnt($0,"kp1",$0); # $#
		next
	}
	if (t !~ /["'}]/) {
		# tail comment is free from str and var
		prnt(s,"tai",$0)
		next
	}
	prnt($0,"kp2",$0)
	next
}
/was-#-above/ { # UNMATCHED greedy => unsafe
	match($0,/^[^#]+/)
	s=substr($0,RSTART,RLENGTH)
	t=substr($0,RSTART+RLENGTH+1) # $0 == s"#"t
	if (s ~ /["']/ && t ~ /["']/ || s ~ /\${/ && t ~ /}/) {
		# first sharp could be in a str or var
		# keep s"#" at least, if not the whole $0
	} else { # $0's sharp free from str and var
		prnt(s,"fre",$0)
		next
	}
	if (match(t,/#[^#]+$/)) { # t could include a tail comment
		s1=substr(t,1,RSTART-1)
		t1=substr(t,RSTART+1,RLENGTH-1) # $0 == s"#"s1"#"t1
		if (t1 !~ /["'}]/) { # (naive test)
			# t's sharp free from str and var
			prnt(s"#"s1,"tai",$0)
			next
		}
		prnt($0,"kp1",$0)
		next
	}
	prnt($0,"kp2",$0)
	next
}
# all remaining lines
{print}
