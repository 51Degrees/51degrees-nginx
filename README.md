# 51Degrees Device Detection and IP Intelligence for NGINX

<img src=".github/images/logo.png" alt="51Degrees" title="Data rewards the curious" width="160">

**Real-Time Data in C** NGINX module

Our User-Agent parser for NGINX supports Device Detection, browser detection, mobile detection, and crawler detection on-premise on Linux. IP Intelligence adds IP geolocation, including IP to country data.

It reads User-Agent and User-Agent Client Hints, HTTP request headers that carry browser and device information.

## Install

For installation prerequisites and pre-built binaries, see the getting started and build sections below.

```
make install
```

Try the [User-Agent tester](https://51degrees.com/developers/user-agent-tester?utm_source=github&utm_medium=readme&utm_campaign=51degrees-nginx&utm_content=readme.md&utm_term=install) and [IP tester](https://51degrees.com/developers/ip-tester?utm_source=github&utm_medium=readme&utm_campaign=51degrees-nginx&utm_content=readme.md&utm_term=install).

This repository was renamed from `device-detection-nginx` and continues that work.

### Example

This directive sets the request header `x-device` to the device's hardware, browser and platform names:

```
51D_match_all x-device HardwareName,BrowserName,PlatformName;
```

[Developer documentation](https://51degrees.com/documentation/_device_detection__other_integrations__nginx.html?utm_source=github&utm_medium=readme&utm_campaign=51degrees-nginx&utm_content=readme.md&utm_term=51degrees-real-time-data-nginx-module)

# Introduction 
This project integrates the 51Degrees real-time data engines as modules to NGINX, allowing users to configure NGINX to enrich requests with real-time data by setting corresponding 51Degrees directives in the NGINX configuration file. Two engines are available, the Device Detection V4 engine which provides device properties from request headers, and the IP Intelligence engine which provides network and location properties from the client IP address. Each engine is built as its own dynamic module (`ngx_http_51D_module` for Device Detection and `ngx_http_51D_ipi_module` for IP Intelligence) and the modules can be loaded together or independently. Currently only Linux platform is supported.

# Getting started
Before following the quick start, make sure to have NGINX installed and have a 51Degrees data file ready to use. The NGINX executable can be installed and built as instructed in the [Build and Test](#build-and-test-linux) section.

## Data files

In order to use the module, you will need at least one 51Degrees data file. Each engine has its own data file format, a `.hash` file for Device Detection and a `.ipi` file for IP Intelligence.

### Device detection data file

The free, 'lite' file `51Degrees-LiteV4.1.hash` has a significantly reduced
set of properties. To obtain a file with a more complete set of device
properties see the
[51Degrees website](https://51degrees.com/pricing?utm_source=github&utm_medium=readme&utm_campaign=51degrees-nginx&utm_content=readme.md&utm_term=device-detection-data-file).

The free data files are not stored in this repository. The `cxx/data`
sub-module, which is the [data](https://github.com/51Degrees/data)
repository, holds a link to each one, and its script downloads each file
beside its link. Run this from the root of this repository.

```
sh cxx/data/get-data-files.sh 51Degrees-LiteV4.1.hash
```

This saves the file as `cxx/data/device-detection/51Degrees-LiteV4.1.hash`.
A file that is already there is kept. Add `-u` to replace it when a newer
version is available.

`make install`, `make test` and `make test-examples` run the script for the
free file they use by default when it is missing, so a fresh clone needs no
step of its own. A file named with `_51DEGREES_DD_PATH` or `_51DEGREES_IPI_PATH`
is never downloaded, and make stops with that name when the file is missing.

### IP Intelligence data file

The free `51Degrees-LiteV41.ipi` file contains the registration properties (RegisteredCountry, RegisteredName and RegisteredOwner). This file is used by default for the IP Intelligence examples and tests. Download it in the same way.

```
sh cxx/data/get-data-files.sh 51Degrees-LiteV41.ipi
```

This saves the file as `cxx/data/ip-intelligence/51Degrees-LiteV41.ipi`.

The same script downloads a second free IP Intelligence data file, `51Degrees-IPIV4AsnIpiV41.ipi`, which is far smaller and has the Asn properties (Asn and AsnName) instead. The performance test uses it. Note that the version of the downloaded data file must match the version expected by the IP Intelligence sources in the cxx sub-module, as with any 51Degrees data file. To obtain a file with the complete set of properties see the [51Degrees website](https://51degrees.com/pricing?utm_source=github&utm_medium=readme&utm_campaign=51degrees-nginx&utm_content=readme.md&utm_term=ip-intelligence-data-file).

## Quick start (Device Detection)

To quickly start using 51Degrees module with NGINX, please follow the below steps:
- Install an NGINX version 1.19.0 or above.
- Obtain a 51Degrees data file. The free Lite file is downloaded by the script in the [data](https://github.com/51Degrees/data) repository, for example with `git clone --depth 1 https://github.com/51Degrees/data.git && sh data/get-data-files.sh 51Degrees-LiteV4.1.hash`, which saves it as `data/device-detection/51Degrees-LiteV4.1.hash`.
- Download the pre-built binaries at our [GitHub release page](https://github.com/51Degrees/51degrees-nginx/releases).
- Choose the binary for the version of NGINX that you want to use.
- Create a folder which we will use for this quick start.
- In the folder:
  - Create a NGINX configuration file and paste the following content, replacing the path in `load_module` and `51D_file_path` with the actual path to the downloaded module and the downloaded data file.
```
# Specify the module to load. 
load_module [path to 51Degrees module];

events {
}

http {
    # Specify the data file to use
    51D_file_path [path to 51Degrees data file];
    server {
        listen 8888;

        location /test {
            # Perform a detection using a single User-Agent header.
            # Set the request header 'x-mobile' to returned value for property 'IsMobile'.
            51D_match_ua x-mobile IsMobile;

            # Set the response header 'x-mobile' using the request header 'x-mobile'.
            add_header x-mobile $http_x_mobile;
        }
    }
}
```
  - Create a folder named `html` and an empty file `test` in that folder. This is because we are serving static content in the above config file and the root directory to serve requests is defaulted at `html`.
  - Create a folder named `logs` for nginx to write its log messages to.
- In the quick start folder, start NGINX using the following command:
```
nginx -p . -c nginx.conf
```
    - The `-p` flag tells NGINX to set the prefix path which NGINX will use.
    - The `-c` flag tells NGINX to use the config file that we just created.
- Install curl if you haven't.
- Fire a request and see the result being sent back in the response using the following command:
```
curl -H 'User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 7_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D167 Safari/9537.53' http://localhost:8888/test -I
```
  - You should see the `x-mobile: True` in the response header, indicating that NGINX has successfully used 51Degrees Device Detection engine to detect that client User-Agent is a mobile device using the input 'User-Agent' header.
- At this point you can terminate the NGINX server using:
```
nginx -p . -s quit
```

## Quick start (IP Intelligence)

IP Intelligence works in the same way, using its own module, data file and match directive. The following configuration sets a request header from the registered name of the network of the client IP address, or of an IP address supplied as a query argument. The RegisteredName property is in the free `51Degrees-LiteV41.ipi` file, which is downloaded as described in [Data files](#data-files), with RegisteredCountry and RegisteredOwner. The free `51Degrees-IPIV4AsnIpiV41.ipi` file has AsnName and Asn instead, and the Enterprise file has every property, each requested in the same way.
```
# Specify the module to load. Add an additional load_module line for the
# device detection module to use both engines together.
load_module [path to 51Degrees IP intelligence module];

events {
}

http {
    # Specify the IP intelligence data file to use
    51D_file_path_ipi [path to 51Degrees IP intelligence data file];
    server {
        listen 8888;

        location /test {
            # Perform a match using the client IP address.
            # Set the request header 'x-registered-name' to the returned
            # value for property 'RegisteredName'.
            51D_match_ipi x-registered-name RegisteredName;

            # Perform a match using the IP address supplied in the
            # 'client_ip' query argument.
            51D_match_ipi x-registered-name-query RegisteredName $arg_client_ip;

            # Set the response headers using the request headers.
            add_header x-registered-name $http_x_registered_name;
            add_header x-registered-name-query $http_x_registered_name_query;
        }
    }
}
```
Fire a request and see the result being sent back in the response using the following command:
```
curl "http://localhost:8888/test?client_ip=212.58.224.22" -I
```
Values are returned in the form `"value":weight` where the weight indicates the confidence the engine has in the value.

Note the use of the `client_ip` query string argument here and throughout the examples and tests. When running on a local machine the client IP address reported by NGINX is a loopback or private network address, which has no useful IP Intelligence associated with it. Passing a real IP address in the `client_ip` query string argument, read by the `51D_match_ipi` directive through the `$arg_client_ip` variable, overrides the reported client IP address for that match. In production, where requests arrive from real client IP addresses, the variable argument can be omitted so the match uses the client IP address directly, or pointed at another variable such as a forwarded header from an upstream proxy.

The IP address is read only when all of the value is one IPv4 or IPv6 address, which may have a port, as in `212.58.224.22:80` or `[2001:db8::1]:80`, as the [IP Intelligence specification](https://github.com/51Degrees/specifications/blob/6570727d2af6967390d3c4fbec77b9cf0540d3f3/ip-intelligence-specification/pipeline-elements/ip-intelligence-on-premise.md#reading-the-client-ip-value) says. Any other value gives `NoMatch` and is not logged as an error, such as a list like the value of `X-Forwarded-For`, a prefix length like `/24`, or text after the address. The first address in a list is not always one you can trust, so choose the address in the configuration, for example with the [real IP module](https://nginx.org/en/docs/http/ngx_http_realip_module.html).

The above gave you a quick overview of how to use the 51Degrees NGINX module. However, that used a pre-built binaries of 51Degrees module, and in some cases, it might not work on your target machine due to the differences in the build environment that was used. In those cases, you will have options to rebuild the module yourself. This is detailed in the [Build and Test](#build-and-test-linux) section.

## Latest releases
The latest releases of 51Degrees NGINX module can be found on [GitHub](https://github.com/51Degrees/51degrees-nginx/releases).

For the supported platforms and NGINX version, please check the [tested versions page](https://51degrees.com/documentation/_product_summaries__tested_versions.html?utm_source=github&utm_medium=readme&utm_campaign=51degrees-nginx&utm_content=readme.md&utm_term=latest-releases) for latest update. At the time of writing, the followings are tested by the continuous integration pipeline:
- Platform Ubuntu (ubuntu-latest), 64bit.
- NGINX version: 1.27.2, 1.27.4, 1.29.0 and 1.29.3

Pre-built modules are published for the NGINX versions listed by the `all-versions` target in the Makefile. Older versions back to 1.19.0 are expected to work as the module accounts for API changes across this range, but they are no longer routinely tested.

## API references
Below is the list of directives that can be used with the 51Degrees modules. The `51D_*_ipi` directives are provided by the IP intelligence module (`ngx_http_51D_ipi_module`) and all the others by the device detection module (`ngx_http_51D_module`).

|Directives|
|---------|
|Syntax: `51D_file_path` *filename*;<br>Default: ---<br>Context: main<br>Specify the data file to used for 51Degrees Device Detection V4 engine|
|Syntax: `51D_file_path_ipi` *filename*;<br>Default: ---<br>Context: main<br>Specify the data file to be used for 51Degrees IP Intelligence engine|
|Syntax: `51D_value_separator_ipi` *separator*;<br>Default: 51D_value_separator_ipi ',';<br>Context: main<br>Specify the separator to be used in the value string returned from an IP intelligence match.|
|Syntax: `51D_performance_profile_ipi` *HIGH_PERFORMANCE \| IN_MEMORY*;<br>Default: 51D_performance_profile_ipi HIGH_PERFORMANCE;<br>Context: main<br>Specify how much of the IP Intelligence data file is held in shared memory. `HIGH_PERFORMANCE` holds only what the properties named in `51D_match_ipi` directives read, and the whole file when none or all of them are named. `IN_MEMORY` always holds the whole file. See [IP Intelligence performance profile](#ip-intelligence-performance-profile).|
|Syntax: `51D_drift` *drift*;<br>Default: 51D_drift 0;<br>Context: main<br>Specify the drift value that a detection can allow.|
|Syntax: `51D_difference` *difference*;<br>Default: 51D_difference 0;<br>Context: main<br>Specify the difference value that a detection can allow.|
|Syntax: `51D_allow_unmatched` *on \| off*;<br>Default: 51D_allow_unmatched off;<br>Context: main<br>Specify if unmatched should be allowed.|
|**DEPRECATED** Syntax: `51D_use_performance_graph` *on \| off*;<br>Default: 51D_use_performance_graph off;<br>Context: main<br>Specify if performance graph should be used in detection. **DEPRECATED**: Has no effect on configuration, the data file has a single (predictive) graph that is always used.|
|**DEPRECATED** Syntax: `51D_use_predictive_graph` *on \| off*;<br>Default: 51D_use_predictive_graph on;<br>Context: main<br>Specify if predictive graph should be used in detection. **DEPRECATED**: Has no effect on configuration, the data file has a single graph that is always used.|
|Syntax: `51D_value_separator` *separator*;<br>Default: 51D_value_separator ',';<br>Context: main<br>Specify the separator to be used in the value string returned from a detection. Each value in the returned result string is correspond to a requested property.|
|Syntax: `51D_match_ua` *header* *properties* \[*argument*\];<br>Default: ---<br>Context: main, server, `location` (**NOTE**: This directive can be used in main, server and location blocks. Specified properties are aggregated and eventually queried in the location. *header* value is set after the query is performed and is only available within `location` block)<br>Perform a detection using a single request header `User-Agent`. *header* specifies which request header the returned *properties* values should be stored at. *properties* is a comma separated list string. *argument* specifies if a `User-Agent` is supplied as a query argument. This will override the value in the `User-Agent` header. The *argument* is optional. Where the variable is empty, or not set for the request, the `User-Agent` header is used instead. A match is only reused when it was made for the same `User-Agent` in the same request.<br>If a property is not available for any reason, the value being returned for that property will be `NA`<br>This directive was previously known as `51D_match_single` (name deprecated)|
|Syntax: `51D_match_ua_client_hints` *header* *properties* \[*argument*\];<br>Default: ---<br>Context: main, server, `location` (**NOTE**: This directive can be used in main, server and location blocks. Specified properties are aggregated and eventually queried in the location. *header* value is set after the query is performed and is only available within `location` block)<br>Perform a detection using request headers `User-Agent` and `Sec-CH-UA-*`. *header* specifies which request header the returned *properties* values should be stored at. *properties* is a comma separated list string. *argument* specifies if a `User-Agent` is supplied as a query argument. This will override the value in the `User-Agent` header. The *argument* is optional. Where the variable is empty, or not set for the request, the `User-Agent` header is used instead.<br>If a property is not available for any reason, the value being returned for that property will be `NA`|
|Syntax: `51D_match_all` *header* *properties*;<br>Default: ---<br>Context: main, server, `location` (**NOTE**: This directive can be used in main, server and location blocks. Specified properties are aggregated and eventually queried in the location. *header* value is set after the query is performed and is only available within `location` block)<br>Perform a detection using all headers, query argument and cookie from a http request. *header* specifies which request header the returned *properties* values should be stored at. *properties* is a comma separated list string.<br>If a property is not available for any reason, the value being returned for that property will be `NA`|
|Syntax: `51D_match_ipi` *header* *properties* \[*argument*\];<br>Default: ---<br>Context: main, server, `location` (**NOTE**: This directive can be used in main, server and location blocks. Specified properties are aggregated and eventually queried in the location. *header* value is set after the query is performed and is only available within `location` block)<br>Perform an IP intelligence match using the client IP address. *header* specifies which request header the returned *properties* values should be stored at. *properties* is a comma separated list string. *argument* specifies a variable (e.g. a query argument such as `$arg_client_ip`) holding an IP address to be used in place of the client IP address. The *argument* is optional. Where the variable is empty, or not set for the request, the client IP address is used instead. A lookup is only performed when the IP address differs from the one already matched for the request, otherwise the existing result is reused.<br>If a property is not available for any reason, the value being returned for that property will be `NoMatch`. Requires `51D_file_path_ipi` to be set.|
|Syntax: `51D_get_javascript_single` *javascript_property* \[*argument*\];<br>Default: ---<br>Context: location<br>Perform a detection using a single request header `User-Agent`. The returned value of *javascript_property* is set in the response body. This works in a similar way as CDN to serve static content. *argument* specifies if a `User-Agent` is supplied as a query argument. This will override the value in the `User-Agent` header. The *argument* is optional. Where the variable is empty, or not set for the request, the `User-Agent` header is used instead.<br>If the Javascript property is not available for any reason, a Javascript block comment will be returned so that it will not cause syntax error when the client executes it.<br>The whole response body is used for the returned content so only one of these directives can be used in a single location block. Also, since the static content does not actually exist as a static file, the nginx http core module will log an error, so it is recommended to use this directive with [log_not_found](http://nginx.org/en/docs/http/ngx_http_core_module.html#log_not_found) set to off.|
|Syntax: `51D_get_javascript_all` *javascript_property*;<br>Default: ---<br>Context: location<br>Perform a detection using all headers, cookie and query arguments from a http request. The returned value of the *javascript_property* is set in the response body. This works in a similar way as CDN to serve static content.<br>If the Javascript property is not available for any reason, a Javascript block comment will be returned so that it will not cause syntax error when the client executes it.<br>The whole response body is used for the returned content so only one of these directives can be used in a single location block. Also, since the static content does not actually exist as a static file, the nginx http core module will log an error, so it is recommended to use this directive with [log_not_found](http://nginx.org/en/docs/http/ngx_http_core_module.html#log_not_found) set to off.|
|Syntax: `51D_set_resp_headers` *on \| off*;<br>Default: 51D_set_resp_headers  off<br>Context: main, server, location<br>Allow Client Hints to be set in response headers where it is applicable to the user agent (e.g. Chrome 89 or above) so that more evidence can be returned in subsequent requests, allowing more accurate detection. Value set in a block overwrites values set in precedent blocks (e.g. value set in `location` block will overwrite value set in `server` and `main` blocks). This will only be available from the 4.3.0 version onwards.<br>Each response this applies to makes a match of all the headers, cookies and query arguments of its request, in the same way as `51D_match_all`, and its headers are set from the `SetHeader` properties of that match. A property whose value is `Unknown` adds nothing, each client hint is listed once, and a header with nothing to list is not set, so a browser which does not support Client Hints is sent no `Accept-CH` header.|

## Required properties
The properties named in the Device Detection match and javascript directives form the required properties which the engine is initialized with. Detection only evaluates the components which the required properties belong to, so naming only the properties that are needed makes each match faster and reduces the shared memory size. Match metric properties (Drift, Difference, Method, MatchedNodes, UserAgents and DeviceId) are computed from the match itself and do not affect initialization. Directives which match on multiple headers also initialize the JavascriptGetHighEntropyValues property, so that decoded GetHighEntropyValues evidence can contribute to the match. All of the data file's properties are initialized when no data set properties are named in any directive, or when `51D_set_resp_headers` is on, as the SetHeader properties it uses are discovered from the data file rather than named in directives. The IP Intelligence module initializes its engine with the properties named in `51D_match_ipi` directives in the same way.

## IP Intelligence performance profile
The IP Intelligence module uses the HighPerformance profile of the engine unless `51D_performance_profile_ipi` names another. When the `51D_match_ipi` directives name some of the data file's properties, HighPerformance holds in shared memory only what those properties read, which is the data of their components, their values and the strings of those values. A lookup that reads them reads nothing from the file. Naming only the properties that are needed therefore saves memory. With the Enterprise data file and only Asn and AsnName named, the engine holds 116 MB, where holding everything takes 6,356 MB, as measured in [51degrees-cxx#114](https://github.com/51Degrees/51degrees-cxx/pull/114). When no properties are named, or every one is, HighPerformance holds the whole file.

The master process reads the data file into shared memory once, before it starts the worker processes, which all read from that memory. The rest of the file stays on disk, so the master keeps the data file open and each worker inherits its handles. The handles are listed in the shared memory and a worker takes one from the list to read, so only one process reads through a handle at a time. A reload closes the master's handles to the file it replaces, so a data file that has been replaced on disk frees its space once the workers that used it have stopped.

`IN_MEMORY` holds the whole data file in shared memory and keeps no handle to it, as earlier releases of the module did. The module logs the profile it uses and the size of its shared memory, at the `notice` level, each time it loads the data file. The engine's Balanced and LowMemory profiles are not offered. Balanced reads through caches that change during lookups, and the memory they add and the locks that guard them belong to one process, so the workers cannot share them. LowMemory reads every lookup from the file through the handles the workers share, and a worker waiting for a handle can only be woken by a thread of its own process.

## Header length limit
A single header such as `User-Agent`, or a pseudo header (several headers read as one), is ignored if it is over 500 bytes. Detection carries on with the rest of the evidence and nothing is logged, so the answer is the same as for a request without that header. Neither module has a directive to raise the limit.

## Proxy passing
When using the `proxy_pass` directive in a location block where a match directive is used, the properties selected are passed as additional HTTP headers with the name specified in the first argument of `51D_match_ua`/`51D_match_ua_client_hints`/`51D_match_all`/`51D_match_ipi`.

## Fast-CGI
Using `include fastcgi_params;` makes these additional headers available via the `$_SERVER` variable.

## Match metrics
Other than detection properties, users can request further metrics of a match in the same way. The available metrics are Drift, Difference, Method, MatchedNodes, User-Agents and DeviceId.
e.g.
```
51D_match_all x-metrics Drift,Difference,Method,MatchedNodes,DeviceId,UserAgents
```

## Output format
The value of the header is set to a comma separated list of values (comma delimited is the default behavior, but the delimiter can be set explicitly with `51D_value_separator`), these are in the same order the properties are listed in the config file. So setting a header with the line:
```
51D_match_all x-device HardwareName,BrowserName,PlatformName;
```
will give a header named `x-device` with a value like `Desktop,Firefox,Ubuntu`. Alternatively, headers can be set individually like:
```
51D_match_all x-hardware HardwareName;
51D_match_all x-browser BrowserName;
51D_match_all x-platform PlatformName;
```
giving three separate headers.

Values returned by `51D_match_ipi` take the form `"value":weight` where the weight is a number between 0 and 1 indicating the confidence the engine has in the value. A property may return more than one weighted value separated by a pipe. The double quotes are escaped with a backslash when set in a header.

## Examples
All examples are located in the `examples` folder. Device detection examples are in the `hash` sub-folder, IP Intelligence examples are in the `ipi` sub-folder, and examples using both engines together are in the `mixed` sub-folder:
|Example|Description|
|-------|-----------|
|gettingStarted.conf|Shows a simple instance of how to use 51D_match_ua, 51D_match_ua_client_hints and 51D_match_all in a configuration file.|
|ipi/gettingStarted.conf|Shows a simple instance of how to use 51D_match_ipi in a configuration file, both with the client IP address and with an IP address from a query argument.|
|mixed/gettingStarted.conf|Shows how to load the Device Detection and IP Intelligence modules together and use 51D_match_all and 51D_match_ipi in the same location.|
|config.conf|Shows how to configure 51Degrees detection using directives such as 51D_drift, 51D_difference, etc...|
|matchQuery.conf|Shows how to perform detection using input from http request query argument|
|matchMetrics.conf|Shows how to obtain other match metrics of the detection such as drift, difference, method and etc...|
|responseHeaders|Shows how to enable Client Hints support to request further evidence from User-Agent to provide more accurate detection. This will only be available from the 4.3.0 version onwards.|
|jsExample|Shows how to use 51D_get_javascript* directive to get the JavaScript to obtain further evidences from the client. To run this example, start NGINX with the included `javascript.conf` set as the configuration file. Once NGINX fully start, open `index.html` in a browser to see that the screen width is now set correctly.|
<br>

To run an example, `make install` writes the getting started example for `_51DEGREES_API` as `build/nginx.conf`, and `_51DEGREES_EXAMPLE` names another in `examples/hash`, for example `make install _51DEGREES_EXAMPLE=config`, filling in its data file and creating the file it serves. Each example's comment gives its request.

# Build and test (Linux)
Before build and test the 51Degrees module, make sure to check out the project and all of its sub-modules.

The module is built and tested on Linux. On Windows, use WSL with the repository checked out with LF line endings. The `.gitattributes` file enforces LF in the working tree, so a normal clone works regardless of the `core.autocrlf` setting. A checkout made before the `.gitattributes` file was added can be renormalized with `git rm -rq --cached . && git reset --hard`. All `make` targets and test scripts then run from the same checkout inside WSL.

## Fetching sub-modules

This repository has sub-modules that must be fetched.
If cloning for the first time, use:

```
git clone --recurse-submodules https://github.com/51Degrees/51degrees-nginx.git
```

If you have already cloned the repository and want to fetch the sub modules, use:

```
git submodule update --init --recursive
```

If you have downloaded this repository as a zip file then these sub modules need to be downloaded separately as GitHub does not include them in the archive. The data files are downloaded separately in any case, as described in [Data files](#data-files).

Earlier versions read the data files from the `cxx/device-detection-data` and `cxx/ip-intelligence-data` sub-modules. They are now read from `cxx/data/device-detection` and `cxx/data/ip-intelligence`, so move any data file you added to an old folder into the matching new one. The build, tests and examples no longer read the old folders. When a later version of cxx removes them, Git leaves them on disk, so delete them then.

## Build

To build the 51Degrees module, the following libraries are required.
- C compiler that support C11 or above.
- make
- zlib1g-dev
- libpcre2-dev, which NGINX reads from 1.21.5. NGINX before 1.21.5 reads only PCRE1 (`libpcre3-dev`), which Ubuntu 26.04 does not have.
- libatomic

To build the modules only, run the following command. This will output `ngx_http_51D_module.so` and `ngx_http_51D_ipi_module.so` in the `build/modules` directory.
```
make module
```
<br>

To build the modules and NGINX, run the following command.
```
make install
```
By default this builds NGINX 1.29.3, the newest version CI builds and tests. To build another version of NGINX, run the above command with the `_51DEGREES_NGINX_VERSION` variable, for example.
```
make install _51DEGREES_NGINX_VERSION=[Version]
```
<br>

To build and link a module statically with NGINX, use the `_51DEGREES_STATIC_BUILD` variable. Only one of the modules can be linked statically into a binary as each carries its own copy of the common 51Degrees sources. The module is selected with the `_51DEGREES_API` variable which defaults to `hash` (Device Detection). e.g.
```
make install _51DEGREES_STATIC_BUILD=1
make install _51DEGREES_STATIC_BUILD=1 _51DEGREES_API=ipi
```
<br>

The NGINX executable will be output to the project root directory. The prefix path of the NGINX will be set to `build` directory. A `nginx.conf` is also included with a simple example of `51D_match_ua`, `51D_match_ua_client_hints` and `51D_match_all` directives, set in a static content location. The build process has created the static file in the `build/html` folder so you can start NGINX and start sending requests to that static content endpoint.

## Names

Every setting this repository reads is named `_51DEGREES_<NAME>`. Each one can be given on the make command line, and those marked with * also in the environment.

|Name|What it holds|
|----|-------------|
|`_51DEGREES_DD_PATH` *|The path of the Device Detection data file for the build, the tests, and the performance tests. When it is not set, the free Lite file in `cxx/data/device-detection` is used.|
|`_51DEGREES_IPI_PATH` *|The path of the IP Intelligence data file, in the same way. When it is not set, a free file in `cxx/data/ip-intelligence` is used.|
|`_51DEGREES_NGINX_VERSION` *|The version of NGINX to build.|
|`_51DEGREES_API`|The module `make install` writes an example for and a static build links, which is `hash` (the default), `ipi`, or `mixed`.|
|`_51DEGREES_EXAMPLE`|The example in `examples/hash` that `make install` writes as `build/nginx.conf`.|
|`_51DEGREES_STATIC_BUILD` *|When set, links one module into the NGINX binary in place of building modules to load.|
|`_51DEGREES_TEST_OUTPUT` *|The file a test run writes a JUnit report to. See [Test options](#test-options).|
|`_51DEGREES_DONT_CLEAN_TESTS` *|When set, `make clean` keeps the NGINX tests downloaded into `tests/nginx-tests`.|

The Docker example in `examples/curl` takes the build arguments `_51DEGREES_REPOSITORY`, `_51DEGREES_BRANCH`, `_51DEGREES_COMMIT`, and `_51DEGREES_NGINX_VERSION`, which name what the image builds. Its workflow allows `_51DEGREES_START_SECONDS` for the image to answer.

The browser test of the JavaScript example takes the address of the page in `_51DEGREES_EXAMPLE_URL`, which the shared browser test suite reads.

CI reads the secrets `_51DEGREES_LICENSE_KEY`, `_51DEGREES_NGINX_PLUS_KEY`, `_51DEGREES_NGINX_PLUS_CERT`, and `_51DEGREES_NGINX_PLUS_JWT_TOKEN`, which [ci/README.md](ci/README.md) describes.

## Test
All tests are allocated in the `tests` folder.

To be able to test the 51Degrees module the following libraries are required.
- Perl 5 and prove Test::Harness
- CMake 3.24 or above
- .NET 10 SDK, Chrome and Firefox, for the browser test of the JavaScript example
- curl
- grep

Before running any test, make sure to build the project with `make install` command. The tests are designed to test the dynamic build only so `_51DEGREES_STATIC_BUILD` will not work.

To run the 51Degrees tests with the free 51Degrees Lite data file in the `cxx/data/device-detection` directory, download it as described in [Data files](#data-files), then run the following command.
```
make test
```

To run the 51Degrees together with the NGINX test suite, run the following command:
```
make test-full
```

These do not run all the required tests as some tests requires properties that are not supported with the Lite version of the data file. To run all tests, obtain a data file with support properties JavascriptHardwareProfile,ScreenPixelsWidthJavascript and ScreenPixelsWidth. Then, use the `_51DEGREES_DD_PATH` variable to specify the path of the data file to run the tests with. If tests still fail, obtain data file with any other properties used in the tests. Below is an example of running tests with different data file:
```
make [test|test-full] _51DEGREES_DD_PATH=/path/to/51Degrees-EnterpriseV4.1.hash
```

The data file used by the tests is the one `_51DEGREES_DD_PATH` names, given
either in the environment or on the make command line. When it is not set,
the free Lite data file `51Degrees-LiteV4.1.hash` in the
`cxx/data/device-detection` folder is used. When it names a file that does
not exist, make stops and says so.

For example:
```
make test _51DEGREES_DD_PATH=/path/to/51Degrees-EnterpriseV4.1.hash
```

`make test-examples` hands the example tests the two paths as
`_51DEGREES_DD_PATH` and `_51DEGREES_IPI_PATH`. A test run some other way reads
the same names. A device detection test stops with the name when
`_51DEGREES_DD_PATH` is not set or names a missing file. An IP Intelligence
test is skipped when `_51DEGREES_IPI_PATH` is not set, and stops with the name
when it names a missing file.

Note that when running NGINX itself the data file is always specified
explicitly with the `51D_file_path` directive in the configuration file.

The IP Intelligence tests find their data file in the same way. `_51DEGREES_IPI_PATH`, in the environment or on the make command line, provides an explicit path to the file. When it is not set, the free `51Degrees-LiteV41.ipi` file in the `cxx/data/ip-intelligence` folder is used, which is downloaded as described in [Data files](#data-files). For example:
```
make test-examples _51DEGREES_IPI_PATH=/path/to/51Degrees-EnterpriseIpiV41.ipi
```

## Performance test

The project also include a performance test suite. This required `CMake 3.24` or above to be installed.

To run the performance test, please follow the below steps:
- Make sure to build the project with `make install`.
- Download the Lite data file, and the Asn file for the IP Intelligence test, as described in [Data files](#data-files). CMake downloads the evidence records file into `cxx/data/device-detection` when it is missing.
- Navigate to the `tests/performance` directory.
- Create a `build` folder and navigate to it.
- Run:
```
cmake ..
cmake --build .
./runPerf.sh
```
  - This step will build our internal version of `Apache Benchmark` and use it for performance testing.

By default the performance test exercises the Device Detection module, sending the headers of one of 20,000 evidence records with each request. To run the same test against the IP Intelligence module, give `ipi` as the argument:
```
./runPerf.sh ipi
```
This uses the `evidence.yml` file of IP addresses in the `cxx/data/ip-intelligence` folder, with each request carrying an IP address which the `51D_match_ipi` directive reads from the User-Agent header via the `$http_user_agent` variable. The test uses the data file `_51DEGREES_DD_PATH` names for Device Detection and `_51DEGREES_IPI_PATH` for IP Intelligence, and the free Lite and Asn files when they are not set. The nightly CI runs both variants and records a `DetectionsPerSecond` result for each, which feeds the benchmark graphs published from the `gh-images` branch.

# For developers

## Build options
Run the following to build all current supported versions in `modules` folder:
```
make all-versions
```

## Test options
There are number of test options that are recommended for development only.
|Build Option|Description|
|------------|-----------|
|`_51DEGREES_TEST_OUTPUT`|This is available when running the `test`, `test-full`, or `test-examples` target. It names the file that a JUnit test report is written to, e.g. `make test _51DEGREES_TEST_OUTPUT=test.xml`. The report requires the module TAP::Formatter::JUnit to be installed. `cpan` and `cpanm` are recommended to install this module.|

## Memory check
The project can be built with address sanitizer enabled. To do so, run:
```
make mem-check
```
The build options mentioned in the [Build](#build) section are also applicable to this `mem-check` rule. However, it has been observed that, in some version of NGINX such 1.19.0 or 1.20.0, the address sanitizer will report memory leak in NGINX without 51Degrees module loaded. Thus, when develop project, make sure that the error is confirmed to not be generated from the 51Degrees module.

## Stress test
The project also include a stress test. This test is inherited from V3 version of 51Degrees project. This test can be run to compared the performance against V3 version and to see how the 51Degrees module perform under heavy load. Note that, in V4 we have constructed a slightly different approach to performance testing so the output from this test is only used as a reference to compare with V3 version. For actually performance test, please follow the instructions in [Performance Test](#performance-test) section.

To run the stress test, Make sure that the project is built with `make install` and the Apache Benchmark is built as described in the [Performance Test](#performance-test) section, without running `runPerf.sh` script. Then, run the `test.sh` script.
```
./test.sh
```

## Examples test
Before running the tests for the example, make sure to obtain data files that contain all required properties in the examples.

Run the example tests with the obtained data files:
```
make test-examples _51DEGREES_DD_PATH=[Path to obtained data file] _51DEGREES_IPI_PATH=[Path to obtained IP intelligence data file]
```

### JavaScript and overrides example test
The JavaScript and overrides example is tested in Chrome and Firefox by the `ModuleJavaScript` tests of the shared browser test suite, [selenium-api-tests](https://github.com/51Degrees/selenium-api-tests), which finds and starts the browsers and their drivers. `ci/run-integration-tests.ps1` checks the suite out beside this repository and runs it as below. The data file needs the ScreenPixelsWidthJavascript property, which the free Lite data file does not have.
- Start NGINX with `javascript.conf` as described in the file itself, with `index.html` copied to `build/html/jsExample/index.html` so that NGINX serves the page as well.
- Check out the suite beside this repository and run:
```
git clone https://github.com/51Degrees/selenium-api-tests.git ../selenium-api-tests
_51DEGREES_EXAMPLE_URL=http://localhost:8888/jsExample/index.html dotnet test ../selenium-api-tests --filter TestCategory=ModuleJavaScript
```
  - The tests need the .NET 10 SDK, Chrome and Firefox. A driver the machine provides is used, and Selenium Manager fetches one otherwise.
  - Stop NGINX.

## Re-certify 51Degrees module
When a new release is made to the 51Degrees module, module maintainer will need to re-certify it the NGINX Plus for target releases.

To re-certify, follow the "Partner Build, Functional Testing, and Self Certification Process" in the documentation [here](https://web.archive.org/web/20240214223113/https://www.nginx.com/partners/certified-module-program-documentation/) then submit your results to NGINX to be reviewed by their engineering team.

Make sure to use the latest versions of [NGINX OSS & Plus](https://docs.nginx.com/nginx/releases/) for re-certification.

A NGINX Plus dev license might be required for testing.

## History

This repository was renamed from `device-detection-nginx` and continues that work. The old address redirects here, and the repository retains its history, stars, and issues.

## Find out more

- [Device Detection](https://51degrees.com/device-detection?utm_source=github&utm_medium=readme&utm_campaign=51degrees-nginx&utm_content=readme.md&utm_term=find-out-more)
- [IP Intelligence](https://51degrees.com/ip-intelligence?utm_source=github&utm_medium=readme&utm_campaign=51degrees-nginx&utm_content=readme.md&utm_term=find-out-more)
- [Documentation](https://51degrees.com/documentation/index.html?utm_source=github&utm_medium=readme&utm_campaign=51degrees-nginx&utm_content=readme.md&utm_term=find-out-more)
- https://github.com/51Degrees/51degrees-cxx
