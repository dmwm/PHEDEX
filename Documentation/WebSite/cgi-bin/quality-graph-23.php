<?
@define ('BASE_PATH', dirname(__FILE__));
include BASE_PATH . "/phedex-utils-23.php";
include BASE_PATH . "/jpgraph/jpgraph.php";
include BASE_PATH . "/jpgraph/jpgraph_bar.php";

function makeGraph($graph, $data, $args, $upto, $by)
{
  // Rendering parameters
  $patterns = array('/^T1/' => 0, '/^T2/' => PATTERN_DIAG2, '/^/' => PATTERN_DIAG4);
  $styles = array("#e66266", "#fff8a9", "#7bea81", "#8d4dff", "#ffbc71", "#a57e81",
                  "#baceac", "#00ccff", "#63aafe", "#ccffff", /* "#ccffcc", "#ffff99", */
                  "#99ccff", "#ff99cc", "#cc99ff", "#ffcc99", "#3366ff", "#33cccc");

  // Build X-axis labels.  Make sure there are not too many of them.
  $xrewrite = $args['xrewrite'];
  $xlabels = array();
  $xkeys = array_keys($data);
  foreach ($xkeys as $time)
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

    $allzero = true;
    foreach ($data as $xbin => $xdata)
      if (isset($xdata[$node]) && max($xdata[$node]) > 0)
      {
	$allzero = false;
	break;
      }

    if ($allzero) continue;

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
    $plot = count($barplots) ? new GroupBarPlot ($barplots) : new AccBarPlot ($barplots);
  else
  {
    $plot = new AccBarPlot ($barplots);
    $plot->SetWidth(0.65);
  }

  // Compute how much the legend needs
  $legendcols = (count($barplots) > 25 ? 2 : 1);
  $legendwidth = ($by == 'link' ? 200 : 122);

  // Configure the graph
  $graph->SetScale("textlin");
  $graph->SetColor("white");
  $graph->SetMarginColor("white");
  $graph->img->SetMargin(65,56 + $legendcols * $legendwidth,40,40);
  $graph->img->SetAntiAliasing();

  $graph->title->Set("PhEDEx Transfer Quality {$args['title']}");
  $graph->title->SetFont(FF_VERDANA,FS_BOLD,14);
  $graph->title->SetColor("black");

  $nowstamp = gmdate("Y-m-d H:i");
  $urewrite = $args['urewrite'];
  $xlast = preg_replace("/{$urewrite[0]}/", $urewrite[1], $xkeys[count($xkeys)-1]);
  if (isset ($upto) && $upto != '')
    $upto = preg_replace("/{$urewrite[0]}/", $urewrite[1], $upto);
  $graph->subtitle->Set("{$args['instance']} transfer quality by "
  	                . ($by == 'link' ? "link" :
			   ($by == 'dest' ? "destination" : "source"))
			. ((isset($args['filter']) && $args['filter'] != '')
			   ? " matching '{$args['filter']}'," : "")
			. ((isset($upto) && $upto != '')
			   ? " up to $upto GMT, as of $nowstamp GMT"
			   : " as of $nowstamp GMT")
		        . ", last statistic {$xlast} GMT");
  $graph->subtitle->SetFont(FF_VERDANA,FS_NORMAL);
  $graph->subtitle->SetColor("black");

  $graph->xaxis->SetTitle($args['xtitle'], 'middle');
  $graph->xaxis->title->SetFont(FF_VERDANA,FS_NORMAL,11);
  $graph->xaxis->SetFont(FF_VERDANA,FS_NORMAL,9);
  $graph->xaxis->SetTextLabelInterval($nrowskip);
  $graph->xaxis->SetTickLabels($xlabels);
  $graph->xaxis->SetLabelAlign('center');
  $graph->xscale->ticks->Set($nrowskip, $xunit);

  $graph->yaxis->SetTitleMargin(35);
  $graph->yaxis->SetTitle($args['ytitle'], 'middle');
  $graph->yaxis->title->SetFont(FF_VERDANA,FS_NORMAL,11);
  $graph->yaxis->SetFont(FF_VERDANA,FS_NORMAL,9);

  $graph->legend->Pos(0.01, 0.5, "right", "center");
  $graph->legend->SetColumns($legendcols);
  $graph->legend->SetShadow(0);
  $graph->legend->SetFont(FF_VERDANA,FS_NORMAL,8);
  // $graph->legend->SetLayout(LEGEND_HOR);
  $graph->Add ($plot);
  $graph->Stroke();
}

$kind_types       = array ('attempted'       => "Attempted Transfers",
		           'failed'          => "Failed Transfers",
		           'completed'       => "Successful Transfers",
		           'completed_ratio' => "Fraction of Successful Transfers",
		           'failed_ratio'    => "Fraction of Failed Transfers");
$srcdb            = $GLOBALS['HTTP_GET_VARS']['db'];
$span             = $GLOBALS['HTTP_GET_VARS']['span'];
$kind             = $GLOBALS['HTTP_GET_VARS']['kind'];
$entries          = $GLOBALS['HTTP_GET_VARS']['last'];
$args['filter']   = $GLOBALS['HTTP_GET_VARS']['filter'];
$upto             = $GLOBALS['HTTP_GET_VARS']['upto'];
$by               = $GLOBALS['HTTP_GET_VARS']['by'];

if ($by != 'link' && $by != 'dest' && $by != 'src') $by = 'dest';

$args['metric']   = (isset ($kind_types[$kind]) ? $kind : 'completed_ratio');
$args['ytitle']   = $kind_types[$args['metric']];
$args['instance'] = ($srcdb == 'prod' ? 'Production'
	             : ($srcdb == 'test' ? 'Dev'
	                : ($srcdb == 'sc' ? 'SC4'
	                   : 'SC4')));
if ($span == "month")
{
  $args['title'] = ($entries ? "Last $entries Months" : "By Month");
  $args['xtitle'] = "Month";
  $args['xunit'] = 2;
  $args['xbin'] = 0;
  $args['xrewrite'] = array('(....)(..)', '\1-\2');
  $args['urewrite'] = $args['xrewrite'];
}
else if ($span == "week")
{
  $args['title'] = ($entries ? "Last $entries Weeks" : "By Week");
  $args['xtitle'] = "Week";
  $args['xunit'] = 4;
  $args['xbin'] = 1;
  $args['xrewrite'] = array('(....)(..)', '\1/\2');
  $args['urewrite'] = $args['xrewrite'];
}
else if ($span == "day")
{
  $args['title'] = ($entries ? "Last $entries Days" : "By Day");
  $args['xtitle'] = "Day";
  $args['xunit'] = 7;
  $args['xbin'] = 2;
  $args['xrewrite'] = array('(....)(..)(..)', '\1-\2-\3');
  $args['urewrite'] = $args['xrewrite'];
}
else // hour
{
  $args['title'] = ($entries ? "Last $entries Hours" : "By Hour");
  $args['xtitle'] = "Hour";
  $args['xunit'] = 4;
  $args['xbin'] = 3;
  $args['xrewrite'] = array('(....)(..)(..)Z(..)(..)', '\4:\5');
  $args['urewrite'] = array('(....)(..)(..)Z(..)(..)', '\1-\2-\3 \4:\5');
}

$graph = new Graph (900, 406, "auto");
$data = readCSV ("/afs/cern.ch/cms/aprom/phedex/DBPerfData/{$args['instance']}-quality.csv", ",");
$data = selectQualityData ($data, $args['xbin'], $entries, $upto, $by);
makeGraph ($graph, $data, $args, $upto, $by);

?>
