#!/bin/sh
echo "args       : $*"
echo "APP_ENV    : $APP_ENV"
echo "APP_VERSION: $APP_VERSION"
echo "user       : $(id -u)"
echo "config     : $(cat /app/config.txt)"
echo "bundle     : $(ls /app/data)"
if [ "$1" = "serve" ]; then
  echo "serving... (Ctrl+C to stop)"
  while true; do sleep 5; done
fi
