#!/bin/bash
# expect(tcl)-like functionality in bash
# -Don Mahurin

set -e

script_dir="$(dirname "${BASH_SOURCE[0]}")"

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
debug=1

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
	python "$script_dir"/run.py "$@" <&7 >&8 2>&1 &
	spawn_id="$!"
}

send () {
	line="$1"
#	line="$(echo "${line}" | tr '\r' '\n')"
	[ "$debug" -gt 0 ] && echo "bexpect: send: '$line'" 1>&2
	echo -n -e "$1" | tr '\r' '\n' >&7
}

send_user () {
	echo -n -e "$1" | tr '\r' '\n'
}

exp_read_ () {
	t="$1"
	chunk=$(python "$script_dir"/read.py "$t" <&8)
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
	if [ $timeout -lt 0 ]; then
		t=-1
	elif [ -z "$endtime" ]; then
		t=0
	elif (( $SECONDS >= $endtime )); then
		endtime=
		[ "$debug" -gt 1 ] && echo -e "bexpect: no match. buffer:'\n$expect_out_buffer'" 1>&2
		return 1
	else
		t="$(($endtime-$SECONDS))"
	fi
	exp_read_ "$t"
}

expect_nowait () {
	# reset timer if not set
	if [ -z "$endtime" ]; then
		exp_continue
		exp_read_ 0
	fi

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
			[ "$debug" -gt 1 ] && echo -e "bexpect: before'\n$expect_out_before'" 1>&2
			expect_out_match=${BASH_REMATCH[2]}
			[ "$debug" -gt 0 ] && echo "bexpect: matched '$expect_out_match'" 1>&2
			expect_out_buffer=${BASH_REMATCH[3]}
			return 0
		fi
	else # glob match
		if [[ $expect_out_buffer == *$pattern* ]]; then
			endtime=
			expect_out_before=${expect_out_buffer%%${pattern}*}
			before_len=${#expect_out_before}
			[ "$debug" -gt 1 ] && echo -e "bexpect: before'\n$expect_out_before'" 1>&2
			after=${expect_out_buffer#*${pattern}}
			buf_len=${#expect_out_buffer}
			after_len=${#after}
			match_len=$(( $buf_len - $after_len - $before_len ))
			expect_out_match=${expect_out_buffer:$before_len:$match_len}
			[ "$debug" -gt 0 ] && echo "bexpect: matched '$expect_out_match'" 1>&2
			expect_out_buffer="$after"
			return 0
		fi
	fi
	return 1
}

expect () {
	while : ; do
		if expect_nowait "$@"; then
			return 0
		fi
		exp_next || return 1
	done
	return 0
}
