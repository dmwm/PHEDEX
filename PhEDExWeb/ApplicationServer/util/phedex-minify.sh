#!/bin/bash
# Script to compress (minify) the phedex js files
yuicompressor_path=/home/tony/YUI/yuicompressor-2.4.2/build/yuicompressor-2.4.2.jar
cd `dirname $0`
cd ../..
phedex_base=`pwd`
echo "Using $phedex_base for setup..."
phedex_js_path=$phedex_base/ApplicationServer/js
phedex_css_path=$phedex_base/ApplicationServer/css
phedex_min_js_path=$phedex_base/ApplicationServer/min/js
phedex_min_css_path=$phedex_base/ApplicationServer/min/css

echo "========================================================"
# Check if the YUI compressor file exist or not
if [ ! -f $yuicompressor_path ]; then
  echo "YUI compressor jar file is missing"
  exit 0
fi

# Check if the raw js files directory exist or not
if [ ! -d $phedex_js_path ]; then
  echo "Phedex raw js files directory is missing"
  exit 0
fi

# Check if the raw css files directory exist or not
if [ ! -d $phedex_css_path ]; then
  echo "Phedex raw css files directory is missing"
  exit 0
fi

# Check if the min js files directory exist or not
if [ ! -d $phedex_min_js_path ]; then
    mkdir -p $phedex_min_js_path
    if [ ! -d $phedex_min_js_path ]; then
      echo "Cannot create $phedex_min_js_path, quitting"
      exit 1
    fi
    echo "Phedex min js files directory is created as it was missing!"
fi

# Check if the min css files directory exist or not
if [ ! -d $phedex_min_css_path ]; then
    mkdir $phedex_min_css_path
    if [ ! -d $phedex_min_css_path ]; then
      echo "Cannot create $phedex_min_css_path, quitting"
      exit 1
    fi
    echo "Phedex min css files directory is created as it was missing!"
fi

which java >/dev/null 2>&1
if [ $? -gt 0 ]; then
    echo "Cannot find a 'java' executable"
    exit 1
fi

cd $phedex_js_path
for file in `dir -d *.js` ; do
echo "Converting $file"
java -jar $yuicompressor_path $file -o $phedex_min_js_path/${file/.js/-min.js}
done

echo "Phedex min js files are in $phedex_min_js_path directory"
echo "========================================================"

cd $phedex_css_path
for file in `dir -d *.css` ; do
echo "Converting $file"
java -jar $yuicompressor_path $file -o $phedex_min_css_path/${file/.css/-min.css}
done

echo "Phedex min css files are in $phedex_min_css_path directory"
echo "========================================================"
exit 0
