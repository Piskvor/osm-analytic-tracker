#!/usr/bin/env bash

set -euxo pipefail

HERE=$(dirname $(realpath $0))

FULL=0
NOCACHE=0
DOCKER_ARGS=""
CACHE_BUSTER=""
#CACHE_BUSTER="$(date)"
DOCKER_VOLUMES=""


if [ "${1:-}" = "--no-cache" ]; then
	NOCACHE=1
	CACHE_BUSTER="$(date)"
	shift
	if [ "${1:-}" = "--full" ]; then
		FULL=1
		shift
	fi
else
	if [ "${1:-}" = "--cache" ] ; then
		CACHE_BUSTER=""
	fi
fi

sudo docker build -t osmat-mongo --build-arg CACHEBUSTER="$CACHE_BUSTER" --build-arg TIMEZONE="$(cat /etc/timezone)" -f docker/Dockerfile-mongo-from-base .

docker stop osmat-container-mongo && docker rm osmat-container-mongo  || true

docker run -d --restart=always --name=osmat-container-mongo -p 27017:27017 -p 28017:28017 ${DOCKER_VOLUMES} osmat-mongo:latest
sleep 2
docker ps
