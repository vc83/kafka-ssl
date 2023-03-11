#!/usr/bin/env bash

function exit_with_error {
    printf '\n%s\n' "$1" >&2 ## Send message to stderr.
    exit "${2-1}" ## Return a code specified by $2, or 1 by default.
}

function fail_by_rc {
  echo -e "Executing '$*'\n"
  "$@"
  rc=$?
  if [ ${rc} -ne 0 ]; then
      exit_with_error "Failed to execute cmd " $rc
  fi
}


# echo "home dir : " ${HOME}
# ls -a 

fail_by_rc ./createCerts.sh
fail_by_rc /kafka/bin/zookeeper-server-start.sh -daemon /kafka/config/zookeeper.properties
sleep 1
fail_by_rc /kafka/bin/kafka-server-start.sh -daemon  /kafka/config/server.properties 
sleep 1
fail_by_rc /kafka/bin/kafka-topics.sh --create --topic test --partitions 1 --replication-factor 1 --bootstrap-server localhost:9092 --command-config /kafka/config/kafka-client.properties 

fail_by_rc tail -f /kafka/logs/server.log