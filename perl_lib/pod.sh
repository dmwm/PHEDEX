#!/bin/bash

dest=$1
if [ -z "$dest" ]; then
  echo "Destination directory is required."
  exit 1
fi

for dir in `find . -type d -print | grep -v CVS`; do
  echo -n "Check existence of $dest/$dir: "
  if [ -d "$dest/$dir" ]; then
    echo "OK"
  else
    echo "creating..."
    mkdir -p $dest/$dir || exit 1
  fi
done

htmlroot=$dest
for f in `find . -type f -name '*.pm'`; do
  echo "Podding $f..."
  g=`echo $f | sed -e 's%pm$%html%'`
  pod2html --infile $f --outfile $dest/$g --header --htmlroot $htmlroot
done

echo "Finished..."
