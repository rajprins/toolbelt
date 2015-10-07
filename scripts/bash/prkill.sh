#!/bin/bash
echo
echo "Listing processes matching '$1' :"
for PS in $(ps -ef | grep -i $1 | grep -v 'grep' | grep -v 'bash' | awk '{print $8}') ; do
   echo "- $PS"
done
echo
sudo kill `ps -ef | grep -i $1 | grep -v 'bash' | awk '{print $2}'` 1> /dev/null 2> /dev/null
echo "Killed matching processes."
echo
