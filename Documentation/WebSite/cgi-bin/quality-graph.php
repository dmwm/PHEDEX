<?
error_reporting(E_ALL);

function read_csv ($file, $delimiter)
{
  $data_array = file($file);
  for ( $i = 0; $i < count($data_array); $i++ )
  {
    $parts_array[$i] = explode($delimiter,trim($data_array[$i]));
  }
  return $parts_array;
}

@define ('BASE_PATH', dirname(__FILE__));
include BASE_PATH . "/jpgraph/jpgraph.php";
include BASE_PATH . "/jpgraph/jpgraph_bar.php";

function selectData($data, $xbin, $tail, $filter)
{
  // Collect all the data into correct binning
  $newdata = array(); $xvals = array();
  for ($i = count($data)-1; $i >= 1; --$i)
  {
    // Reject data for nodes not interest to us
    $node = $data[$i][4];
    if (isset($filter) && $filter != '' && ! preg_match("/$filter/", $node))
      continue;

    // Select the right time for X axis plus convert to desired format.
    // Stop when we have $tail unique X values.
    $time = $data[$i][$xbin];
    if (! count($xvals) || $xvals[count($xvals)-1] != $time) $xvals[] = $time;
    if (isset($tail) && $tail && count($xvals) > $tail) break;

    // Transpose data to $newdata[xbin][node][attempted, errors, transferred]
    if (! isset ($newdata[$time][$node]))
    {
      $newdata[$time][$node] = array(0, 0, 0);
    }

    $newdata[$time][$node][0] += $data[$i][5];
    $newdata[$time][$node][1] += $data[$i][6];
    $newdata[$time][$node][2] += $data[$i][7];
  }

  return array_reverse($newdata, true);
}

function makeGraph($graph, $data, $args)
{
  // Rendering parameters
  $styles = array("#e66266", "#fff8a9", "#7bea81", "#8d4dff", "#ffbc71", "#a57e81",
		  "#baceac", "#00ccff", "#63aafe", "#ccffff", "#ccffcc", "#ffff99",
		  "#99ccff", "#ff99cc", "#cc99ff", "#ffcc99", "#3366ff", "#33cccc");
  $patterns = array('/^T1/' => 0, '/^T2/' => PATTERN_DIAG2, '/^/' => PATTERN_DIAG4);

  // Build X-axis labels.  Make sure there are not too many of them.
  $xrewrite = $args['xrewrite'];
  $xlabels = array();
  foreach (array_keys($data) as $time)
      $xlabels[] = preg_replace("/{$xrewrite[0]}/", $xrewrite[1], $time);

  $xbins = count($data);
  $xunit = $args['xunit'];
  $nxunits = round($xbins / $xunit) + ($xbins % $xunit ? 1 : 0);
  $nrowskip = ($xbins <= 10 ? 1 : ($nxunits <= 10 ? $xunit : round($nxunits/10) * $xunit));

  // Get category labels for each style, used to generate consistent style
  $nodes = array();
  foreach ($data as $xbin => $xdata)
    foreach ($xdata as $node => $info)
      $nodes[$node] = 1;
  sort ($nodes = array_keys ($nodes));

  // Assign patterns to nodes
  $nodepats = array();
  foreach ($nodes as $n => $node)
    foreach ($patterns as $pat => $patvalue)
    {
      if (! preg_match($pat, $node)) continue;
      $nodepats[$node] = $patvalue;
      break;
    }

  // Build a bar plot for each node and selected transfer metric.
  $legend = array();
  $barplots = array();
  foreach ($nodes as $n => $node)
  {
    $plotdata = array();
    if ($args['metric'] == 'attempted')
      foreach ($data as $xbin => $xdata)
        $plotdata[] = isset ($xdata[$node]) ? $xdata[$node][0] : 0;
    else if ($args['metric'] == 'failed')
      foreach ($data as $xbin => $xdata)
        $plotdata[] = isset ($xdata[$node]) ? $xdata[$node][1] : 0;
    else if ($args['metric'] == 'completed')
      foreach ($data as $xbin => $xdata)
        $plotdata[] = isset ($xdata[$node]) ? $xdata[$node][2] : 0;
    else if ($args['metric'] == 'failed_ratio')
      foreach ($data as $xbin => $xdata)
        $plotdata[] = isset ($xdata[$node]) && $xdata[$node][0]
		      ? $xdata[$node][1] / $xdata[$node][0] : 0;
    else if ($args['metric'] == 'completed_ratio')
      foreach ($data as $xbin => $xdata)
        $plotdata[] = isset ($xdata[$node]) && $xdata[$node][0]
		      ? $xdata[$node][2] / $xdata[$node][0] : 0;

    $barplot = new BarPlot($plotdata);
    $barplot->SetFillColor ($styles[$n % count($styles)]);
    if ($nodepats[$node])
      $barplot->SetPattern ($nodepats[$node], 'black');
    if (! isset ($legend[$node]))
    {
      $legend[$node] = 1;
      $barplot->SetLegend ($node);
    }
    $barplots[] = $barplot;
  }

  // Build an accumulated bar plot from those
  if ($args['metric'] == 'failed_ratio' || $args['metric'] == 'completed_ratio')
    $plot = new GroupBarPlot ($barplots);
  else
  {
    $plot = new AccBarPlot ($barplots);
    $plot->SetWidth(0.65);
  }

  // Compute how much the legend needs
  $legendcols = (count($nodes) > 20 ? 2 : 1);

  // Configure the graph
  $graph->SetScale("textlin");
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
  $graph->yaxis->SetTitleMargin(35);
  $graph->yaxis->title->SetFont(FF_FONT1,FS_BOLD);

  $graph->legend->Pos(0.01, 0.5, "right", "center");
  $graph->legend->SetColumns($legendcols);
  $graph->legend->SetShadow(0);
  // $graph->legend->SetLayout(LEGEND_HOR);
  $graph->Add ($plot);
  $graph->Stroke();
}

$kind_types       = array ('attempted'       => "Count of Attempted Transfers",
		           'failed'          => "Count of Failed Transfers",
		           'completed'       => "Count of Completed Transfers",
		           'completed_ratio' => "Fraction of Completed Transfers vs. Attempted",
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
  $args['xrewrite'] = array('(....)(..)(..)Z(..)(..)', "\\1-\\2-\\3\n   \\4:\\5");
}

$graph = new Graph (900, 400, "auto");
$data = read_csv (BASE_PATH . "/data/{$args['instance']}-xfer-quality.csv", ",");
$data = selectData ($data, $args['xbin'], $entries, $args['filter']);
makeGraph ($graph, $data, $args);

?>
