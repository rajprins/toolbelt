#!/bin/bash
#
# Convert VIDEO_TS folder into ISO image.
# Roy Prins, 2012

SOURCE=$1
TARGET=./${SOURCE%/}.iso

#clear
echo
echo "================================================================================"
echo "VIDEO_TS to ISO Conversion Utility v. 0.1"
echo "================================================================================"
echo

### Check if VIDEO_TS folder is present
if [[ ! -d ${SOURCE}/VIDEO_TS ]] ; then
   echo "Directory $SOURCE does not seem to contain a VIDEO_TS folder. Cannot continue."
   exit 1
fi

### Check if target exists.
if [[ -f $TARGET ]] ; then
   echo -n "Warning: $TARGET already exists. Overwrite (Y/N)? "
   read ANSWER
   if [[ $ANSWER != Y && $ANSWER != y ]] ; then
      echo "Aborting…"
      exit 1
   fi
fi

### All good to go
echo "Converting VIDEO_TS folder $SOURCE to .ISO format ($TARGET)."
echo "Now would be a great time to grab a coffee. This will take a while."
echo
hdiutil makehybrid -o $TARGET ./$SOURCE  -udf
echo "Done."

