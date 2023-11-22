#!/bin/bash

rm -rf public/
docker build -t ex_static_image .
container_id=$(docker run -it -d -p 3000:4000 ex_static_image)
wget -r -k -E -P public/ --no-host-directories http://localhost:3000/
docker stop $container_id