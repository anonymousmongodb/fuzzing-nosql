#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR"/env.txt "$1" "$2" "$3"

MP=$(($PORT + 1))
CID=$(docker run -d --rm -p $MP:27017  mongo:6.0)

sleep 30

"$JAVA_HOME_8"/bin/java -Xms1G -Xmx4G "$AGENT" -Dspring.data.mongodb.uri=mongodb://localhost:$MP/session -jar "$EMB_DIR"/session-service-sut.jar  --server.port="$PORT" --spring.cache.type=NONE

docker stop $CID
