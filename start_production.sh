#!/usr/bin/env bash
set -e
set -v

# Docker image is pinned here, so that you can checkout older
# versions of this script, and get reproducible deployments.
# DOCKER_VERSION is the version of 4dndcic/higlass-docker
DOCKER_VERSION=v0.1.0
IMAGE=4dndcic/higlass-docker:$DOCKER_VERSION
STAMP=`date +"%Y-%m-%d_%H-%M-%S"`
PORT=80
FLASK_PORT=8005

# NOTE: No parameters should change the behavior in a deep way:
# We want the tests to cover the same setup as in production.

usage() {
  echo "USAGE: $0 [-i IMAGE] [-s STAMP] [-p PORT] [-v VOLUME]" >&2
  exit 1
}

# check all AWS_BUCKET env variables - if not present we should bail.
check_var() {
  if [ -z "$1" ]; then
    echo "Did not find a required environment variable"
    exit 1
  fi
}
check_var "$AWS_BUCKET"
check_var "$AWS_BUCKET2"
check_var "$AWS_BUCKET3"
check_var "$AWS_BUCKET4"
check_var "$AWS_BUCKET5"

# stop all running containers
#sudo docker ps -a -q | xargs sudo docker stop

while getopts 'i:s:p:v:' OPT; do
  case $OPT in
    i)
      IMAGE=$OPTARG
      ;;
    s)
      STAMP=$OPTARG
      ;;
    p)
      PORT=$OPTARG
      ;;
    v)
      VOLUME=$OPTARG
      ;;
    *)
      usage
      ;;
  esac
done

if [ -z "$VOLUME" ]; then
    VOLUME=/tmp/higlass-docker/volume-$STAMP-with-redis
fi

# Clean up stopped containers - if not done could lead to conflicts when restarting container
docker system prune -f

docker network create --driver bridge network-$STAMP

# Create all directories we need. These will be mounted to data, so really
# /hg-data/media/$AWS_BUCKET is /data/media/$AWS_BUCKET, for example
for DIR in redis-data hg-data/log hg-tmp hg-data/media hg-data/media/$AWS_BUCKET hg-data/media/$AWS_BUCKET2 hg-data/media/$AWS_BUCKET3 hg-data/media/$AWS_BUCKET4 hg-data/media/$AWS_BUCKET5; do
  mkdir -p $VOLUME/$DIR || echo "$VOLUME/$DIR already exists"
done

REDIS_HOST=container-redis-$STAMP

# TODO: Should probably make a Dockerfile if configuration gets any more complicated.
SCRIPT_DIR=$( cd "$( dirname "$0" )" && pwd )
REDIS_CONF=/usr/local/etc/redis/redis.conf
docker run --name $REDIS_HOST \
           --network network-$STAMP \
           --volume $VOLUME/redis-data:/data \
           --volume $SCRIPT_DIR/redis-context/redis.conf:$REDIS_CONF \
           --detach redis:5.0.9-alpine \
           redis-server $REDIS_CONF

# Pass all env vars at runtime
docker run --name higlass-container \
           --network network-$STAMP \
           --publish $PORT:80 \
           --publish $FLASK_PORT:8005 \
           --volume $VOLUME/hg-data:/data \
           --volume $VOLUME/hg-tmp:/tmp \
           -e REDIS_HOST=$REDIS_HOST \
           -e REDIS_PORT=6379 \
           -e AWS_ACCESS_KEY_ID \
           -e AWS_SECRET_KEY \
           -e AWS_SECRET_ACCESS_KEY \
           -e AWS_BUCKET \
           -e AWS_BUCKET2 \
           -e AWS_BUCKET3 \
           -e AWS_BUCKET4 \
           -e AWS_BUCKET5 \
           --privileged \
           --detach \
           --publish-all \
           $IMAGE
