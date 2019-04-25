#!/bin/bash

REDIS_IMAGE=redis:5.0.1-alpine
REDIS_CONTAINER=redis_cloud
REDIS_DATA_DIR=/home/lee/deploy/redis/data
REDIS_CONFIG_FILE=/home/lee/deploy/redis/config/redis.conf

# 查找redis镜像是否存在，不存在则拉取
existImage=false
# `docker images | awk { 
#     if [ $1":"$2 -eq ${REDIS_IMAGE} ]; then 
#         existImage=true
#         echo "this image already exist ..."
#     fi }`
if [ !existImage ]; then
    echo "pull redis alpine image ..."
    # docker pull ${REDIS_IMAGE}
fi
sleep 1

echo "create and run redis container ..."
# docker run \
#   --name ${REDIS_CONTAINER} \
#   -p 6379:6379 \
#   -v ${REDIS_DATA_DIR}:/data \
#   -v ${REDIS_CONFIG_FILE}:/usr/local/etc/redis/redis.conf \
#   -d ${REDIS_IMAGE} redis-server /usr/local/etc/redis/redis.conf --appendonly yes
docker-compose up -d
sleep 1

echo "redis container info: "
# docker inspect ${REDIS_CONTAINER}
docker inspect redis_01m redis_01s redis_02m redis_02s redis_03m redis_03s | grep "IPAddress" | grep 172
# docker logs ${REDIS_CONTAINER}
sleep 1