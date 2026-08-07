#!/bin/sh
set -eu

wine_prefix="${WINEPREFIX:-/home/user/.wine}"
if [ -d "$wine_prefix" ]; then
    chown -R user:group "$wine_prefix"
fi

exec /bin/su -s /bin/sh user -c 'exec /bin/dumb-init "$@"' /bin/sh "$@"
