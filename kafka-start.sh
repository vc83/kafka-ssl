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

fail_by_rc docker build -t kafka .
fail_by_rc docker run -d --network host kafka

echo -e "--- waiting for docker container & certificate creation ---"
sleep 5
container_id=$(docker container ls  | grep "kafka" | awk '{print $1}')

echo "container id : $container_id"

echo "--- downloading ssl certificate to" $PWD"/kafkaCerts from container with id $container_id ---"

fail_by_rc rm -rf kafkaCerts
fail_by_rc mkdir -p kafkaCerts

fail_by_rc docker cp $container_id:/certs/client.crt.pem ${PWD}/kafkaCerts/client.crt.pem

fail_by_rc docker cp $container_id:/certs/client.key.pem ${PWD}/kafkaCerts/client.key.pem

fail_by_rc docker cp $container_id:/certs/rootCA.crt.pem ${PWD}/kafkaCerts/rootCA.crt.pem

fail_by_rc docker cp $container_id:/certs/server.crt.pem ${PWD}/kafkaCerts/server.crt.pem

echo -e "--- logging container logs ---"
docker logs --follow $container_id
