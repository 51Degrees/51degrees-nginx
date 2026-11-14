#!/bin/bash
# Temporary. Times main's modules against the head's on one runner, with the
# head's performance harness and NGINX binary, swapping only the module
# between runs and alternating which goes first in each round.
set -u
repo=$1
modules=$2
rounds=${3:-10}
build=$repo/tests/performance/build

stop_nginx() {
	pkill -TERM -x nginx > /dev/null 2>&1
	for i in $(seq 1 60); do
		if ! pgrep -x nginx > /dev/null &&
			! curl -s -o /dev/null --max-time 1 http://127.0.0.1:3000/calibrate; then
			return 0
		fi
		sleep 0.5
	done
	echo "TIMING NGINX did not stop"
	exit 1
}

run_one() {
	local engine=$1 variant=$2 round=$3
	cp "$modules/$variant/"*.so "$repo/build/modules/"
	rm -f summary.json
	if [ "$engine" = ipi ]; then
		ENGINE=ipi ./runPerf.sh > run.out 2>&1
	else
		DATA_FILE_NAME=TAC-HashV41.hash ./runPerf.sh > run.out 2>&1
	fi
	stop_nginx
	local seconds failed
	seconds=$(sed -n "s/.*'request_s_process': \([0-9.e-]*\).*/\1/p" summary.json)
	failed=$(sed -n "s/.*'failed_process': \([0-9]*\).*/\1/p" summary.json)
	echo "TIMING round=$round engine=$engine variant=$variant request_s=$seconds failed=$failed"
	if [ -z "$seconds" ]; then
		tail -20 run.out | sed 's/^/TIMING /'
	fi
}

cd "$build"
stop_nginx
for round in $(seq 1 "$rounds"); do
	if [ $((round % 2)) -eq 1 ]; then order="main head"; else order="head main"; fi
	for engine in hash ipi; do
		for variant in $order; do
			run_one "$engine" "$variant" "$round"
		done
	done
done
