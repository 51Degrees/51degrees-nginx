FROM debian:12-slim
WORKDIR /app

#build dependencies
RUN apt-get update && apt-get install --no-install-recommends -y git curl ca-certificates build-essential libpcre3-dev libz-dev nano && rm -rf /var/lib/apt/lists/*

#what to build, the head of main unless --build-arg names another BRANCH or
#one COMMIT, fetched from REPOSITORY, and an NGINX version CI tests
ARG REPOSITORY=https://github.com/51Degrees/51degrees-nginx
ARG BRANCH=main
ARG COMMIT=
ARG NGINX_VERSION=1.29.3

#cloning the repo
RUN git init -q . && git remote add origin "${REPOSITORY}" \
	&& git fetch -q origin "${COMMIT:-$BRANCH}" && git checkout -q FETCH_HEAD \
	&& git submodule update --init --recursive

#the free Lite data file, downloaded by the data repository's script
RUN sh cxx/data/get-data-files.sh -s examples-51degrees-nginx 51Degrees-LiteV4.1.hash

RUN make install FIFTYONEDEGREES_NGINX_VERSION=${NGINX_VERSION}

COPY nginx.conf /app/build/nginx.conf

EXPOSE 8080

CMD ["/app/nginx", "-c", "/app/build/nginx.conf"]
