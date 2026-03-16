#!/usr/bin/env bash
set -euo pipefail

BREW_PREFIX="/home/linuxbrew/.linuxbrew"
BREW_RUBY="$BREW_PREFIX/opt/ruby/bin/ruby"

if [ ! -x "$BREW_RUBY" ]; then
  echo "Ruby not found at $BREW_RUBY" >&2
  return 1 2>/dev/null || exit 1
fi

RUBY_API_VERSION="$("$BREW_RUBY" -e 'print RbConfig::CONFIG["ruby_version"]')"
RUBY_VERSION_DIR="$HOME/.local/share/gem/ruby/$RUBY_API_VERSION"
BREW_GEM_BIN_DIR="$BREW_PREFIX/lib/ruby/gems/$RUBY_API_VERSION/bin"

export PATH="$BREW_PREFIX/opt/ruby/bin:$BREW_PREFIX/opt/sqlite/bin:$RUBY_VERSION_DIR/bin:$BREW_GEM_BIN_DIR:$PATH"
export GEM_HOME="$RUBY_VERSION_DIR"
export GEM_PATH="$GEM_HOME"
export BUNDLE_PATH="vendor/bundle"
export BUNDLE_DISABLE_SHARED_GEMS="true"
export LDFLAGS="-L$BREW_PREFIX/opt/sqlite/lib -L$BREW_PREFIX/opt/openssl@3/lib"
export CPPFLAGS="-I$BREW_PREFIX/opt/sqlite/include -I$BREW_PREFIX/opt/openssl@3/include"
export PKG_CONFIG_PATH="$BREW_PREFIX/opt/sqlite/lib/pkgconfig:$BREW_PREFIX/opt/openssl@3/lib/pkgconfig"
