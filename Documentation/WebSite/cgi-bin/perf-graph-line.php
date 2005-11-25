<?
@define ('BASE_PATH', dirname(__FILE__));
include BASE_PATH . "/phedex-utils.php";
include BASE_PATH . "/jpgraph/jpgraph.php";
include BASE_PATH . "/jpgraph/jpgraph_line.php";

function makeGraph($graph, $data, $args, $upto)
{
  // Rendering parameters
  $patterns = array('/^T1/' => 0, '/^T2/' => PATTERN_DIAG2, '/^/' => PATTERN_DIAG4);
  $styles = array("#e66266", "#fff8a9", "#7bea81", "#8d4dff", "#ffbc71", "#a57e81",
                  "#baceac", "#00ccff", "#63aafe", "#ccffff", /* "#ccffcc", "#ffff99", */
                  "#99ccff", "#ff99cc", "#cc99ff", "#ffcc99", "#3366ff", "#33cccc");

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
  $filter = $args['filter'];
  foreach ($nodes as $n => $node)
  {
    if (isset($filter) && $filter != '' && ! preg_match("/$filter/", $node))
      continue;

    $plotdata = array();
    if ($args['metric'] == 'rate')
      foreach ($data as $xbin => $xdata)
      {
	$last = count($plotdata) ? $plotdata[count($plotdata)-1] : 0;
        $plotdata[] = ((isset ($xdata[$node]) && $xdata[$node][1])
		       ? (1024*1024*$xdata[$node][0])/($xdata[$node][1]*3600)
		       : 0) + $last;
      }
    else // total || pending
      foreach ($data as $xbin => $xdata)
      {
	$last = count($plotdata) ? $plotdata[count($plotdata)-1] : 0;
        $plotdata[] = (isset ($xdata[$node]) ? $xdata[$node][0] : 0) + $last;
      }

    $barplot = new LinePlot($plotdata);
    $barplot->SetFillColor ($styles[$n % count($styles)]);
    // if ($nodepats[$node]) $barplot->SetPattern ($nodepats[$node], 'black');
    if (! isset ($legend[$node]))
    {
      $legend[$node] = 1;
      $barplot->SetLegend ($node);
    }
    $barplots[] = $barplot;
  }

  // Build an accumulated bar plot from those
  $plot = new AccLinePlot ($barplots);
  // $plot->SetWidth(0.65);

  // Compute how much the legend needs
  $legendcols = (count($barplots) > 30 ? 2 : 1);

  // Configure the graph
  $graph->SetScale("textlin");
  $graph->SetColor("white");
  $graph->SetMarginColor("white");
  $graph->img->SetMargin(65,56 + $legendcols * 122,40,40);
  $graph->img->SetAntiAliasing();

  $graph->title->Set("PhEDEx Data Transfers {$args['title']}");
  $graph->title->SetFont(FF_FONT2,FS_BOLD);
  $graph->title->SetColor("black");

  $nowstamp = gmdate("Y-m-d H:i");
  $graph->subtitle->Set("{$args['instance']} Transfers"
  	                . ((isset($args['filter']) && $args['filter'] != '')
			   ? " Matching `{$args['filter']}'" : "")
			. ((isset($upto) && $upto != '')
			   ? ", upto $upto GMT"
			   : ", $nowstamp GMT"));
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
  $graph->legend->SetVColMargin(2);
  // $graph->legend->SetLayout(LEGEND_HOR);
  $graph->Add ($plot);
  $graph->Stroke();
}

$kind_types       = array ('rate'       => "Throughput (MB/s)",
		           'total'      => "Data Transferred (TB)",
		           'pending'    => "Pending Transfer Queue (TB)");
$srcdb            = $GLOBALS['HTTP_GET_VARS']['db'];
$span             = $GLOBALS['HTTP_GET_VARS']['span'];
$kind             = $GLOBALS['HTTP_GET_VARS']['kind'];
$entries          = $GLOBALS['HTTP_GET_VARS']['last'];
$args['filter']   = $GLOBALS['HTTP_GET_VARS']['filter'];
$upto             = $GLOBALS['HTTP_GET_VARS']['upto'];

$suffix           = ($kind == 'pending' ? 'pending' : 'total');
$args['metric']   = (isset ($kind_types[$kind]) ? $kind : 'rate');
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
$data = readCSV ("/afs/cern.ch/cms/aprom/phedex/DBPerfData/{$args['instance']}-$suffix.csv", ",");
$data = selectPerformanceData ($data, $args['xbin'], $entries, $args['metric'] != 'pending', $upto);
makeGraph ($graph, $data, $args, $upto);

?>
