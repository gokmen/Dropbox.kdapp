#!/bin/bash
DROPBOX="/home/$1/Dropbox"
HELPER="python /home/$1/.dropbox-app/dropbox.py"
EXCLUDE_FILES=""
IFS=$'\n'

mkdir -p $DROPBOX;
mkdir -p $DROPBOX/Koding;

for file in $(ls $DROPBOX | grep -v Koding); do
  EXCLUDE_FILES+="'$DROPBOX/$file' "
done

$HELPER exclude add $EXCLUDE_FILES;