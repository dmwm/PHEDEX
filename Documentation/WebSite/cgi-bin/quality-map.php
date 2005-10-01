<?
error_reporting(E_ALL);
ini_set("max_execution_time", "120");

function read_csv ($file, $delimiter)
{
  $data_array = file($file);
  for ( $i = 0; $i < count($data_array); $i++ )
    $parts_array[$i] = explode($delimiter,trim($data_array[$i]));
  return $parts_array;
}

@define ('BASE_PATH', dirname(__FILE__));
include BASE_PATH . "/jpgraph/jpgraph.php";
include BASE_PATH . "/jpgraph/jpgraph_line.php";

function selectData($data, $xbin, $tail)
{
  // Build a map of nodes we are interested in.
  $newdata = array(); $xvals = array();

  // Collect all the data into correct binning.
  for ($i = count($data)-1; $i >= 1; --$i)
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

function styleByValue($base, $dir, $value)
{
  // The first half of a "hsv" colour map, from IGUANA IgSbColorMap.cc.

  // First constrain $value.  <0 == none, otherwise clamp to [0, 1].
  // Then scale [0, 1] to [$base, $base+$dir] to use good portion of HSV gradient.
  $value = ($value > 1 ? 1 : $value);
  $value = ($value < 0 ? $value : $base + $dir * $value);
  if ($value < 0.) {
    $rgb = array (1, 1, 1);
  } else {
    $rgb = hsv2rgb ($value, 1, 1);
  }
  return sprintf ("#%02x%02x%02x", $rgb[0]*255, $rgb[1]*255, $rgb[2]*255);
}

function makeGraph($graph, $data, $args)
{
  // Build X-axis labels, by time.
  $xrewrite = $args['xrewrite'];
  $xlabels = array();
  foreach (array_keys($data) as $time)
      $xlabels[] = preg_replace("/{$xrewrite[0]}/", $xrewrite[1], $time);

  $xbins = count($data);
  $xunit = $args['xunit'];
  $nxunits = round($xbins / $xunit) + ($xbins % $xunit ? 1 : 0);
  $nrowskip = ($xbins <= 10 ? 1 : ($nxunits <= 10 ? $xunit : round($nxunits/10) * $xunit));

  // Get category labels for each node, going as y-axis
  $nodes = array();
  foreach ($data as $xbin => $xdata)
    foreach ($xdata as $node => $info)
      $nodes[$node] = 1;
  sort ($nodes = array_keys ($nodes));

  // Build a plot for node data.  X-axis is time, Y-axis nodes.  The
  // colouring is achieved by having a trivial line plot (height 1),
  // and adding "areas" to it, and then stacking the line plots so a
  // plot for each node stands on the other in vertical (Y) direction.
  $plots = array();
  $ylabels = array();
  $filter = $args['filter'];
  foreach ($nodes as $n => $node)
  {
    if (isset($filter) && $filter != '' && ! preg_match("/$filter/", $node))
      continue;

    // Suppress fully zero rows: nodes without any transfers
    $iszero = -1;
    foreach ($data as $xbin => $xdata)
      if (isset($xdata[$node]) && ($iszero = $xdata[$node][0]) > 0)
	break;
    if ($iszero <= 0) continue;

    // Construct an y bin (node) a line plot + areas for this node.
    $ylabels[] = $node;
    $thisplot = new LinePlot(array_fill(0, count($data), 1));
    $thisplot->SetColor ("#000000");

    $i = 0;
    if ($args['metric'] == 'failed_ratio')
      foreach ($data as $xbin => $xdata)
      {
        $thisplot->AddArea ($i, $i+1, LP_AREA_FILLED, styleByValue
			    (.4, -.4, isset ($xdata[$node]) && $xdata[$node][0]
			     ? $xdata[$node][1] / $xdata[$node][0] : -1));
        ++$i;
      }
    else if ($args['metric'] == 'completed_ratio')
      foreach ($data as $xbin => $xdata)
      {
        $thisplot->AddArea ($i, $i+1, LP_AREA_FILLED, styleByValue
			    (0, .4, isset ($xdata[$node]) && $xdata[$node][0]
	                     ? $xdata[$node][2] / $xdata[$node][0] : -1));
        ++$i;
      }

    $plots[] = $thisplot;
  }

  $ylabels[] = "";
  $plot = new AccLinePlot ($plots);

  // Configure the graph
  $graph->SetScale("textlin", 0, count($ylabels)-1);
  $graph->SetY2Scale ("lin", 0, count($ylabels)-1);
  $graph->SetColor("white");
  $graph->SetMarginColor("white");
  $graph->img->SetMargin(65,56+122,40,70);
  $graph->img->SetAntiAliasing();

  $graph->title->Set("PhEDEx Transfer Quality {$args['title']}");
  $graph->title->SetFont(FF_FONT2,FS_BOLD);
  $graph->title->SetColor("black");

  $nowstamp = gmdate("Y-m-d H:i");
  $graph->subtitle->Set("{$args['instance']} Transfer Quality"
  	                . ((isset($args['filter']) && $args['filter'] != '')
			   ? " Matching `{$args['filter']}'" : "")
	                . ", $nowstamp GMT");
  $graph->subtitle->SetFont(FF_FONT1,FS_BOLD);
  $graph->subtitle->SetColor("black");

  $graph->xaxis->SetTitle($args['xtitle'], 'middle');
  $graph->xaxis->SetTextLabelInterval($nrowskip);
  $graph->xaxis->SetTickLabels($xlabels);
  $graph->xaxis->SetLabelAlign('center');
  $graph->xaxis->title->SetFont(FF_FONT1,FS_BOLD);
  $graph->xscale->ticks->Set($nrowskip, $xunit);

  $graph->yaxis->title->Set($args['ytitle']);
  $graph->yaxis->title->SetFont(FF_FONT1,FS_BOLD);
  $graph->yaxis->SetTitleMargin(35);
  $graph->yaxis->HideLabels ();

  $graph->y2axis->SetLabelAlign ('left', 'bottom');
  $graph->y2axis->SetTickLabels ($ylabels);
  $graph->y2axis->SetTextTickInterval (1, 0);
  $graph->y2axis->SetTextLabelInterval (1);
  $graph->y2scale->ticks->Set(1,1);

  for ($i = 0; $i <= 100; $i += 10)
  {
    $color = styleByValue (0, 0.4, $i/100.);
    $range = $i == 100 ? "100+%" : sprintf ("%d-%d%%", $i, $i+10);
    $graph->legend->Add ($range, $color);
  }
  $graph->legend->Pos(0.44, 0.98, "center", "bottom");
  $graph->legend->SetLayout(LEGEND_HOR);
  $graph->legend->SetShadow(0);
  $graph->AddY2 ($plot);
  $graph->Stroke();
}

$kind_types       = array ('completed_ratio' => "Fraction of Completed Transfers vs. Attempted",
		           'failed_ratio'    => "Fraction of Failed Transfers vs. Attempted");
$srcdb            = $GLOBALS['HTTP_GET_VARS']['db'];
$span             = $GLOBALS['HTTP_GET_VARS']['span'];
$kind             = $GLOBALS['HTTP_GET_VARS']['kind'];
$entries          = $GLOBALS['HTTP_GET_VARS']['last'];
$args['filter']   = $GLOBALS['HTTP_GET_VARS']['filter'];

$args['metric']   = (isset ($kind_types[$kind]) ? $kind : 'completed_ratio');
$args['ytitle']   = $kind_types[$args['metric']];
$args['instance'] = ($srcdb == 'prod' ? 'Production'
	             : ($srcdb == 'test' ? 'Dev'
	                : ($srcdb == 'sc' ? 'SC3'
	                   : 'SC3')));
if ($span == "month")
{
  $args['title'] = ($entries ? "Last $entries Months" : "By Month");
  $args['xtitle'] = "Month";
  $args['xunit'] = 2;
  $args['xbin'] = 0;
  $args['xrewrite'] = array('(....)(..)', '\1-\2');
}
else if ($span == "week")
{
  $args['title'] = ($entries ? "Last $entries Weeks" : "By Week");
  $args['xtitle'] = "Week";
  $args['xunit'] = 4;
  $args['xbin'] = 1;
  $args['xrewrite'] = array('(....)(..)', '\1/\2');
}
else if ($span == "day")
{
  $args['title'] = ($entries ? "Last $entries Days" : "By Day");
  $args['xtitle'] = "Day";
  $args['xunit'] = 7;
  $args['xbin'] = 2;
  $args['xrewrite'] = array('(....)(..)(..)', '\1-\2-\3');
}
else // hour
{
  $args['title'] = ($entries ? "Last $entries Hours" : "By Hour");
  $args['xtitle'] = "Hour";
  $args['xunit'] = 4;
  $args['xbin'] = 3;
  $args['xrewrite'] = array('(....)(..)(..)Z(..)(..)', '\4:\5');
}

$graph = new Graph (900, 400, "auto");
$data = read_csv (BASE_PATH . "/data/{$args['instance']}-quality.csv", ",");
$data = selectData ($data, $args['xbin'], $entries);
makeGraph ($graph, $data, $args);

?>
