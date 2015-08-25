#!/bin/bash

################################################################################
#
# MODIFY the following lines to match your requirements
#
################################################################################

CERTIFICATE_DETAILS="/C=US/ST=Denial/L=Springfield/O=Dis/CN=example.com"
CERTIFICATE_DAYS=365

INITIAL_USER="testuser"
INITIAL_PASSWD="testpass"

######## INTERNAL ##############################################################

IMAGE_DATA="registry-data-image:latest"
CONTAINER_DATA="registry-data"
CONTAINER_REGISTRY="registry"

## build image if it doesn't exist
docker history $IMAGE_DATA > /dev/null 2>&1
if [ $? -ne 0 ]; then
  cd bootstrap
  docker build --rm -t $IMAGE_DATA .
  cd ..
  if [ $? -ne 0 ]; then
    echo "[FATAL] not able to build $IMAGE_DATA (this shouldn't happen)"
    exit 1
  fi
fi 

docker inspect $CONTAINER_DATA > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "[INFO] data container [${CONTAINER_DATA}] already exists."
else
  docker run -dti --name=$CONTAINER_DATA -v /var/lib/registry $IMAGE_DATA
  docker exec $CONTAINER_DATA gen-cert "$CERTIFICATE_DAYS" "$CERTIFICATE_DETAILS"
  docker exec $CONTAINER_DATA add-user "$INITIAL_USER" "$INITIAL_PASSWD"
  docker exec -ti $CONTAINER_DATA output-crt > ca.crt
  docker stop $CONTAINER_DATA
fi

docker inspect $CONTAINER_REGISTRY > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "[INFO] registry container [${CONTAINER_REGISTRY}] already exists. Nothing to do."
else

  docker run -d -p 5000:5000 --restart=always --name ${CONTAINER_REGISTRY} \
    --log-opt max-size=2m --log-opt max-file=5 \
    --volumes-from=${CONTAINER_DATA} \
    -e REGISTRY_AUTH=htpasswd \
    -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
    -e REGISTRY_AUTH_HTPASSWD_PATH=/var/lib/registry/auth/htpasswd \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/var/lib/registry/certs/domain.crt \
    -e REGISTRY_HTTP_TLS_KEY=/var/lib/registry/certs/domain.key \
    registry:2.1.1
fi



