#!/usr/bin/env bash

set -euxo pipefail

HERE=$(dirname $(realpath $0))

FULL=0
NOCACHE=0
DOCKER_ARGS=""
CACHE_BUSTER=""
#CACHE_BUSTER="$(date)"
DOCKER_VOLUMES=""
DOCKER_VOLUMES="-v ${HERE}/mounts/osmtracker:/osmtracker"
#DOCKER_VOLUMES="-v ${HERE}/mounts/html:/html -v ${HERE}/mounts/osmtracker:/osmtracker"

if [ "${1:-}" = "--full" ]; then
	FULL=1
	shift
fi

if [ "${1:-}" = "--no-cache" ]; then
	NOCACHE=1
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

if [ "$FULL" -gt 0 ]; then
	git reset HEAD --hard
	git checkout master
	git branch -D local-prg
	git checkout local-prg
	git fetch --all
	git pull
fi

if [ "$NOCACHE" -gt 0 ]; then
	DOCKER_ARGS="${DOCKER_ARGS} --no-cache"
fi

sudo docker build ${DOCKER_ARGS} \
	--build-arg CACHEBUSTER="$CACHE_BUSTER" \
	--build-arg TIMEZONE="$(cat /etc/timezone)" \
	--build-arg REGIONS_URL_PREFIX="https://maps.piskvor.org/regions" \
	-t osm-analytic-tracker \
	.

docker stop osmat-container && docker rm osmat-container || true

if [ "$DOCKER_VOLUMES" != "" ]; then
	mkdir -p ${HERE}/mounts/html/dynamic
	cp -r ${HERE}/html ${HERE}/mounts/
	cp  ${HERE}/html/starting.html ${HERE}/mounts/html/index.html
	mkdir -p ${HERE}/mounts/osmtracker/osm-analytic-tracker
	cp ${HERE}/*.py ${HERE}/logging.conf ${HERE}/mounts/osmtracker/osm-analytic-tracker
	cp -r ${HERE}/osm ${HERE}/mounts/osmtracker/osm-analytic-tracker/
#	cp -r ${HERE}/templates ${HERE}/mounts/osmtracker/
	cp -r ${HERE}/templates ${HERE}/mounts/osmtracker/osm-analytic-tracker/
	cp ${HERE}/docker/supervisord.conf ${HERE}/mounts/osmtracker/
#	exit;
fi

docker run -d --restart=always --name=osmat-container -p 80:80 ${DOCKER_VOLUMES} osm-analytic-tracker:latest
sleep 5
docker ps
