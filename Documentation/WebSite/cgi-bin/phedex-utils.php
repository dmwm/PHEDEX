<?
error_reporting(E_ALL);
ini_set("max_execution_time", "120");

// Read CSV file contents into an array of arrays.
function readCSV ($file, $delimiter)
{
  $data_array = file($file);
  for ( $i = 0; $i < count($data_array); $i++ )
    $parts_array[$i] = explode($delimiter,trim($data_array[$i]));
  return $parts_array;
}

// Interpret and rearrange quality history data.
function selectQualityData($data, $xbin, $tail, $upto)
{
  // Build a map of nodes we are interested in.
  $newdata = array(); $xvals = array();

  // If "up-to" limit is set, walk back from the end of the data array
  // until we find the specified time.  Then gather data from there.
  $end = count($data)-1;
  if (isset ($upto) && $upto != '')
    while ($end > 0 && $data[$end][$xbin] != $upto)
      --$end;

  // Collect all the data into correct binning.
  for ($i = $end; $i >= 1; --$i)
  {
    // Select correct time for X axis, plus convert to desired format.
    // Stop when we have $tail unique X values.
    $time = $data[$i][$xbin];
    if (! count($xvals) || $xvals[count($xvals)-1] != $time) $xvals[] = $time;
    if (isset($tail) && $tail && count($xvals) > $tail) break;

    // Append to $newdata[$time][$node]
    $newrow = array($time);
    for ($n = 4; $n < count($data[$i]); ++$n)
    {
      $node = $data[0][$n];
      if (preg_match("/MSS$/", $node)) continue;
      if (! isset ($newdata[$time][$node]))
        $newdata[$time][$node] = array (0, 0, 0);

      $values = explode ("/", $data[$i][$n]);
      $newdata[$time][$node][0] += $values[0];
      $newdata[$time][$node][1] += $values[1];
      $newdata[$time][$node][2] += $values[2];
    }
  }

  return array_reverse($newdata, true);
}

// Interpret and rearrange performance history data.
function selectPerformanceData($data, $xbin, $tail, $sum, $upto)
{
  // Build a map of nodes we are interested in.
  $newdata = array(); $xvals = array();

  // If "up-to" limit is set, walk back from the end of the data array
  // until we find the specified time.  Then gather data from there.
  $end = count($data)-1;
  if (isset ($upto) && $upto != '')
    while ($end > 0 && $data[$end][$xbin] != $upto)
      --$end;

  // Collect all the data into correct binning.
  for ($i = $end; $i >= 1; --$i)
  {
    // Select correct time for X axis, plus convert to desired format.
    // Stop when we have $tail unique X values.
    $time = $data[$i][$xbin];
    if (! count($xvals) || $xvals[count($xvals)-1] != $time) $xvals[] = $time;
    if (isset($tail) && $tail && count($xvals) > $tail) break;

    // Append to $newdata[$time][$node].  If $sum, it's additive (rate
    // or data transferred), otherwise pick last value of period (pending)
    $newrow = array($time);
    for ($n = 4; $n < count($data[$i]); ++$n)
    {
      $node = $data[0][$n];
      if (preg_match("/MSS$/", $node)) continue;
      if (! isset ($newdata[$time][$node]))
        $newdata[$time][$node] = array (0, 0);

      if ($sum)
      {
        $newdata[$time][$node][0] += $data[$i][$n];
        $newdata[$time][$node][1]++;
      }
      else if (! $newdata[$time][$node][0])
        $newdata[$time][$node][0] = $data[$i][$n];
    }
  }

  return array_reverse($newdata, true);
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
