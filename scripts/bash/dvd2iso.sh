#!/bin/bash
#
# Converts phyisical (mounted) DVD into ISO image
# Roy Prins, 2010

echo "Converting currently mounted DVD into ISO image. Please wait..."
diskutil unmountDisk /dev/disk3
dd if=/dev/disk2s3 of=dvd.iso bs=2048
echo "Done."