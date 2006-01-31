<?php
include ("./jpgraph/jpgraph.php");
include ("./jpgraph/jpgraph_pie.php");
include ("./jpgraph/jpgraph_pie3d.php");
$data = array($_REQUEST['u'],$_REQUEST['d']);

if(!preg_match("/^[0-9]+$/", $_REQUEST['u'])) {
    die( "Illegal Up value"); 
}

if(!preg_match("/^[0-9]+$/", $_REQUEST['d'])) {
    die("Illegal down value");
}

$graph = new PieGraph(470,400,"auto");
$graph->SetShadow();

#Plot Titles
$graph->title->Set("Overall Heartbeat Status");
$graph->title->SetFont(FF_FONT1,FS_BOLD);
$plot = new PiePlot3D($data);

#Plot Labels
#$plot -> value -> SetFont(FF_FONT1, FS_BOLD);
#$plot -> value -> SetColor("darkred");
#$plot -> value -> SetLabelPos(0.6);

#$plot -> ExplodeAll();
$plot -> SetSize(0.4);
$plot -> SetCenter(0.50);
$plot -> SetSliceColors(array('yellow','red',));
$plot -> SetLegends(array('Links up','Links down'));
$graph->Add($plot);
$graph->Stroke();

?>
