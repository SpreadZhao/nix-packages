#!/usr/bin/env bash

set -euo pipefail

export PATH="@runtimePath@${PATH:+:$PATH}"

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
config_dir="$config_home/gaomontablet"
cache_dir="$cache_home/gaomontablet"
state_dir="$state_home/gaomontablet"
runtime_dir="$cache_dir/@version@"
app_dir="@appDir@"

mkdir -p "$config_dir/res" "$cache_dir" "$state_dir" "$runtime_dir"
exec {lock_fd}>"$cache_dir/runtime.lock"
flock "$lock_fd"

if [[ ! -e "$config_dir/res/.seeded-@version@" ]]; then
  cp -a -n "$app_dir/res/." "$config_dir/res/"
  chmod -R u+rwX "$config_dir/res"
  touch "$config_dir/res/.seeded-@version@"
fi

if [[ ! -e "$state_dir/log.conf" ]]; then
  cp -a "$app_dir/log.conf" "$state_dir/log.conf"
  chmod u+rw "$state_dir/log.conf"
fi

install -m755 "$app_dir/gaomontablet" "$runtime_dir/gaomontablet"
install -m755 "$app_dir/huionCore" "$runtime_dir/huionCore"
for entry in \
  detectSessionProtocol \
  imageformats \
  libs \
  platforminputcontexts \
  platforms \
  qml \
  screenshot \
  xdotool; do
  ln -sfn "$app_dir/$entry" "$runtime_dir/$entry"
done
ln -sfn "$config_dir/res" "$runtime_dir/res"
ln -sfn "$state_dir/log.conf" "$runtime_dir/log.conf"

flock -u "$lock_fd"

export GAOMON_TABLET_RUNTIME_DIR="$runtime_dir"
export LD_LIBRARY_PATH="$runtime_dir/libs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QML2_IMPORT_PATH="$runtime_dir/qml${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
export QT_PLUGIN_PATH="$runtime_dir${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export QT_QPA_PLATFORM=xcb
export QT_QPA_PLATFORM_PLUGIN_PATH="$runtime_dir/platforms"

cd "$runtime_dir"
if [[ "$(basename "$0")" == "gaomon-tablet-core" ]]; then
  exec "$runtime_dir/huionCore" -d
fi

if ! pgrep -u "$(id -u)" -x huionCore >/dev/null; then
  "$runtime_dir/huionCore" -d &
  sleep 1
fi

exec "$runtime_dir/gaomontablet" "$@" -d
