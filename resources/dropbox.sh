#!/bin/bash
DROPBOX="/home/$1/Dropbox"
HELPER="python /home/$1/.dropbox-app/dropbox.py"
EXCLUDE_FILES=""

mkdir -p $DROPBOX;
mkdir -p $DROPBOX/Koding;

for file in $(ls -b $DROPBOX | grep -v Koding); do
  EXCLUDE_FILES+="$DROPBOX/$file ";
done

$HELPER exclude add $EXCLUDE_FILES;