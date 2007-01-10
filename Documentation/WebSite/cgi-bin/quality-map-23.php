<?
@define ('BASE_PATH', dirname(__FILE__));
include BASE_PATH . "/phedex-utils-23.php";
include BASE_PATH . "/jpgraph/jpgraph.php";
include BASE_PATH . "/jpgraph/jpgraph_line.php";

function makeGraph($graph, $data, $args, $upto, $by)
{
  // Build X-axis labels.  Make sure there are not too many of them.
  $xrewrite = $args['xrewrite'];
  $xlabels = array();
  foreach ($data as $item)
    $xlabels[] = preg_replace("/{$xrewrite[0]}/", $xrewrite[1], $item[0]);

  $xbins = count($data);
  $xunit = $args['xunit'];
  $maxunits = $args['maxunits'];
  $nxunits = round($xbins / $xunit) + ($xbins % $xunit ? 1 : 0);
  while ($nxunits > $maxunits) { $nxunits /= 2; $xunit *= 2; }
  $nrowskip = ($xbins <= 10 ? 1 : $xunit);

  // Get category labels for each style, used to generate consistent style
  $nodes = array();
  foreach ($data as $item)
    foreach ($item[2] as $node => $value)
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

    // Check whether this node has any values
    $allzero = true;
    foreach ($data as $item)
      if (isset ($item[2][$node]) && max($item[2][$node]) > 0)
      {
	$allzero = false;
	break;
      }

    if ($allzero) continue;

    // Construct an y bin (node) a line plot + areas for this node.
    $ylabels[] = $node;
    $thisplot = new LinePlot(array_fill(0, count($data)+1, 1));
    $thisplot->SetColor ("#000000");

    $i = 0;
    if ($args['metric'] == 'failed_ratio')
      foreach ($data as $item)
      {
	$started = (isset ($item[2][$node]) ? $item[2][$node][0] : 0);
	$failed = (isset ($item[2][$node]) ? $item[2][$node][1] : 0);
	$success = (isset ($item[2][$node]) ? $item[2][$node][2] : 0);
	$finished = $failed + $success;
	$fraction = $finished ? $failed / $finished : -1;
        $thisplot->AddArea ($i, $i+1, LP_AREA_FILLED,
	                    styleByValue (.4, -.4, 1, 0, $fraction, 1));
        ++$i;
      }
    else if ($args['metric'] == 'completed_ratio')
      foreach ($data as $item)
      {
	$started = (isset ($item[2][$node]) ? $item[2][$node][0] : 0);
	$failed = (isset ($item[2][$node]) ? $item[2][$node][1] : 0);
	$success = (isset ($item[2][$node]) ? $item[2][$node][2] : 0);
	$finished = $failed + $success;
	$fraction = $finished ? $success / $finished : -1;
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
  $graph->img->SetMargin(40,56+($by == 'link' ? 200 : 100),40,70);
  $graph->img->SetAntiAliasing();

  $graph->title->Set("PhEDEx {$args['instance']} Transfer Quality By "
  		     . ($by == 'link' ? "Link" :
		        ($by == 'dest' ? "Destination" : "Source")));
  $graph->title->SetFont(FF_VERDANA,FS_BOLD,14);
  $graph->title->SetColor("black");

  $urewrite = $args['urewrite'];
  $fromtime = preg_replace("/{$urewrite[0]}/", $urewrite[1], $data[0][0]);
  $totime   = preg_replace("/{$urewrite[0]}/", $urewrite[1], $data[count($data)-1][0]);
  $graph->subtitle->Set($args['title']
			. " from {$fromtime} to {$totime} GMT"
  	                . ((isset($args['filter']) && $args['filter'] != '')
			   ? "\nNodes matching regular expression '{$args['filter']}'" : ""));
  $graph->subtitle->SetFont(FF_VERDANA,FS_NORMAL);
  $graph->subtitle->SetColor("black");

  $graph->xaxis->SetTitle($args['xtitle'], 'middle');
  $graph->xaxis->title->SetFont(FF_VERDANA,FS_NORMAL,11);
  $graph->xaxis->SetFont(FF_VERDANA,FS_NORMAL,9);
  $graph->xaxis->SetTextLabelInterval($nrowskip);
  $graph->xaxis->SetTickLabels($xlabels);
  $graph->xaxis->SetLabelAlign('center');
  $graph->xscale->ticks->Set($nrowskip, $xunit);

  $graph->yaxis->SetTitleMargin(15);
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
  $graph->legend->Pos(0.5, 0.98, "center", "bottom");
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
$dir		  = $GLOBALS['HTTP_GET_VARS']['data'];

if ($by != 'link' && $by != 'dest' && $by != 'src') $by = 'dest';

$args['metric']   = (isset ($kind_types[$kind]) ? $kind : 'completed_ratio');
$args['ytitle']   = $kind_types[$args['metric']];
$args['instance'] = ($srcdb == 'prod' ? 'Prod'
	             : ($srcdb == 'test' ? 'Dev'
	                : ($srcdb == 'sc' ? 'SC4'
	                   : ($srcdb == 'tbedi' ? 'Testbed' : 'Validation'))));
if ($span == "month")
{
  $args['title'] = ($entries ? "$entries Months" : "By Month");
  $args['xtitle'] = "Month";
  $args['xunit'] = 2;
  $args['maxunits'] = 10;
  $args['xrewrite'] = array('(....)(..)', '\1-\2');
  $args['urewrite'] = $args['xrewrite'];
}
else if ($span == "week")
{
  $args['title'] = ($entries ? "$entries Weeks" : "By Week");
  $args['xtitle'] = "Week";
  $args['xunit'] = 4;
  $args['maxunits'] = 10;
  $args['xrewrite'] = array('(....)(..)', '\1/\2');
  $args['urewrite'] = $args['xrewrite'];
}
else if ($span == "day")
{
  $args['title'] = ($entries ? "$entries Days" : "By Day");
  $args['xtitle'] = "Day";
  $args['xunit'] = 7;
  $args['maxunits'] = 8;
  $args['xrewrite'] = array('(....)(..)(..)', '\1-\2-\3');
  $args['urewrite'] = $args['xrewrite'];
}
else // hour
{
  $args['title'] = ($entries ? "$entries Hours" : "By Hour");
  $args['xtitle'] = "Hour";
  $args['xunit'] = 4;
  $args['maxunits'] = 10;
  $args['xrewrite'] = array('(....)(..)(..)Z(..)(..)', '\4:\5');
  $args['urewrite'] = array('(....)(..)(..)Z(..)(..)', '\1-\2-\3 \4:\5');
}

if (isset($dir) && $dir != "" && preg_match("/^[A-Za-z][A-Za-z0-9.]+$/", $dir))
{
  $filename = "/tmp/{$dir}/quality";
  $data = selectQualityData ($filename);
  makeGraph (new Graph (800, 500, "auto"), $data, $args, $upto, $by);
}

?>
