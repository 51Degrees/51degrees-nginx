FROM debian:12-slim
WORKDIR /app

#build dependencies
RUN apt-get update && apt-get install --no-install-recommends -y git curl ca-certificates build-essential libpcre3-dev libz-dev nano && rm -rf /var/lib/apt/lists/*

#what to build, the head of main unless --build-arg names another
#_51DEGREES_BRANCH or one _51DEGREES_COMMIT, fetched from
#_51DEGREES_REPOSITORY, and an NGINX version CI tests
ARG _51DEGREES_REPOSITORY=https://github.com/51Degrees/51degrees-nginx
ARG _51DEGREES_BRANCH=main
ARG _51DEGREES_COMMIT=
ARG _51DEGREES_NGINX_VERSION=1.29.3

#cloning the repo
RUN git init -q . && git remote add origin "${_51DEGREES_REPOSITORY}" \
	&& git fetch -q origin "${_51DEGREES_COMMIT:-$_51DEGREES_BRANCH}" && git checkout -q FETCH_HEAD \
	&& git submodule update --init --recursive

#the free Lite data file, downloaded by the data repository's script, which
#keeps a file that is already there. A copy of 51Degrees-LiteV4.1.hash put
#beside this Dockerfile is used in place of the download. It is read through
#a mount, so the image holds the file once.
RUN --mount=type=bind,target=/tmp/context \
	if [ -f /tmp/context/51Degrees-LiteV4.1.hash ]; then \
		cp /tmp/context/51Degrees-LiteV4.1.hash cxx/data/device-detection/; fi \
	&& sh cxx/data/get-data-files.sh -s examples-51degrees-nginx 51Degrees-LiteV4.1.hash

#make reads the NGINX version from _51DEGREES_NGINX_VERSION
RUN make install

COPY nginx.conf /app/build/nginx.conf

EXPOSE 8080

CMD ["/app/nginx", "-c", "/app/build/nginx.conf"]
