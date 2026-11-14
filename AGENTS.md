# Working in this repository

If you have been asked to get an example running, follow
[Run the examples](#run-the-examples). It gives every step in order, from a
fresh clone to a response from nginx. The sections after it are notes on what
is not obvious from the code, for changing it. Keep them short and current.
The [README](README.md) describes the directives, the build options and the
tests.

## Run the examples

The examples are nginx configuration files in `examples`. `make install`
builds nginx with both 51Degrees modules, and writes the Device Detection
getting-started example, `examples/hash/gettingStarted.conf`, as
`build/nginx.conf` with the data file paths filled in. You then start nginx
and send it a request with `curl`. Run each command from the repository root
unless the step says otherwise. There are no cloud examples, because the
modules work only on-premise, with a data file.

### Prerequisites

- Linux. The module is built and tested on Linux only, on Ubuntu in CI. On
  Windows, use WSL, and clone inside WSL as "Pitfalls" explains. On macOS, use
  the Docker example at the end of "Run".
- The build tools the README lists, which are a C compiler that supports C11,
  `make`, zlib, PCRE and `libatomic`.
- `curl`, which the Makefile uses to download the nginx source from nginx.org,
  and which sends the requests.
- `gzip` and `md5sum`, which the data repository's download script needs
  beside `curl`, and network access to `distributor.51degrees.com` for the
  data files.
- Git.

On Ubuntu, CI installs the build tools with this command, on runners that
already have gcc.

```
sudo apt-get install make zlib1g-dev libpcre3 libpcre3-dev
```

Clone the repository with its submodules.

```
git clone --recurse-submodules https://github.com/51Degrees/51degrees-nginx.git
cd 51degrees-nginx
```

In a clone made without `--recurse-submodules`, fetch the submodules.

```
git submodule update --init --recursive
```

### Data files

The examples use free data files, which need no licence key. They are not
stored in this repository. The `cxx` submodule holds the
[data](https://github.com/51Degrees/data) repository as `cxx/data`, which has a
link to each file, and a script downloads them into `cxx/data/device-detection`
and `cxx/data/ip-intelligence`, where the `FILEPATH :=` and `FILEPATH_IPI :=`
lines in `Makefile` look for them. `make install` runs that script for the
free file its `API` uses when it is missing (both for `mixed`), `make test`
for the Lite file and `make test-examples` for both, so a fresh clone needs no
step of its own. To fetch both before building, run the script yourself.

```
sh cxx/data/get-data-files.sh 51Degrees-LiteV4.1.hash 51Degrees-IPIV4AsnIpiV41.ipi
```

The script keeps a file that is already there. A file named with
`51DEGREES_DD_PATH` or `51DEGREES_IPI_PATH` is never downloaded.

#### Check the files

- `cxx/data/device-detection/51Degrees-LiteV4.1.hash` is more than 10 MB.
- `cxx/data/ip-intelligence/51Degrees-IPIV4AsnIpiV41.ipi` is more than 1 MB.

### Build

```
make install FIFTYONEDEGREES_NGINX_VERSION=1.29.3
```

1.29.3 is the nginx version of the first entry in `ci/options.json`, which CI
builds and tests. Without the variable the Makefile builds nginx 1.20.0, which
CI no longer builds. The build downloads the nginx source into `vendor`, builds
both modules into `build/modules`, puts the nginx program at `./nginx`, writes
`build/nginx.conf` from `examples/hash/gettingStarted.conf`, and creates the
empty file `build/html/hash` that the example serves.

### Run

Start nginx. The example configuration runs it in the background
(`daemon on`), listening on `127.0.0.1:8080`.

```
./nginx
```

Send the request that `examples/hash/gettingStarted.conf` documents.

```
curl localhost:8080/hash -I -A "Mozilla/5.0 (iPhone; CPU iPhone OS 7_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D167 Safari/9537.53"
```

Stop nginx.

```
./nginx -s quit
```

For IP Intelligence, build again with `API=ipi`, which writes
`build/nginx.conf` from `examples/ipi/gettingStarted.conf` and creates
`build/html/ipi`. Stop nginx first, because `make install` starts by deleting
`build` and `./nginx`.

```
make install API=ipi FIFTYONEDEGREES_NGINX_VERSION=1.29.3
./nginx
curl "localhost:8080/ipi?client_ip=212.58.224.22" -I
./nginx -s quit
```

The `client_ip` query argument carries the address to look up, because the
address the request really comes from is the loopback address, which has no
network to report. `API=mixed` works in the same way for
`examples/mixed/gettingStarted.conf`, which loads both modules and answers at
`/mixed`. The request it documents is
`curl "localhost:8080/mixed?client_ip=212.58.224.22" -I -A "<the User-Agent above>"`.

The other Device Detection examples run in the same way with `EXAMPLE`, which
names the example in `examples/hash` that `make install` writes as
`build/nginx.conf`. `make install EXAMPLE=config` writes
`examples/hash/config.conf` and creates `build/html/config`, which it serves
at `/config`. `EXAMPLE=matchMetrics` answers at `/metrics`,
`EXAMPLE=matchQuery` at `/query?user_agent=<a User-Agent>`, and
`EXAMPLE=responseHeaders/responseHeader` at `/response.html`. Each example's
comment gives its request.

On macOS, or anywhere Docker runs, the curl example builds the module in a
Debian image.

```
cd examples/curl
docker build -t 51d-nginx-curl .
docker run -d -p 8080:8080 51d-nginx-curl
```

Then send the request that `examples/curl/README.md` gives, which asks for
`http://127.0.0.1:8080/hash`. The image clones `main` from GitHub rather than
using your checkout, builds the Makefile's default nginx 1.20.0, and loads only
the Device Detection module, with `examples/curl/nginx.conf`.

### Correct output

The Device Detection request answers with these lines among the response
headers, as `examples/hash/gettingStarted.conf` documents.

```
HTTP/1.1 200 OK
...
x-device: Mobile Safari,iOS
x-mobile: True
x-hardware: NoMatch,NoMatch,NoMatch
x-enterprise: Some of these properties need the Enterprise data file. Contact us for a copy at https://51degrees.com/contact-us?utm_source=code&utm_medium=example&utm_campaign=51degrees-nginx&utm_content=examples-hash-gettingstarted.conf&utm_term=enterprise-data-file
...
```

`x-device-hinted` has the same form, a browser name and a platform name
separated by a comma. `x-hardware` reads `NoMatch` for HardwareVendor,
HardwareName and DeviceType, which only the Enterprise data file has, and
`x-enterprise`, which is there only when they read `NoMatch`, says where to ask
for a copy. With the Enterprise data file `x-hardware` holds their values and
there is no `x-enterprise` header.

The IP Intelligence request answers with these lines, as
`examples/ipi/gettingStarted.conf` documents.

```
HTTP/1.1 200 OK
...
x-asn-query: \"BBC\":1
x-location-query: NoMatch,NoMatch,NoMatch
x-enterprise: Some of these properties need the Enterprise data file. Contact us for a copy at https://51degrees.com/contact-us?utm_source=code&utm_medium=example&utm_campaign=51degrees-nginx&utm_content=examples-ipi-gettingstarted.conf&utm_term=enterprise-data-file
...
```

`x-asn` holds the answer for the address the request came from. IP
Intelligence values take the form `"value":weight`, with each double quote
escaped by a backslash in the header. A property the data file does not have
reads `NoMatch` in both modules (`FIFTYONE_DEGREES_PROPERTY_NOT_AVAILABLE` in
`51Degrees_hash_module/ngx_http_51D_module.c`, and its IP Intelligence
counterpart). `x-location-query` reads `NoMatch` for Country, Latitude and
Longitude, which only the Enterprise data file has, and `x-enterprise` says
where to ask for a copy. The mixed example answers with the headers of both.
The Docker request answers with `x-platform-name`, `x-browser-name`,
`x-is-mobile` and the other headers that `examples/curl/README.md` shows, and
`x-device-type: NoMatch`, because the Lite file has no DeviceType, with
`x-enterprise` saying where to ask for a copy. The configuration and match
metrics examples answer with `x-hardware` and `x-enterprise` in the same way,
and the JavaScript example's `/overrides` adds `x-enterprise` when the data file
has no ScreenPixelsWidthJavascript.

The Enterprise data files have many more properties.
[Contact us](https://51degrees.com/contact-us?utm_source=github&utm_medium=docs&utm_campaign=51degrees-nginx&utm_content=agents.md&utm_term=correct-output)
for a copy.

### Cloud examples

There are none. The nginx modules work only on-premise, with a data file.

### Pitfalls

- **A data file that is not there.** `cxx/data` holds a `.link` for each file
  rather than the file. nginx then does not start, and its error log,
  `build/logs/error.log`, has a line starting with `51Degrees` that describes
  the data file. This happens when a build names a file that is not there,
  or when the download in `make install` failed. Download the files and check
  their sizes as above.
- **Missing submodules.** `make install` then stops at its first
  `cp cxx/src/...`, because the module sources come from the `cxx` submodule.
  A zip download of the repository has no submodules, so clone with Git.
- **The nginx version.** Plain `make install` builds nginx 1.20.0. Give
  `FIFTYONEDEGREES_NGINX_VERSION` as "Build" shows, so that you build a
  version CI tests.
- **Linux only.** The Makefile uses GNU `sed -i` and links `-latomic`, and the
  README says only Linux is supported. Use WSL on Windows and Docker on macOS.
- **Windows line endings.** This repository's `.gitattributes` keeps LF line
  endings for its own files, whatever `core.autocrlf` says. `cxx` has no
  `.gitattributes`, and `cxx/data` keeps LF only for its shell script and its
  links, so a checkout made by Git for Windows, which usually sets
  `core.autocrlf=true`, gives their other text files, such as the IP
  Intelligence evidence files, Windows line endings. Clone inside WSL, not on
  a Windows drive.
- **`make install` deletes the build.** It runs the `clean` target first,
  which removes `./nginx` and `build`, and with `build` the pid file that
  `./nginx -s quit` needs. Stop nginx before building again, or the old nginx
  keeps port 8080 and the new one cannot start.
- **A path with nothing to serve.** nginx's
  [`add_header`](http://nginx.org/en/docs/http/ngx_http_headers_module.html#add_header)
  adds a header only to some response codes, such as 200 and not 404, so ask
  for the path the example serves, such as `/hash` or `/ipi`.
  `examples/curl/curl.sh` asks for `/mixed`, which the Docker image does not
  serve, so it gets `404 Not Found` with no 51Degrees headers. Use the request
  in `examples/curl/README.md` instead.
- **What CI tests.** CI builds with the paid `TAC-HashV41.hash`
  (`51DEGREES_DD_PATH` in `ci/build-project.ps1` and the test scripts), and
  runs the example tests on it and again on the free Lite file, which a fresh
  clone uses. `ci/fetch-assets.ps1` downloads the Lite and Asn files with the
  data repository's script, as the steps here do.

## Building the modules

The Makefile copies the C sources from `cxx/src` into `src` folders inside
`51Degrees_hash_module` and `51Degrees_ipi_module`, which git ignores, and
rewrites their include paths. nginx has no compiler flags for one module, so
the Makefile adds the IP Intelligence defines (`FIFTYONE_DEGREES_LARGE_DATA_FILE_SUPPORT`,
`FIFTYONE_DEGREES_REDUCED_FILE` and `_FILE_OFFSET_BITS`) to the top of each
copied IP Intelligence source. They must match the defines in
`ngx_http_51D_ipi_module.c`. Each module carries its own copy of common, so
only one of them can be linked statically.

## CI

The workflows call the shared workflows in
[common-ci](https://github.com/51Degrees/common-ci), which run the scripts in
`ci/`. `ci/options.json` lists the nginx versions CI builds and tests.
`ci/update-packages.ps1` rewrites it from the NGINX Plus releases page in the
nightly package update, so do not edit the versions by hand. The nightly
submodule update moves `cxx` with a pull request into `rc`.

## Versions

`ci/get-next-package-version.ps1` works out the version from the release tags
with GitVersion and common-ci's `GitVersion.yml`, so each release moves only
the patch number. Never move the major or minor number, and never add a
`+semver:` directive to a commit.
