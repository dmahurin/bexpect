#!/bin/bash
# expect(tcl)-like functionality in bash
# -Don Mahurin

set -e

bexpect_script_dir="$(dirname "${BASH_SOURCE[0]}")"

mkfifo /tmp/expect_fifo_out
mkfifo /tmp/expect_fifo_in

exec 7<>/tmp/expect_fifo_in
exec 8<>/tmp/expect_fifo_out

cleanup () {
	set +e
	if [ ! -e /tmp/expect_fifo_out ]; then return; fi
	kill $(jobs -p)
	rm /tmp/expect_fifo_in
	rm /tmp/expect_fifo_out
	stty sane
	echo
}
trap "cleanup" EXIT INT TERM CHLD

timeout=10
expect_out_buffer=
endtime=
spawn_id=
debug=0

exp_internal () {
	debug="$1"
}

exp_pid () {
	return "$spawn_id"
}

interact () {
	stty raw -echo isig
	cat </tmp/expect_fifo_out &
	cat >/tmp/expect_fifo_in
	wait
}

spawn () {
	python "$bexpect_script_dir"/run.py "$@" <&7 >&8 2>&1 &
	spawn_id="$!"
}

send () {
	line="$1"
	[ -n "$debug" ] && [ "$debug" -gt 0 ] && echo "bexpect: sending \"$line\"" 1>&2
	echo -n -e "$1" >&7
}

send_user () {
	echo -n -e "$1"
}

exp_read_ () {
	t="$1"
	if ! chunk="$(python "$bexpect_script_dir"/read.py "$t" <&8 && echo x)"; then
		echo read failed
		exit 1
	fi
	chunk="${chunk%x}"
	[ -n "$debug" ] && echo -n "$chunk"
	expect_out_buffer="$expect_out_buffer$chunk"
}

exp_continue () {
	if [ $timeout -lt 0 ]; then
		endtime=-1
	else
		endtime=$(($SECONDS + $timeout))
	fi
}

exp_next () {
	if [ -z "$endtime" ]; then
		# reset timer if not set
		t=0
		exp_continue
	elif [ $endtime -lt 0 ]; then
		t=-1
	elif (( $SECONDS >= $endtime )); then
		if [ "$debug" -gt 1 ] ; then
			echo
			echo "bexpect: timeout $timeout" 1>&2
			echo "bexpect: buffer \"$expect_out_buffer\"" 1>&2
		fi
		endtime=
		return 1
	else
		t="$(($endtime-$SECONDS))"
	fi
	if ! exp_read_ "$t"; then
		return 1
	fi
}

expect_nowait () {
	exact=
	re_match=
	while [ "$#" -gt 0 ] ; do case "$1" in
		-re) re_match=1; shift ; ;;
		-ex) exact=1; shift ; ;;
		-gl) shift ; ;;
		*) break
	esac; done

	pattern="$1"
	if [ -n "$exact" ]; then
		pattern=$(echo "$1" |  sed 's:\([()\$\^\.\*\\]\):\\\1:g')
		re_match=1
	fi
	if [ -n "$re_match" ]; then
		re="(.*)($pattern)(.*)"
		if [[ $expect_out_buffer =~ $re ]]; then
			endtime=
			expect_out_before=${BASH_REMATCH[1]}
			expect_out=("${BASH_REMATCH[@]:2}")
			[ -n "$debug" ] && [ "$debug" -gt 0 ] && ( echo; echo  "bexpect: match \"${expect_out[0]}\"" 1>&2 )
			expect_out_buffer=${BASH_REMATCH[3]}
			return 0
		fi
	else # glob match
		if [[ $expect_out_buffer == *$pattern* ]]; then
			endtime=
			expect_out_before=${expect_out_buffer%%${pattern}*}
			before_len=${#expect_out_before}
			after=${expect_out_buffer#*${pattern}}
			buf_len=${#expect_out_buffer}
			after_len=${#after}
			match_len=$(( $buf_len - $after_len - $before_len ))
			expect_out=( "${expect_out_buffer:$before_len:$match_len}" )
			[ -n "$debug" ] && [ "$debug" -gt 0 ] && ( echo ; echo "bexpect: match \"${expect_out[0]}\"" 1>&2 )
			expect_out_buffer="$after"
			return 0
		fi
	fi
	if [ "$debug" -gt 0 ] ; then
		echo
		echo "bexpect: no match \"$pattern\"" 1>&2
	fi
	return 1
}

expect () {
	while exp_next ; do
		if expect_nowait "$@"; then
			return 0
		fi
	done
	return 1
}

if [ "$#" -gt 0 ]; then . "$1"; fi
