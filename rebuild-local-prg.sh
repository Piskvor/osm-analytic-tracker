#!/usr/bin/env bash

set -euxo pipefail

if [ "$1" = "--full" ]; then
	git reset HEAD --hard
	git checkout master
	git branch -D local-prg
	git checkout local-prg
	git fetch --all
	git pull
fi

sudo docker build \
	--build-arg CACHEBUSTER="$(date)" \
	--build-arg TIMEZONE="$(cat /etc/timezone)" \
	--build-arg REGIONS_URL_PREFIX="https://maps.piskvor.org/regions" \
	-t osm-analytic-tracker \
	.
docker stop osmat-container
docker rm osmat-container
docker run -d --restart=always --name=osmat-container -p 80:80 osm-analytic-tracker:latest
sleep 5
docker ps
