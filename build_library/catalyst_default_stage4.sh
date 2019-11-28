#!/bin/bash

source /tmp/chroot-functions.sh

export clst_myemergeopts="$( echo "$clst_myemergeopts" | sed -e 's/--newuse//' )"

echo "Double checking everything is fresh and happy."
run_merge -uDN --with-bdeps=y world

echo "Setting the default Python interpreter to Python 2."
eselect python set python2.7
