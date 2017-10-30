#!/usr/bin/env bash

set -euxo pipefail

HERE=$(dirname $(realpath $0))

FULL=0
NOCACHE=0
DOCKER_ARGS=""
CACHE_BUSTER=""
CACHE_BUSTER="$(date)"
DOCKER_VOLUMES=""
#DOCKER_VOLUMES="-v ${HERE}/mounts/osmtracker:/osmtracker"
DOCKER_VOLUMES="-v ${HERE}/mounts/html:/html -v ${HERE}/mounts/osmtracker:/osmtracker"
MONGO_CONTAINER=""
MONGO_CONTAINER="osmat-container-mongo"
IS_MONGO_STANDALONE=0

if [ "${1:-}" = "--full" ]; then
	FULL=1
	shift
fi

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

DOCKER_LINK_TO=""
if [ "$MONGO_CONTAINER" != "" ] ; then
	IS_MONGO=$(docker ps --quiet --filter name="$MONGO_CONTAINER" | wc -l)
	if [ "$IS_MONGO" -gt 0 ]; then
		DOCKER_LINK_TO="--link $MONGO_CONTAINER"
		IS_MONGO_STANDALONE=1
	fi
fi

sudo docker build ${DOCKER_ARGS} \
	--build-arg CACHEBUSTER="$CACHE_BUSTER" \
	--build-arg TIMEZONE="$(cat /etc/timezone)" \
	--build-arg REGIONS_URL_PREFIX="https://maps.piskvor.org/regions" \
	--build-arg IS_MONGO_STANDALONE="$IS_MONGO_STANDALONE" \
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
	cp -r ${HERE}/templates ${HERE}/mounts/osmtracker/osm-analytic-tracker/
	cp ${HERE}/docker/supervisord.conf ${HERE}/mounts/osmtracker/
	if [ "$IS_MONGO_STANDALONE" = "0" ]; then \
		sed -i "s/autostart=false/autostart=true/" ${HERE}/mounts/osmtracker/supervisord.conf; \
		echo "mongo autostart" ;\
	else \
		sed -i "s/localhost:27017/osmat-container-mongo:27017/" ${HERE}/mounts/osmtracker/supervisord.conf; \
		echo "mongo container"; \
	fi

	mkdir -p ${HERE}/mounts/html/jquery-2.1.3
	cd ${HERE}/mounts/html/jquery-2.1.3
	wget --no-verbose --timestamping https://code.jquery.com/jquery-2.1.3.min.js && ln -sfT jquery-2.1.3.min.js jquery.min.js
	wget --no-verbose --timestamping http://timeago.yarp.com/jquery.timeago.js

	mkdir -p ${HERE}/mounts/html/leaflet-0.7.7
	cd ${HERE}/mounts/html/leaflet-0.7.7
	wget --no-verbose --timestamping http://cdn.leafletjs.com/leaflet/v0.7.7/leaflet.css
	wget --no-verbose --timestamping http://cdn.leafletjs.com/leaflet/v0.7.7/leaflet.js

fi

docker run -d ${DOCKER_LINK_TO} --restart=always --name=osmat-container -p 80:80 ${DOCKER_VOLUMES} osm-analytic-tracker:latest
sleep 5
docker ps
