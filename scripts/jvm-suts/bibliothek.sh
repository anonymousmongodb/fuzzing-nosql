#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR"/env.txt "$1" "$2" "$3"

MP=$(($PORT + 1))
CID=$(docker run -d --rm -p $MP:27017  mongo:6.0)

sleep 30

TMP_DIR=./tmp/bibliothek/p$PORT
mkdir -p $TMP_DIR

"$JAVA_HOME_17"/bin/java -Xms1G -Xmx4G "$AGENT" -Dspring.data.mongodb.uri=mongodb://localhost:$MP/library -jar "$EMB_DIR"/bibliothek-sut.jar  --server.port="$PORT" --databaseUrl=mongodb://localhost:$MP/library --app.storagePath=$TMP_DIR

docker stop $CID
