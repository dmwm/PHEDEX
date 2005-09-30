<?
error_reporting(E_ALL);

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

function styleByValue($value)
{
  // Rendering parameters: limit, color, line color, description
  $styles = array(array(-.1, "#ffffff", "#000000", "No transfers"),     // white
                  array(.15, "#ae0000", "#6a2055", "0-15% success"),    // blood red
  		  array(.25, "#ff0000", "#ff0000", "15-25% success"),   // bright red
  		  array(.50, "#012dfa", "#0518d5", "25-50% success"),   // dark blue
  		  array(.75, "#5287fe", "#0849de", "50-75% success"),   // light blue
		  array(.85, "#c0fe52", "#9cd70a", "75-85% success"),   // light green
		  array(.95, "#00c023", "#009d01", "85-95% success"),   // dark green
		  array(1.0, "#00e942", "#52c252", "95-100% success"),  // bright green
		  array(1e9, "#000000", "#ffffff", ">100% success"));   // black

  for ($s = 0; $s < count($styles); ++$s)
    if ($value <= $styles[$s][0])
      return $styles[$s][1];
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
  $legend = array();
  $plots = array();
  $filter = $args['filter'];
  foreach ($nodes as $n => $node)
  {
    if (isset($filter) && $filter != '' && ! preg_match("/$filter/", $node))
      continue;

    // Construct an y bin (node) a line plot + areas for this node.
    $thisplot = new LinePlot(array_fill(0, count($data), 1));
    $thisplot->SetColor ("#000000");

    $i = 0;
    if ($args['metric'] == 'failed_ratio')
      foreach ($data as $xbin => $xdata)
      {
        $thisplot->AddArea ($i, $i+1, LP_AREA_FILLED, styleByValue
			    (isset ($xdata[$node]) && $xdata[$node][0]
	                     ? $xdata[$node][1] / $xdata[$node][0] : -1));
	++$i;
      }
    else if ($args['metric'] == 'completed_ratio')
      foreach ($data as $xbin => $xdata)
      {
        $thisplot->AddArea ($i, $i+1, LP_AREA_FILLED, styleByValue
			    (isset ($xdata[$node]) && $xdata[$node][0]
	                     ? $xdata[$node][2] / $xdata[$node][0] : -1));
	++$i;
      }

    $plots[] = $thisplot;
    /*
    if (! isset ($legend[$node]))
    {
      $legend[$node] = 1;
      $barplot->SetLegend ($node);
    }
    */
  }

  $plot = new AccLinePlot ($plots);

  // Compute how much the legend needs
  $legendcols = (count($plots) > 20 ? 2 : 1);

  // Configure the graph
  $graph->SetScale("textlin", 0, count($nodes));
  $graph->SetColor("white");
  $graph->SetMarginColor("white");
  $graph->img->SetMargin(65,56 + $legendcols * 122,40,40);
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
  $graph->yaxis->SetTitleMargin(-130);
  $graph->yaxis->SetPos ('max');
  $graph->yaxis->SetLabelSide (SIDE_RIGHT);
  $graph->yaxis->SetTickSide (SIDE_LEFT);
  $graph->yaxis->SetTickLabels (array_merge(array_values ($nodes), array("")));
  $graph->yaxis->SetTextTickInterval (1, 0);
  $graph->yaxis->title->SetFont(FF_FONT1,FS_BOLD);
  $graph->yscale->ticks->Set(1,1);

  $graph->legend->Pos(0.01, 0.5, "right", "center");
  $graph->legend->SetColumns($legendcols);
  $graph->legend->SetShadow(0);
  // $graph->legend->SetLayout(LEGEND_HOR);
  $graph->Add ($plot);
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
