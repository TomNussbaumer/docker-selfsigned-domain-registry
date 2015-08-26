#!/bin/bash

# sets up a self-signed domain registry automatically
#
# The MIT License (MIT)
#
# Copyright (c) 2015 Tom Nussbaumer <thomas.nussbaumer@gmx.net>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

cd "$(readlink -f "$(dirname "$BASH_SOURCE")")"
. ./settings

## build image if it doesn't exist
docker history $IMAGE_DATA > /dev/null 2>&1
if [ $? -ne 0 ]; then
  cd data-image
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
