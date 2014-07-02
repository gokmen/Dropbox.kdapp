#!/bin/bash
DROPBOX="/home/$1/Dropbox"
HELPER="python /home/$1/.dropbox-app/dropbox.py"
EXCLUDE_FILES=""
OLD_IFS=$IFS

mkdir -p $DROPBOX;
mkdir -p $DROPBOX/Koding;

if [ -z `$HELPER running`] then

  IFS=$'\n'
  for file in `ls -1 $DROPBOX | grep -v Koding`; do
    # Dropbox python script cant read paths with spaces in
    # it becuase of how it parses arguments from cli.
    # This replaces spaces with ||. Then the python
    # script goes back and converts it back to a space.
    EXCLUDE_FILES+="$DROPBOX/${file// /||} ";
  done
  IFS=$OLD_IFS;
  
  echo "$HELPER exclude add $EXCLUDE_FILES";
  $HELPER exclude add $EXCLUDE_FILES;

fi