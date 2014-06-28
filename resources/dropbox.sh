DROPBOX = "/home/$1/Dropbox"
HELPER = "/tmp/_dropbox.py"

if [ ! -d "$DROPBOX" ]; then
  mkdir $DROPBOX;
fi

if [ ! -d "$DROPBOX/Koding" ]; then
  mkdir $DROPBOX/Koding;
fi

ls $DROPBOX/* | grep -v Koding | xargs python $HELPER exclude add;
python $HELPER exclude remove $DROPBOX/Koding;