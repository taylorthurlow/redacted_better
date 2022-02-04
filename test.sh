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
scp redacted_better*.gem taylor@192.168.1.22:~/temp/redacted_better.gem
ssh -t taylor@192.168.1.22 "cd ~/temp && \
                            gem uninstall -x redacted_better && \
                            gem install ./redacted_better.gem && \
                            echo '---------------------' && \
                            $COMMAND && \
                            echo '---------------------'"
