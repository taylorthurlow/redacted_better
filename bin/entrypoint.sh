#!/bin/bash

set -e

if [ -n "$1" ]; then
  echo "Using torrent URL: $1"
  COMMAND="redactedbetter --torrent \"$1\""
else
  COMMAND="redactedbetter"
fi

bundle exec $COMMAND
