#!/usr/bin/env sh

set -o errexit
set -o nounset

cmd="$*"

env=${DJANGO_ENV-development}

postgres_ready () {
  # Check that postgres is up and running on port `5432`:
  dockerize -wait 'tcp://database:5432'
}

services_ready () {
  dockerize -wait 'tcp://database:5432' -wait 'tcp://rabbitmq:5672' -timeout 5s
}

if [ "$env" = 'test' ]; then
  until postgres_ready; do
    >&2 echo 'Postgres is unavailable - sleeping'
  done
  >&2 echo 'Postgres is up - continuing...'
else
  until services_ready; do
    >&2 echo 'Postgres or rabbitmq is unavailable - sleeping'
  done
  >&2 echo 'Postgres and rabbitmq is up - continuing...'
fi

# Evaluating passed command (do not touch):
# shellcheck disable=SC2086
exec $cmd
