<?
@define ('BASE_PATH', dirname(__FILE__));
include BASE_PATH . "/phedex-utils.php";
include BASE_PATH . "/jpgraph/jpgraph.php";
include BASE_PATH . "/jpgraph/jpgraph_bar.php";

// Interpret and rearrange job data.
function selectJobData($data, $all)
{
  // Build a map of nodes we are interested in.
  $newdata = array(); $xvals = array();

  // Collect all the data into correct binning.
  for ($i = 1; $i < count($data); ++$i)
  {
    $node = $data[$i][1];
    $status = $data[$i][5];
    if (($status == 'Done' || $status == 'Retrieved') && $data[$i][6] != '')
        $status = "{$status}, Exit {$data[$i][6]}";
    $count = $data[$i][7];

    if (! $all && preg_match("/Aborted|Retrieved/", $status))
      continue;

    if (! isset ($newdata[$status][$node]))
      $newdata[$status][$node] = 0;

    $newdata[$status][$node] += $count;
  }

  return $newdata;
}


function makeGraph($graph, $data)
{
  // Rendering parameters
  $styles = array("#e66266", "#fff8a9", "#7bea81", "#8d4dff", "#ffbc71", "#a57e81",
                  "#baceac", "#00ccff", "#63aafe", "#ccffff", "#ccffcc", "#ffff99",
                  "#99ccff", "#ff99cc", "#cc99ff", "#ffcc99", "#3366ff", "#33cccc");

  // Get category labels for each status and node
  sort ($statuses = array_keys ($data));
  $nodes = array();
  foreach ($data as $status => $sdata)
    foreach ($sdata as $node => $value)
      $nodes[$node] = 1;
  sort ($nodes = array_keys ($nodes));

  // Build a bar plot for each node and selected transfer metric.
  $legend = array();
  $barplots = array();
  foreach ($statuses as $sn => $status)
  {
    $plotdata = array();
    foreach ($nodes as $nn => $node)
      $plotdata[] = (isset ($data[$status][$node])
                     ? $data[$status][$node] : 0);

    $barplot = new BarPlot($plotdata);
    $barplot->SetFillColor ($styles[$sn % count($styles)]);
    if (! isset ($legend[$status]))
    {
      $legend[$status] = 1;
      $barplot->SetLegend ($status);
    }
    $barplots[] = $barplot;
  }

  // Build an accumulated bar plot from those
  $plot = new AccBarPlot ($barplots);
  $plot->SetWidth(0.65);

  // Configure the graph
  $graph->SetScale("textlin");
  $graph->SetColor("white");
  $graph->SetMarginColor("white");
  $graph->img->SetMargin(65,56+122,40,40);
  $graph->img->SetAntiAliasing();

  $graph->title->Set("SC3 Job Submission State");
  $graph->title->SetFont(FF_FONT2,FS_BOLD);
  $graph->title->SetColor("black");

  $nowstamp = gmdate("Y-m-d H:i");
  $graph->subtitle->Set("$nowstamp GMT");
  $graph->subtitle->SetFont(FF_FONT1,FS_BOLD);
  $graph->subtitle->SetColor("black");

  $graph->xaxis->SetTitle('PubDB Site Name', 'middle');
  $graph->xaxis->SetTickLabels($nodes);
  $graph->xaxis->SetLabelAlign('center');
  $graph->xaxis->title->SetFont(FF_FONT1,FS_BOLD);

  $graph->yaxis->title->Set('Number of Jobs');
  $graph->yaxis->SetTitleMargin(35);
  $graph->yaxis->title->SetFont(FF_FONT1,FS_BOLD);

  $graph->legend->Pos(0.01, 0.5, "right", "center");
  $graph->legend->SetColumns(1);
  $graph->legend->SetShadow(0);
  // $graph->legend->SetLayout(LEGEND_HOR);
  $graph->Add ($plot);
  $graph->Stroke();
}

$graph = new Graph (900, 400, "auto");
$data = readCSV ("/afs/cern.ch/cms/aprom/phedex/SC/SC3Jobs/profile/jobstatus.csv", ",");
$all = isset ($GLOBALS['HTTP_GET_VARS']['all']) ? 1 : 0;
makeGraph ($graph, selectJobData ($data,$all));

?>
