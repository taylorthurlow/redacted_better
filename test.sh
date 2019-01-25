#!/bin/sh

set -e

rm -f *.gem
gem build redacted_better.gemspec
scp redacted_better*.gem taylor@home.thurlow.io:~/temp/redacted_better.gem
ssh -t taylor@home.thurlow.io "cd ~/temp && \
                               ~/.rbenv/shims/gem uninstall -x redacted_better && \
                               ~/.rbenv/shims/gem install ./redacted_better.gem && \
                               echo '---------------------' && \
                               ~/.rbenv/shims/redactedbetter && \
                               echo '---------------------'"
