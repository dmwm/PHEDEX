#!/bin/bash

# Example:
# ./pod.sh ~/www/PHEDEX/PHEDEX_CVS http://cern.ch/wildish/PHEDEX/PHEDEX_CVS

cd `dirname $0`
dest=$1
if [ -z "$dest" ]; then
  echo "Destination directory is required."
  exit 1
fi

htmlroot=$2
if [ -z "$htmlroot" ]; then
  echo "Destination htmlroot is required."
  exit 1
fi

css=$3
if [ -z "$css" ]; then
  css=http://cern.ch/wildish/PHEDEX/phedex_pod.css
  echo "Using default CSS file: $css"
  echo "Copy (and edit) that file if you want something different..."
fi

version=`cat ../VERSION`
ssss="$dest/$version"
index="$dest/index.html"
for dir in `find . -type d -print | grep -v CVS`; do
  echo -n "Check existence of $dest/$dir: "
  if [ -d "$dest/$dir" ]; then
    echo "OK"
  else
    echo "creating..."
    mkdir -p $dest/$dir || exit 1
  fi
done

echo "<html>
<head>PhEDEx module index for version $version</head>
<body>
  <ul>
" | tee $index >/dev/null

for f in `find . -type f -name '*.pm' | sort`; do
  echo "Podding $f..."
  g=`echo $f | sed -e 's%pm$%html%'`
  pm=`echo $f | sed -e 's%pm$%%' -e 's%^\./%%' -e 's%/%::%g'`
  pod2html --infile $f --outfile $dest/$g --header --htmlroot $htmlroot \
  	-css http://cern.ch/wildish/PHEDEX/phedex_pod.css
  echo "<li><a href='$g'>$pm</a></li>" >> $index
done

echo "</ul>
</body>
</html>" >> $index

echo "Finished..."
