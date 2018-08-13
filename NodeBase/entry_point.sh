#!/bin/bash

source /opt/bin/functions.sh
/opt/bin/generate_config > /opt/selenium/config.json

export GEOMETRY="$SCREEN_WIDTH""x""$SCREEN_HEIGHT""x""$SCREEN_DEPTH"

if [ ! -e /opt/selenium/config.json ]; then
  echo No Selenium Node configuration file, the node-base image is not intended to be run directly. 1>&2
  exit 1
fi

# In the long term the idea is to remove $HUB_PORT_4444_TCP_ADDR and $HUB_PORT_4444_TCP_PORT and only work with
# $HUB_HOST and $HUB_PORT
if [ ! -z "$HUB_HOST" ]; then
  HUB_PORT_PARAM=4444
  if [ ! -z "$HUB_PORT" ]; then
      HUB_PORT_PARAM=${HUB_PORT}
  fi
  echo "Connecting to the Hub using the host ${HUB_HOST} and port ${HUB_PORT_PARAM}"
  HUB_PORT_4444_TCP_ADDR=${HUB_HOST}
  HUB_PORT_4444_TCP_PORT=${HUB_PORT_PARAM}
fi

if [ -z "$HUB_PORT_4444_TCP_ADDR" ]; then
  echo "Not linked with a running Hub container" 1>&2
  exit 1
fi

function shutdown {
  kill -s SIGTERM $NODE_PID
  wait $NODE_PID
}

REMOTE_HOST_PARAM=""
if [ ! -z "$REMOTE_HOST" ]; then
  echo "REMOTE_HOST variable is set, appending -remoteHost"
  REMOTE_HOST_PARAM="-remoteHost $REMOTE_HOST"
fi

if [ ! -z "$SE_OPTS" ]; then
  echo "appending selenium options: ${SE_OPTS}"
fi

SERVERNUM=$(get_server_num)

echo "DISPLAY PORT $SERVERNUM"
rm -f /tmp/.X*lock

xvfb-run --listen-tcp -n $SERVERNUM --server-args="-screen 0 $GEOMETRY -ac +extension RANDR" \
  java ${JAVA_OPTS} -jar /opt/selenium/selenium-server-standalone.jar \
    -role node \
    -hub http://$HUB_PORT_4444_TCP_ADDR:$HUB_PORT_4444_TCP_PORT/grid/register \
    ${REMOTE_HOST_PARAM} \
    -nodeConfig /opt/selenium/config.json \
    ${SE_OPTS} &
NODE_PID=$!

echo "Waiting and launching ffmpeg"
sleep 10
ffmpeg -f x11grab -video_size 1920x1080 -i :99.0 -codec:v libx264 -r 12 /tmp/record.mp4 &

trap shutdown SIGTERM SIGINT
wait $NODE_PID
