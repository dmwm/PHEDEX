#!/bin/bash
# Script to compress (minify) the phedex js files
cd `dirname $0`
cd ../..
phedex_base=`pwd`
echo "Using $phedex_base for setup..."

phedex_js_path=$phedex_base/ApplicationServer/js
phedex_css_path=$phedex_base/ApplicationServer/css
phedex_min_js_path=$phedex_base/ApplicationServer/build/js
phedex_min_css_path=$phedex_base/ApplicationServer/build/css

yuicompressor_version='2.4.7'
yuicompressor_url=http://yui.zenfs.com/releases/yuicompressor/yuicompressor-${yuicompressor_version}.zip
yuicompressor_path=$YUICOMPRESSOR_PATH
if [ "$yuicompressor_path" == '' ]; then
  yuicompressor_path=$phedex_base/yuicompressor-${yuicompressor_version}/build/yuicompressor-${yuicompressor_version}.jar
fi

echo "========================================================"
# Check if the YUI compressor file exist or not
if [ ! -f $yuicompressor_path ]; then
  echo "YUI compressor jar file is missing, attempting to download it"
  wget -q $yuicompressor_url
  unzip -q `basename $yuicompressor_url`
  if [ ! -f $yuicompressor_path ]; then
    echo "YUI compressor jar file is still missing, giving up..."
    echo "(looked for $yuicompressor_path )"
    exit 1
  fi
fi

# Check if the raw js files directory exist or not
if [ ! -d $phedex_js_path ]; then
  echo "Phedex raw js files directory is missing"
  exit 1
fi

# Check if the raw css files directory exist or not
if [ ! -d $phedex_css_path ]; then
  echo "Phedex raw css files directory is missing"
  exit 1
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

# Prepare the rollup-file for the base and loader
cd $phedex_js_path
cat phedex-base.js phedex-loader.js | tee phedex-base-loader.js >/dev/null

echo "Command is:"
echo java -jar $yuicompressor_path input_file -o output_file
cd $phedex_js_path
for file in `dir -d *.js` ; do
echo -n "Converting $file "
if [ -f $phedex_min_js_path/${file/.js/-min.js} ]; then
  echo '...already there'
else
  echo ' '
  java -jar $yuicompressor_path $file -o $phedex_min_js_path/${file/.js/-min.js}
  status=$?
  if [ $status -ne 0 ]; then
    echo "compress $file: status $status"
    exit $status
  fi
fi
cp $file $phedex_min_js_path/$file # for the debug-version
done

echo "Phedex min js files are in $phedex_min_js_path directory"
echo "========================================================"

cd $phedex_css_path
for file in `dir -d *.css` ; do
echo -n "Converting $file "
if [ -f $phedex_min_css_path/${file/.css/-min.css} ]; then
  echo '...already there'
else
  echo ' '
  java -jar $yuicompressor_path $file -o $phedex_min_css_path/${file/.css/-min.css}
  status=$?
  if [ $status -ne 0 ]; then
    echo "compress $file: status $status"
    exit $status
  fi
fi
cp $file $phedex_min_css_path/$file # for the debug-version
done

echo "Phedex min css files are in $phedex_min_css_path directory"
echo "========================================================"
exit 0
