#!/bin/bash
# Example requests against the Docker image that run.sh starts. Its
# configuration, nginx.conf in this folder, loads the device detection module
# and answers on /hash with the values in response headers.
#
# The match uses the User-Agent and Sec-CH-UA-* headers, so the requests
# show what the module makes of the same browser with and without client
# hints. The IP Intelligence examples are in examples/ipi and examples/mixed.

HOST=127.0.0.1:8080

echo "=== Desktop browser with client hints ==="
curl --head \
	-H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.41' \
	-H 'Sec-CH-UA: "Not.A/Brand";v="8","Chromium";v="114","Microsoft Edge";v="114"' \
	-H 'Sec-CH-UA-Arch: x86' \
	-H 'Sec-CH-UA-Bitness: 64' \
	-H 'Sec-CH-UA-Full-Version: 114.0.5735.110' \
	-H 'Sec-CH-UA-Full-Version-List: "Not.A/Brand";v="8.0.0.0","Chromium";v="114.0.5735.110","Microsoft Edge";v="114.0.1823.41"' \
	-H 'Sec-CH-UA-Mobile: ?0' \
	-H 'Sec-CH-UA-Model: ' \
	-H 'Sec-CH-UA-Platform: Windows' \
	-H 'Sec-CH-UA-Platform-Version: 15.0.0' \
	"http://$HOST/hash"

echo "=== Mobile browser ==="
curl --head \
	-H 'User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 7_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D167 Safari/9537.53' \
	"http://$HOST/hash"
