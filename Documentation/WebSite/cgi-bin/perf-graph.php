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

function makeGraph($graph, $data, $tail, $instance, $title, $xtitle, $ytitle, $xunit, $rewrite)
{
  // Get category labels and styles for each site
  $startrow = (! $tail || $tail > count($data)-1 ? 1 : count($data)-$tail);
  $categories = $data[0];
  $styles = array("#e66266", "#fff8a9", "#7bea81", "#8d4dff", "#ffbc71", "#a57e81",
		  "#baceac", "#00ccff", "#63aafe", "#ccffff", "#ccffcc", "#ffff99",
		  "#99ccff", "#ff99cc", "#cc99ff", "#ffcc99", "#3366ff", "#33cccc");
  $patterns = array(array ('/^T1/', 0),
  		    array ('/^T2/', PATTERN_DIAG2),
		    array ('/^/', PATTERN_DIAG4));

  // Build an array of bar plots, one for each category (site)
  $plots = array();
  for ($cat = 1; $cat < count($categories); $cat++)
  {
    $plotdata = array();
    for ($row = $startrow; $row < count($data); $row++)
    {
      $plotdata[$row-$startrow] = $data[$row][$cat];
    }
    $barplot = new BarPlot($plotdata);
    $barplot->SetFillColor ($styles[($cat-1) % count($styles)]);
    for ($pat = 0; $pat < count($patterns); $pat++)
    {
	if (! preg_match($patterns[$pat][0], $categories[$cat])) continue;
	if ($patterns[$pat][1]) $barplot->SetPattern ($patterns[$pat][1], 'black');
	break;
    }
    $barplot->SetLegend ($categories[$cat]);
    $plots[] = $barplot;
  }

  // Build X-axis labels.  Make sure there are not too many of them.
  $xlabels = array();
  $nrows = count($data) - $startrow;
  $nxunits = round($nrows / $xunit) + ($nrows % $xunit ? 1 : 0);
  $nrowskip = ($nrows <= 10 ? 1 : ($nxunits <= 10 ? $xunit : round($nxunits/10) * $xunit));
  for ($row = $startrow; $row < count($data); $row++)
  {
     $label = $data[$row][0];
     if ($rewrite) $label = preg_replace($rewrite[0], $rewrite[1], $label);
     $xlabels[] = $label;
  }

  // Build a compound bar plot from those
  $plot = new AccBarPlot ($plots);
  $plot->SetWidth(0.65);

  // Compute how much the legend needs
  $legendcols = (count($categories) > 20 ? 2 : 1);

  // Configure the graph
  $graph->SetScale("textlin");
  $graph->SetColor("white");
  $graph->SetMarginColor("white");
  $graph->img->SetMargin(65,56 + $legendcols * 122,40,40);
  $graph->img->SetAntiAliasing();

  $graph->title->Set("PhEDEx Data Transfers $title");
  $graph->title->SetFont(FF_FONT2,FS_BOLD);
  $graph->title->SetColor("black");

  $nowstamp = gmdate("Y-m-d H:i");
  $graph->subtitle->Set("$instance Transfers, $nowstamp GMT");
  $graph->subtitle->SetFont(FF_FONT1,FS_BOLD);
  $graph->subtitle->SetColor("black");

  $graph->xaxis->SetTitle($xtitle, 'middle');
  $graph->xaxis->SetTextLabelInterval($nrowskip);
  $graph->xaxis->SetTickLabels($xlabels);
  $graph->xaxis->SetLabelAlign('center');
  $graph->xaxis->title->SetFont(FF_FONT1,FS_BOLD);
  $graph->xscale->ticks->Set($nrowskip, $xunit);

  $graph->yaxis->title->Set($ytitle);
  $graph->yaxis->SetTitleMargin(35);
  $graph->yaxis->title->SetFont(FF_FONT1,FS_BOLD);

  $graph->legend->Pos(0.01, 0.5, "right", "center");
  $graph->legend->SetColumns($legendcols);
  $graph->legend->SetShadow(0);
  // $graph->legend->SetLayout(LEGEND_HOR);
  $graph->Add ($plot);
  $graph->Stroke();
}

$srcdb    = $GLOBALS['HTTP_GET_VARS']['db'];
$span     = $GLOBALS['HTTP_GET_VARS']['span'];
$kind     = $GLOBALS['HTTP_GET_VARS']['kind'];
$entries  = $GLOBALS['HTTP_GET_VARS']['last'];

$ytitle   = ($kind == 'rate' ? 'Throughput (MB/s)' : 'Terabytes');
$ksuffix  = (($kind == 'rate' || $kind == 'total') ? $kind : 'Unknown');
$prefix   = ($srcdb == 'prod' ? 'Production'
	     : ($srcdb == 'test' ? 'Dev'
	        : ($srcdb == 'sc' ? 'SC3'
	           : 'Unknown')));
if ($span == "hour")
{
  $tsuffix = $span;
  $title = ($entries ? "Last $entries Hours" : "By Hour");
  $xtitle = "Hour";
  $xunit = 4;
  $rewrite = ($entries ? array('/.*Z(..)(..)/', '\1:\2')
  	      : array('/(.*)Z(.*)/', '\1\n\2'));
}
else if ($span == "day")
{
  $tsuffix = $span;
  $title = ($entries ? "Last $entries Days" : "By Day");
  $xtitle = "Day";
  $xunit = 7;
  $rewrite = array('/(....)(..)(..)/', '\1-\2-\3');
}
else if ($span == "week")
{
  $tsuffix = $span;
  $title = ($entries ? "Last $entries Weeks" : "By Week");
  $xtitle = "Week";
  $xunit = 4;
  $rewrite = array('/(....)(..)/', '\1/\2');
}
else if ($span == "month")
{
  $tsuffix = $span;
  $title = ($entries ? "Last $entries Months" : "By Month");
  $xtitle = "Month";
  $xunit = 2;
  $rewrite = array('/(....)(..)/', '\1-\2');
}
else
{
  $tsuffix = "Unknown";
  $title = "Unknown Time Period";
  $xtitle = "Time Period";
  $xunit = 2;
  $rewrite = 0;
}

$graph = new Graph (900, 400, "auto");
$data = read_csv (BASE_PATH . "/data/$prefix-$tsuffix-$ksuffix.csv", ",");
makeGraph ($graph, $data, $entries, $prefix, $title, $xtitle, $ytitle, $xunit, $rewrite);

?>
