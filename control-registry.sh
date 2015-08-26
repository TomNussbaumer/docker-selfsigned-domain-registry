#!/bin/bash

# helperscript containing various utility methods related to the registry
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

showUsage () {
cat << END_OF_USAGE
USAGE: $1 command [command-options]
       utility methods for running the registry

commands:

  help                           ... print this page
  start                          ... starts registry
  stop                           ... stops registry
  pause                          ... pauses registry
  unpause                        ... unpauses registry
  restart                        ... restarts registry to pickup changes
  adduser <username> <password>  ... add a new authorized user
  deluser <username>             ... delete an authorized user
  outauth <filename>             ... outputs htpasswd file (use '-' for stdout)
  backup  <filename>             ... backup to tarfile (use '-' for stdout)
  restore <filename>             ... restore from tarfile (use '-' for stdin)
  outcrt  <filename>             ... outputs certificate (use '-' for stdout)
  setup-new-cert                 ... configures registry with new cert
                                     this will automatically generate a new 
                                     ca.cert file along this script
END_OF_USAGE
}

dataExistsOrExit () {
  docker inspect $CONTAINER_DATA >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "[ERROR] data container [$CONTAINER_DATA] doesn't exist"
    exit $1
  fi
}

registryExistsOrExit () {
  docker inspect $CONTAINER_REGISTRY >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "[ERROR] registry container [$CONTAINER_REGISTRY] doesn't exist"
    exit $1
  fi
}

checkParams () {
#  echo "$2 -t $3"
  if [ $2 -lt $3 ]; then
     echo "[ERROR] missing parameter"
     showUsage $1
     exit 1
  fi
}

startData () {
  docker unpause $CONTAINER_DATA >/dev/null 2>&1   ## just in case
  docker start   $CONTAINER_DATA >/dev/null 2>&1
}

stopData () {
  docker unpause $CONTAINER_DATA >/dev/null 2>&1  ## just in case
  docker stop    $CONTAINER_DATA >/dev/null 2>&1
}

pauseReg() {
  docker pause $CONTAINER_REGISTRY >/dev/null 2>&1
}

unpauseReg() {
  docker unpause $CONTAINER_REGISTRY >/dev/null 2>&1
}

startReg () {
  unpauseReg # just in case
  docker start $CONTAINER_REGISTRY >/dev/null 2>&1
}

stopReg () {
  unpauseReg # just in case
  docker stop $CONTAINER_REGISTRY >/dev/null 2>&1
}


checkParams $0 $# 1

case "$1" in
  "help")    showUsage $0;;

  "start")   registryExistsOrExit 2; docker start $CONTAINER_REGISTRY;;
  "stop")    registryExistsOrExit 2; docker stop $CONTAINER_REGISTRY;;
  "pause")   registryExistsOrExit 2; docker pause $CONTAINER_REGISTRY;;
  "unpause") registryExistsOrExit 2; docker unpause $CONTAINER_REGISTRY;;
  "restart") registryExistsOrExit 2; docker stop $CONTAINER_REGISTRY;docker start $CONTAINER_REGISTRY;;  

  "adduser") checkParams $0 $# 3; dataExistsOrExit 3
             startData
             docker exec $CONTAINER_DATA add-user "$2" "$3"
             stopData;;

  "deluser") checkParams $0 $# 2; dataExistsOrExit 3
             startData
             docker exec $CONTAINER_DATA del-user "$2"
             stopData;;

  "outauth") checkParams $0 $# 2; dataExistsOrExit 3
             startData
             if [ "$2" = "-" ]; then
               docker exec $CONTAINER_DATA output-auth
             else
               docker exec $CONTAINER_DATA output-auth > "$2"
             fi
             stopData;;

  "backup")  checkParams $0 $# 2; dataExistsOrExit 3
             startData
             pauseReg
             if [ "$2" = "-" ]; then
               docker exec $CONTAINER_DATA do-backup
             else
               docker exec $CONTAINER_DATA do-backup > "$2"
             fi
             unpauseReg
             stopData;;

  "restore") checkParams $0 $# 2; dataExistsOrExit 3
             startData
             pauseReg
             if [ "$2" = "-" ]; then
               $(docker exec -i $CONTAINER_DATA do-restore) <&1
             else
               cat "$2" | docker exec -i $CONTAINER_DATA do-restore
             fi
             unpauseReg
             stopData;;

  "outcrt")  checkParams $0 $# 2; dataExistsOrExit 3
             startData
             if [ "$2" = "-" ]; then
               docker exec $CONTAINER_DATA output-crt
             else
               docker exec $CONTAINER_DATA output-crt > "$2"
             fi
             stopData;;

  "setup-new-cert") dataExistsOrExit 3
             startData
             stopReg
             docker exec $CONTAINER_DATA gen-cert "$CERTIFICATE_DAYS" "$CERTIFICATE_DETAILS"
             docker exec $CONTAINER_DATA output-crt > ca.crt
             startReg
             stopData;; 

  *) echo "[ERROR] unknown command [$1]"; showUsage $0; exit 2;;
esac

