<?
@define ('BASE_PATH', dirname(__FILE__));
include BASE_PATH . "/phedex-utils-23.php";
include BASE_PATH . "/jpgraph/jpgraph.php";
include BASE_PATH . "/jpgraph/jpgraph_line.php";

function makeGraph($graph, $data, $args, $upto, $by)
{
  // Rendering parameters
  $styles = array("#e66266", "#fff8a9", "#7bea81", "#8d4dff", "#ffbc71", "#a57e81",
                  "#baceac", "#00ccff", "#63aafe", "#ccffff", /* "#ccffcc", "#ffff99", */
                  "#99ccff", "#ff99cc", "#cc99ff", "#ffcc99", "#3366ff", "#33cccc");

  // Build X-axis labels.  Make sure there are not too many of them.
  $xrewrite = $args['xrewrite'];
  $xlabels = array(preg_replace("/{$xrewrite[0]}/", $xrewrite[1], $data[0][0]));
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

  // Build a plot for each node and selected transfer metric.
  $legend = array();
  $barplots = array();
  $filter = $args['filter'];
  foreach ($nodes as $n => $node)
  {
    if (isset($filter) && $filter != '' && ! preg_match("/$filter/", $node))
      continue;

    // Check whether this node has any values
    $allzero = true;
    foreach ($data as $item)
      if (isset ($item[2][$node]) && $item[2][$node] > 0)
      {
	$allzero = false;
	break;
      }

    if ($allzero) continue;

    // Add to the plot
    $plotdata = array(0);
    foreach ($data as $item)
    {
      $plotdata[] = (isset ($item[2][$node]) ? $item[2][$node] : 0)
	+ $plotdata[count($plotdata)-1];
    }

    $barplot = new LinePlot($plotdata);
    $barplot->SetFillColor ($styles[$n % count($styles)]);
    if (! isset ($legend[$node]))
    {
      $legend[$node] = 1;
      $barplot->SetLegend ($node);
    }
    $barplots[] = $barplot;
  }

  // Build an accumulated bar plot from those
  $plot = new AccLinePlot ($barplots);

  // Compute how much the legend needs
  $legendcols = ($by == 'link' ? 3 : 6);
  $legendrows = round(count($legend)/$legendcols) + 1;
  $legendsize = (($by == 'link' || $legendrows > 3) ? 7 : 8);
  $legendmargin = ($legendsize * 1.8) * $legendrows + 10;

  // Configure the graph
  $graph->SetScale("textlin");
  $graph->SetColor("white");
  $graph->SetMarginColor("white");
  $graph->SetFrame(false);
  $graph->img->SetMargin(90,56,40,40+$legendmargin);
  $graph->img->SetAntiAliasing();

  $graph->title->Set("PhEDEx {$args['instance']} Data Transfers By "
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

  $graph->yaxis->SetTitleMargin(65);
  $graph->yaxis->SetTitle($args['ytitle'], 'middle');
  $graph->yaxis->title->SetFont(FF_VERDANA,FS_NORMAL,11);
  $graph->yaxis->SetFont(FF_VERDANA,FS_NORMAL,9);

  $graph->legend->Pos(.5, .99, "center", "bottom");
  $graph->legend->SetLayout(LEGEND_HOR);
  $graph->legend->SetColumns($legendcols);
  $graph->legend->SetShadow(0);
  $graph->legend->SetVColMargin(2);
  $graph->legend->SetFont(FF_VERDANA,FS_NORMAL,$legendsize);
  $graph->Add ($plot);
  $graph->Stroke();
}

$kind_types       = array ('total'      => "Data Transferred (TB)");
$srcdb            = $GLOBALS['HTTP_GET_VARS']['db'];
$span             = $GLOBALS['HTTP_GET_VARS']['span'];
$kind             = $GLOBALS['HTTP_GET_VARS']['kind'];
$entries          = $GLOBALS['HTTP_GET_VARS']['last'];
$args['filter']   = $GLOBALS['HTTP_GET_VARS']['filter'];
$upto             = $GLOBALS['HTTP_GET_VARS']['upto'];
$by		  = $GLOBALS['HTTP_GET_VARS']['by'];
$dir		  = $GLOBALS['HTTP_GET_VARS']['data'];

if ($by != 'link' && $by != 'dest' && $by != 'src') $by = 'dest';

$suffix		  = 'total';
$args['metric']   = (isset ($kind_types[$kind]) ? $kind : 'total');
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
  $filename = "/tmp/{$dir}/$suffix";
  $data = selectPerformanceData ($filename, $args['metric'] != 'pending');
  makeGraph (new Graph (800, 500, "auto"), $data, $args, $upto, $by);
}

?>
