#!/bin/sh

cd "$(readlink -f "$(dirname "$BASH_SOURCE")")"
. ./settings

read -p "[WARNING] you will LOOSE ALL CONTENT of your registry. Really proceed [y/n]? " ANSWER

if [ "$ANSWER" = "y" ]; then
  docker stop              "$CONTAINER_REGISTRY"
  # TODO: in our case --volumes=true should not be necessary on the registry, but IT IS with
  # docker v1.8.1. Maybe a bug?
  docker rm --volumes=true "$CONTAINER_REGISTRY"
  docker stop              "$CONTAINER_DATA"
  docker rm --volumes=true "$CONTAINER_DATA"
  #just destroy image during development
  #docker rmi   "$IMAGE_DATA"
else
  echo "[INFO] You are a really wise man, Sir! Skipping armageddon."
fi
