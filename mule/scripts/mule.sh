#!/bin/bash
# RHEL Mule Init Script
#
# chkconfig: 2345 65 64
# description: Mule ESB service

. /etc/init.d/functions
#
if [ -f /etc/sysconfig/mule ]; then
   . /etc/sysconfig/mule
fi

# Set JDK related environment
JAVA_HOME=/usr/java/default
PATH=$PATH:$JAVA_HOME/bin

# Set Mule related environment
MULE_HOME=/opt/mule
MULE_LIB=$MULE_HOME/lib
PATH=$PATH:$MULE_HOME/bin
RUN_AS_USER=mule
MULE_ENV=production

# Export environment variables
export JAVA_HOME MULE_HOME MULE_LIB PATH MULE_ENV RUN_AS_USER

case "$1" in
   start)
      echo "Start service mule"
      $MULE_HOME/bin/mule start -M-Dspring.profiles.active=$MULE_ENV -M-DMULE_ENV=$MULE_ENV
      ;;
   stop)
      echo "Stop service mule"
      $MULE_HOME/bin/mule stop
      ;;
   restart)
      echo "Restart service mule"
      $MULE_HOME/bin/mule restart -M-Dspring.profiles.active=$MULE_ENV -M-DMULE_ENV=$MULE_ENV
      ;;
   *)
      echo "Usage: $0 {start|stop|restart}"
      exit 1
      ;;
esac


