#!/bin/bash
# Times requests through NGINX, each making one detection. Run it from the
# folder CMake built in.
#
#   ./runPerf.sh [hash|ipi]
#
# The engine is hash for device detection, the default, or ipi for IP
# Intelligence. The data file is the one _51DEGREES_DD_PATH names for hash,
# or _51DEGREES_IPI_PATH for ipi. When the name is not set, the free Lite
# device detection file or the free Asn IP Intelligence file in cxx/data is
# used.

# Constants
FULLPATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
HOST=127.0.0.1:3000
CAL=calibrate
PRO=process
PERF=./ApacheBench-prefix/src/ApacheBench-build/bin/runPerf.sh

# Run the benchmark with as many concurrent requests as there are
# processors, matching the worker_processes auto setting in the config
# templates, so that all of the Nginx workers are exercised at once. This
# mirrors the multi threaded benchmarks of the other 51Degrees APIs rather
# than measuring a single request at a time.
CONCURRENCY=$(nproc)

# Number of requests per worker. The total passed to ApacheBench scales
# with the concurrency so that each phase runs for the same wall-clock
# time however many processors the machine has.
PASSES_PER_WORKER=20000
PASSES=$((PASSES_PER_WORKER * CONCURRENCY))

# The engine to test. Either 'hash' (device detection, the default) or
# 'ipi' (IP intelligence).
ENGINE=${1:-hash}
if [ "$ENGINE" != "hash" ] && [ "$ENGINE" != "ipi" ]; then
	echo "The engine is hash or ipi, not $ENGINE"
	exit 1
fi

# Get the repo directory as an absolute path
ORIGINPATH="$(pwd)"
cd $FULLPATH/../../../
REPO_DIR="$(pwd)"
cd $ORIGINPATH

echo $REPO_DIR

# Create the nginx.conf, and choose the evidence the benchmark sends. Each
# request carries the header lines of one record of a YAML evidence file.
MODULES_DIR=$REPO_DIR/build/modules
if [ "$ENGINE" == "ipi" ]; then
	DATA_FILE_IPI=${_51DEGREES_IPI_PATH:-$REPO_DIR/cxx/data/ip-intelligence/51Degrees-IPIV4AsnIpiV41.ipi}
	sed "s|\${MODULES_DIR}|${MODULES_DIR}|g" ./nginx.conf.ipi.template > ./nginx.conf
	sed -i "s|\${DATA_FILE_IPI}|${DATA_FILE_IPI}|g" ./nginx.conf
	# A record of the IP Intelligence evidence file holds one IP address,
	# which is not a header. The address is sent as the User-Agent header,
	# where the configuration reads it, so that each request carries a
	# different address.
	EVIDENCE="$FULLPATH/evidence.ipi.yml"
	sed 's/^server\.client-ip: /header.User-Agent: /' \
		"$REPO_DIR/cxx/data/ip-intelligence/evidence.yml" > "$EVIDENCE"
else
	DATA_FILE=${_51DEGREES_DD_PATH:-$REPO_DIR/cxx/data/device-detection/51Degrees-LiteV4.1.hash}
	sed "s|\${MODULES_DIR}|${MODULES_DIR}|g" ./nginx.conf.template > ./nginx.conf
	sed -i "s|\${DATA_FILE}|${DATA_FILE}|g" ./nginx.conf
	# Send the full evidence records, matching the other 51Degrees API
	# benchmarks. CMake copies the file here.
	EVIDENCE="$FULLPATH/evidence.yml"
fi
if [ ! -s "$EVIDENCE" ]; then
	echo "The evidence file $EVIDENCE is missing or empty"
	exit 1
fi

# Create required directories and target files for service
echo > ../../../build/html/calibrate
echo > ../../../build/html/process

# Create coredumps folder
mkdir -p coredumps

# Backup the current config and replace with the test config
mv $REPO_DIR/build/nginx.conf $REPO_DIR/build/nginx.conf.bkp
cp $FULLPATH/nginx.conf $REPO_DIR/build/nginx.conf

# Run the performrance
$PERF -n $PASSES -s "$REPO_DIR/nginx" -t "$REPO_DIR/nginx -s stop" -c $CAL -p $PRO -h $HOST -k $CONCURRENCY -E "$EVIDENCE"

# Replace the original config
mv $REPO_DIR/build/nginx.conf.bkp $REPO_DIR/build/nginx.conf

# Remove coredumps folder
if [ ! "$(find coredumps -type f)" ]; then
	rmdir coredumps
fi
