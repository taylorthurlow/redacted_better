#!/bin/bash

set -e

if [ -n "$1" ]; then
  echo "Using torrent URL: $1"
  COMMAND="redactedbetter --torrent \"$1\""
else
  COMMAND="redactedbetter"
  fi


rm -f *.gem
gem build redacted_better.gemspec
scp redacted_better*.gem taylor@home.thurlow.io:~/temp/redacted_better.gem
ssh -t taylor@home.thurlow.io "cd ~/temp && \
                               ~/.rbenv/shims/gem uninstall -x redacted_better && \
                               ~/.rbenv/shims/gem install ./redacted_better.gem && \
                               echo '---------------------' && \
                               ~/.rbenv/shims/$COMMAND && \
                               echo '---------------------'"
