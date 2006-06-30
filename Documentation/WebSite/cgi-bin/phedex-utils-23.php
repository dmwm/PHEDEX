<?
error_reporting(E_ALL);
ini_set("max_execution_time", "120");
ini_set("memory_limit", "128M");
DEFINE ('TTF_DIR', BASE_PATH . "/fonts/");

// Hack to fill in PHP 5 function...
function stream_get_line ($fh, $len) { return trim(fgets($fh, $len)); }

// Interpret and rearrange quality history data.
function selectQualityData($filename, $xbin, $tail, $upto, $by)
{
  // Build a map of nodes we are interested in.
  $result = array();
  $last = null;

  // Open the CSV file for reading.  We keep reading from this file into
  // an array ($result), either a large one ($tail is unset), or circular
  // one ($tail is set, in which case it defines the size of the array).
  // If $upto is given, we stop reading once we have reached the $upto
  // label _and_ see the next label that is different.
  $fh = fopen($filename, "r");
  $labels = explode(",", stream_get_line($fh, 100000));

  // Collect all the data into correct binning.  We read from start, filling
  // a circular buffer, or until we see a label following $upto (in which
  // case our circular buffer already contains what we need!).
  while (! feof($fh))
  {
    // Read this line item.
    $data = explode(",", stream_get_line($fh, 100000));

    // Select correct time for X axis, plus convert to desired format.
    // Stop when we have $tail unique X values.
    $time = $data[$xbin];
    if (! $last || $last != $time)
    {
      if (isset ($upto) && $upto != '' && $last && $last == $upto)
	break;

      $result[$time] = array();
      $last = $time;

      if (isset($tail) && $tail && count($result) > $tail)
	array_shift($result);
    }

    // Append to $result[$time][$node]
    $dest = $data[4];
    for ($n = 5; $n < count($data); ++$n)
    {
      $node = $labels[$n];
      //if (preg_match("/MSS$/", $node)) continue;
      $key = ($by == 'link' ? "{$dest} < {$node}" :
              ($by == 'dest' ? $dest : $node));
      if (! isset ($result[$time][$key]))
        $result[$time][$key] = array (0, 0, 0);

      $values = explode ("/", $data[$n]);
      $result[$time][$key][0] += $values[0];
      $result[$time][$key][1] += $values[1];
      $result[$time][$key][2] += $values[2];
    }
  }

  fclose($fh);
  return $result;
}

// Interpret and rearrange performance history data.
function selectPerformanceData($filename, $xbin, $tail, $sum, $upto, $by)
{
  // Build a map of nodes we are interested in.
  $result = array();
  $last = null;

  // Open the CSV file for reading.  We keep reading from this file into
  // an array ($result), either a large one ($tail is unset), or circular
  // one ($tail is set, in which case it defines the size of the array).
  // If $upto is given, we stop reading once we have reached the $upto
  // label _and_ see the next label that is different.
  $fh = fopen($filename, "r");
  $labels = explode(",", stream_get_line($fh, 100000));

  // Collect all the data into correct binning.  We read from start, filling
  // a circular buffer, or until we see a label following $upto (in which
  // case our circular buffer already contains what we need!).
  while (! feof($fh))
  {
    // Read this line item.
    $data = explode(",", stream_get_line($fh, 100000));

    // Select correct time for X axis, plus convert to desired format.
    // Stop when we have $tail unique X values.
    $time = $data[$xbin];
    if (! $last || $last != $time)
    {
      if (isset ($upto) && $upto != '' && $last && $last == $upto)
	break;

      $result[$time] = array();
      $last = $time;

      if (isset($tail) && $tail && count($result) > $tail)
	array_shift($result);
    }

    // Append to $result[$time][$node]
    $dest = $data[4];
    for ($n = 5; $n < count($data); ++$n)
    {
      $node = $labels[$n];
      if (preg_match("/MSS$/", $node)) continue;
      $key = ($by == 'link' ? "{$dest} < {$node}" :
              ($by == 'dest' ? $dest : $node));
      if (! isset ($result[$time][$key]))
        $result[$time][$key] = array (0, array());

      if ($sum)
      {
        $result[$time][$key][0] += $data[$n];
        $result[$time][$key][1][$data[3]] = 1;
      }
      else if (! isset ($result[$time][$key][1]["$dest:$node"]))
      {
        $result[$time][$key][0] = 1;
        $result[$time][$key][1]["$dest:$node"] = $data[$n];
      }
    }
  }

  fclose($fh);
  return $result;
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
