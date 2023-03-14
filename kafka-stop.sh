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
      echo "Failed to execute cmd " $rc
  fi
}

container_id=$(docker container ls -a | grep "kafka" | awk '{print $1}')

if [[ -z "${container_id}" ]]; then
  echo "No kafka running container found !!"
  exit 0
fi

fail_by_rc docker stop $container_id
fail_by_rc docker rm $container_id