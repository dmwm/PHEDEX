<?
error_reporting(E_ALL);
ini_set("max_execution_time", "120");
ini_set("memory_limit", "96M");
DEFINE ('TTF_DIR', "/afs/cern.ch/cms/sw/slc3_ia32_gcc323/lcg/root/5.12.00/root/fonts/");

// Hack to fill in PHP 5 function...
function stream_get_line ($fh, $len) { return trim(fgets($fh, $len)); }

// Interpret and rearrange quality history data.
function selectQualityData($filename)
{
  // Open the CSV file for reading, then read all the rows in it.
  $fh = fopen($filename, "r");
  $labels = explode(",", stream_get_line($fh, 100000));
  if (count($labels) != 4) return array();

  // Build a list of bins.  Include rows that match our key selection.
  // Produce one row per time bin, under which there is an associative
  // array per line item key.
  $bins = array();
  while (! feof($fh))
  {
    // Read this line item.
    $data = explode(",", stream_get_line($fh, 100000));
    if (count($data) != 4) break;

    // If this is different from the previous time stamp, add a new row.
    $time = $data[0];
    $span = $data[1];
    $dest = $data[2];
    $values = explode("/", $data[3]);
    if (preg_match("/MSS$/", $dest)) continue;

    if (! count($bins) || $bins[count($bins)-1][0] != $time)
      // Start building new bin
      $bins[] = array($time, $span, array());

    $bins[count($bins)-1][2][$dest] = $values;
  }

  // We are done
  fclose($fh);
  return $bins;
}

// Interpret and rearrange performance history data.
function selectPerformanceData($filename)
{
  // Open the CSV file for reading, then read all the rows in it.
  $fh = fopen($filename, "r");
  $labels = explode(",", stream_get_line($fh, 100000));
  if (count($labels) != 4) return array();

  // Build a list of bins.  All rows are interesting, include only columns
  // of interest.  Compact so that each time bin has exactly one row, then
  // has underneath it rows for each line item.
  $bins = array();
  while (! feof($fh))
  {
    // Read this line item.
    $data = explode(",", stream_get_line($fh, 100000));
    if (count($data) != 4) break;

    // If this is different from the previous time stamp, add a new row.
    $time = $data[0];
    $span = $data[1];
    $dest = $data[2];
    $value = $data[3];

    if (! count($bins) || $bins[count($bins)-1][0] != $time)
      // Start building new bin
      $bins[] = array($time, $span, array());

    $bins[count($bins)-1][2][$dest] = $value;
  }

  // We are done
  fclose($fh);
  return $bins;
}

// Convert HSV colour values to RGB.
function hsv2rgb($h, $s, $v)
{
  if ($s == 0)
    return array($v, $v, $v);
  else
  {
    if ($h == 1.) $h = 0.;
    $h *= 6.;
    $i = (int) $h;
    $f = $h - $i;
    $p = $v * (1. - $s);
    $q = $v * (1. - $s * $f);
    $t = $v * (1. - $s * (1. - $f));
    switch ($i)
    {
      case 0: return array($v, $t, $p);
      case 1: return array($q, $v, $p);
      case 2: return array($p, $v, $t);
      case 3: return array($p, $q, $v);
      case 4: return array($t, $p, $q);
      case 5: return array($v, $p, $q);
    }
  }
}

// The first half of a "hsv" colour map, from IGUANA IgSbColorMap.cc.
// However, we darken the edge (red, green) colours to give more
// variety to the colours.  We do this by giving value coordinate
// a value using a half circle in range [0, 1] with base line of
// the circle half at v=0.5: $value=0 and $value=1 result in v=0.5,
// and $value=0.5 results in $v=1, so the midtones (yellows) are
// brighter whereas edges (red, green) are darker.
//
// We also constrain $value; <0 means no colour (= white), otherwise
// $value is clamped to [0, 1], then scaled to [$base, $base+$range]
// to use a suitable portion of the HSV gradient range (red-green).
//
// FIXME: Constrain to max ten distinct colours?
function styleByValue($base, $range, $saturation, $srange, $value, $modrange)
{
  $value = min($value, 1); // ((int) (max ($value, 1) * 10)) / 10.;
  if ($value < 0.) {
    $rgb = array (1, 1, 1);
  } else {
    $huev = $base + $range*$value;
    $satv = $saturation - $srange + $srange * (1 + sin($value*25))/2;
    $modv = fmod ($value, $modrange);
    $rgb = hsv2rgb ($huev, $satv, 0.5 + sqrt($modv*(1-$modv)));
  }
  return sprintf ("#%02x%02x%02x", $rgb[0]*255, $rgb[1]*255, $rgb[2]*255);
}

?>
