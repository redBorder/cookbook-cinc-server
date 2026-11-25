#!/bin/bash
# Run cinc-server-ctl with its embedded Ruby, isolated from the RVM environment
unset GEM_HOME GEM_PATH GEM_ROOT RUBYOPT RUBYLIB RUBY_VERSION MY_RUBY_HOME IRBRC
unset BUNDLE_GEMFILE BUNDLE_PATH BUNDLE_BIN_PATH
export PATH=/opt/cinc-project/embedded/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
exec /opt/cinc-project/bin/cinc-server-ctl "$@"
