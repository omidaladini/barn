#!/bin/bash

function close {                                                                   
  pkill -TERM -P $$                                                                
  wait                                                                             
  exit $?                                                                          
}

trap close SIGTERM SIGINT SIGHUP  

if [[ "$4" == "" ]]; then
  echo "Usage: $0 RSYNC_HOST:RSYNC_PORT RSYNC_SOURCE SERVICE_NAME CATEGORY";
  exit 0;
fi

BARN_RSYNC_ADDR=$1
INOTIFY_EXCLUSIONS="--exclude '\.u' --exclude 'lock' --exclude 'current' --exclude '*~'"
RSYNC_EXCLUSIONS="--exclude=*.u --exclude=config --exclude=current --exclude=lock --exclude=*~"
RSYNC_FLAGS="-c --verbose"  # --verbose is important since we use it to issue rsync incrementally
RSYNC_SOURCE=$2

SERVICE_NAME=$3
CATEGORY=$4

#Monitor a subdirectory
function sleepit {
  uname=$(uname)
  RSYNC_SOURCE=$1
  echo "Nothing more to sync. Hibernating till a log file is rotated on $RSYNC_SOURCE"
  if [[ "$uname" == 'Linux' ]]; then
     exec inotifywait $INOTIFY_EXCLUSIONS --timeout 3600 -q -e close_write $RSYNC_SOURCE/
  elif [[ "$uname" == 'Darwin' ]]; then
     echo "I'm on OSX so I'm going to loop-sleep like a madman. Use Linux for inotify."
     sleep 10
  fi
}

# Take one argument and sync it to the target barn rsync server
function sync {
  RSYNC_SOURCE=$1
  HOST_NAME=$(hostname -f)

  echo "Checking for $SERVICE_NAME@$CATEGORY"

  RSYNC_INITIALS="$RSYNC_FLAGS $RSYNC_EXCLUSIONS"
  RSYNC_TARGET="rsync://$BARN_RSYNC_ADDR/barn_logs/$SERVICE_NAME@$CATEGORY@$HOST_NAME/"

  CANDIDATES=$(eval "rsync --dry-run $RSYNC_INITIALS $RSYNC_SOURCE/* $RSYNC_TARGET" | grep -v "created directory" | grep "@" | awk '{print $1}' | sort)

  for c in $CANDIDATES; do
    echo "Candidate on $RSYNC_SOURCE is $c"
    DUMMY=$(rsync $RSYNC_INITIALS $RSYNC_SOURCE/$c $RSYNC_TARGET)
  done

  if [[ $CANDIDATES == "" ]]; then
    return 1   #I didn't sync anything
  else
    return 0
  fi
}

# Main program is here                                                          
#
# Note that the code below is not equivalent to:
# 
#  while true; do
#    sync $RSYNC_SOURCE || sleepit $RSYNC_SOURCE
#  done
#
# The background invocation paired with "wait" is to
# make sure the signal handler would be called as
# soon as the signal is fired.
#
while true; do                                                                  
  sync $RSYNC_SOURCE &
  wait $!
  SYNCED=$?
  if [ SYNCED != 0 ]; then
    sleepit $RSYNC_SOURCE & 
    wait $!
  fi
done
