#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR"/env.txt "$1" "$2" "$3"

MP=$(($PORT + 1))
CID=$(docker run -d --rm -p $MP:27017  mongo:3.2)

sleep 30

"$JAVA_HOME_8"/bin/java -Xms1G -Xmx4G "$AGENT" -Dliquibase.enabled=false -Ddg-toolkit.derby.port=0 -Dspring.data.mongodb.uri=mongodb://localhost:$MP/ocvn -jar "$EMB_DIR"/ocvn-rest-sut.jar  --server.port="$PORT" --spring.datasource.url="jdbc:h2:mem:testdb;DB_CLOSE_DELAY=-1;" --spring.datasource.driver-class-name=org.h2.Driver --spring.jpa.database-platform=org.hibernate.dialect.H2Dialect

docker stop $CID
