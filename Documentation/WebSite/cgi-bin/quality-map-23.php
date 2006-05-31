<?
@define ('BASE_PATH', dirname(__FILE__));
include BASE_PATH . "/phedex-utils-23.php";
include BASE_PATH . "/jpgraph/jpgraph.php";
include BASE_PATH . "/jpgraph/jpgraph_line.php";

function makeGraph($graph, $data, $args, $upto, $by)
{
  // Build X-axis labels, by time.
  $xrewrite = $args['xrewrite'];
  $xlabels = array();
  $xkeys = array_keys($data);
  foreach ($xkeys as $time)
      $xlabels[] = preg_replace("/{$xrewrite[0]}/", $xrewrite[1], $time);
  $xlabels[] = "";

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
      if (isset($xdata[$node]) && ($iszero = max($xdata[$node])) > 0)
	break;
    if ($iszero <= 0) continue;

    // Construct an y bin (node) a line plot + areas for this node.
    $ylabels[] = $node;
    $thisplot = new LinePlot(array_fill(0, count($data)+1, 1));
    $thisplot->SetColor ("#000000");

    $i = 0;
    if ($args['metric'] == 'failed_ratio')
      foreach ($data as $xbin => $xdata)
      {
	$fraction = -1;
	if (isset ($xdata[$node]) && $xdata[$node][0])
	  $fraction = $xdata[$node][1] / $xdata[$node][0];
	else if (isset ($xdata[$node]) && $xdata[$node][1])
	  $fraction = 1;
        $thisplot->AddArea ($i, $i+1, LP_AREA_FILLED,
	                    styleByValue (.4, -.4, 1, 0, $fraction, 1));
        ++$i;
      }
    else if ($args['metric'] == 'completed_ratio')
      foreach ($data as $xbin => $xdata)
      {
	$fraction = -1;
	if (isset ($xdata[$node]) && $xdata[$node][0])
	  $fraction = $xdata[$node][2] / $xdata[$node][0];
	else if (isset ($xdata[$node]) && $xdata[$node][2])
	  $fraction = 1;
        $thisplot->AddArea ($i, $i+1, LP_AREA_FILLED,
	                    styleByValue (0, .4, 1, 0, $fraction, 1));
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
  $graph->SetFrame(false);
  $graph->img->SetMargin(90,56+($by == 'link' ? 200 : 130),40,70);
  $graph->img->SetAntiAliasing();

  $graph->title->Set("PhEDEx {$args['instance']} Transfer Quality By "
  		     . ($by == 'link' ? "Link" :
		        ($by == 'dest' ? "Destination" : "Source"))
  	             . ((isset($args['filter']) && $args['filter'] != '')
			? "s matching '{$args['filter']}'" : ""));
  $graph->title->SetFont(FF_VERDANA,FS_BOLD,14);
  $graph->title->SetColor("black");

  $nowstamp = gmdate("Y-m-d H:i");
  $urewrite = $args['urewrite'];
  $xlast = preg_replace("/{$urewrite[0]}/", $urewrite[1], $xkeys[count($xkeys)-1]);
  if (isset ($upto) && $upto != '')
    $upto = preg_replace("/{$urewrite[0]}/", $urewrite[1], $upto);
  $graph->subtitle->Set($args['title']
			. ((isset($upto) && $upto != '')
			   ? " up to $upto, at $nowstamp"
			   : " at $nowstamp")
		   	. ", last entry {$xlast} GMT");
  $graph->subtitle->SetFont(FF_VERDANA,FS_NORMAL);
  $graph->subtitle->SetColor("black");

  $graph->xaxis->SetTitle($args['xtitle'], 'middle');
  $graph->xaxis->title->SetFont(FF_VERDANA,FS_NORMAL,11);
  $graph->xaxis->SetFont(FF_VERDANA,FS_NORMAL,9);
  $graph->xaxis->SetTextLabelInterval($nrowskip);
  $graph->xaxis->SetTickLabels($xlabels);
  $graph->xaxis->SetLabelAlign('center');
  $graph->xscale->ticks->Set($nrowskip, $xunit);

  $graph->yaxis->SetTitleMargin(65);
  $graph->yaxis->SetTitle($args['ytitle'], 'middle');
  $graph->yaxis->title->SetFont(FF_VERDANA,FS_NORMAL,11);
  $graph->yaxis->SetFont(FF_VERDANA,FS_NORMAL,9);
  $graph->yaxis->HideLabels ();
  $graph->yaxis->HideTicks();

  $graph->y2axis->scale->ticks->Set (.5,.5);
  $graph->y2axis->title->SetFont(FF_VERDANA,FS_NORMAL,11);
  $graph->y2axis->SetFont(FF_VERDANA,FS_NORMAL,count($ylabels) > 26 ? 6 : 9);
  $graph->y2axis->SetTickLabels ($ylabels);
  $graph->y2axis->SetTextLabelInterval (2);
  $graph->y2axis->HideFirstTickLabel ();
  $graph->y2axis->HideTicks ();

  for ($i = 0; $i <= 100; $i += 10)
  {
    $color = styleByValue (0, 0.4, 1, 0, $i/100., 1);
    $range = $i == 100 ? "100+%" : sprintf ("%d-%d%%", $i, $i+10);
    $graph->legend->Add ($range, $color);
  }
  $graph->legend->Pos(0.44, 0.98, "center", "bottom");
  $graph->legend->SetLayout(LEGEND_HOR);
  $graph->legend->SetShadow(0);
  $graph->legend->SetFont(FF_VERDANA,FS_NORMAL,8);
  $graph->AddY2 ($plot);
  $graph->Stroke();
}

$kind_types       = array ('completed_ratio' => "Fraction of Successful Transfers",
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
	                   : ($srcdb == 'tbedi' ? 'Testbed' : 'Validation'))));
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
