#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR"/env.txt "$1" "$2" "$3"

MP=$(($PORT + 1))
CID=$(docker run -d --rm -p $MP:27017  mongo:4.4)

sleep 30

"$JAVA_HOME_11"/bin/java -Xms1G -Xmx4G "$AGENT" -Dspring.data.mongodb.uri=mongodb://localhost:$MP/reservations-api -jar "$EMB_DIR"/reservations-api-sut.jar  --server.port="$PORT" --databaseUrl=mongodb://localhost:$MP/reservations-api --app.jwt.secret=abcdef012345678901234567890123456789abcdef012345678901234567890123456789

docker stop $CID
