<?php
include ("./jpgraph/jpgraph.php");
include ("./jpgraph/jpgraph_line.php");
include ("./phedex-utils.php");

#Input parameters
$sourceSite = $_REQUEST['source'];
$tool = $_REQUEST['tool'];
$time = $_REQUEST['filter'];
$xlabels = array();
$ylabels = array();
if($tool && $sourceSite && $time && checkTime($time)) {
    if($tool != "srmcp" && $tool != "globus-url-copy") {
        die("Please specify correct tool name");
    }    
    #Read in the database configuration
    $fileName = '/afs/cern.ch/cms/aprom/phedex/DBAccessInfo/dbconf';
    $fileHandle = fopen($fileName,'r');
    $dbConf = array();
    if($fileHandle) {

        while(!feof ($fileHandle)) {
            $data = fgets($fileHandle);
            $values = preg_split('/\s+/', $data);
            if(sizeof($values) >=2 ) {
                $values[1] = trim($values[1]);
                $dbConf[$values[0]] = $values[1]; 
            }
        }
    } else {
        echo "Couldn't read the database configuration file while generating the graph!";
    }

    $now = time();
    $ytitle = "Hourly Link Status";
    $xtitle = "Hours";
    if($time == "l48h") {

        $range = $now - (60*60*48);
        $xDataPonts = 48;
        $gtype = "hour";
        $xlabelInterval = 4;
        $title = "Last 48 Hours";       

    } elseif ($time == "l72h") {
        
        $range = $now - (60*60*72);
        $xDataPonts = 72;
        $gtype = "hour"; 
        $xlabelInterval = 6;
        $title = "Last 72 Hours";

    } elseif ($time == "l96h") {

        $range = $now - (60*60*96);
        $xDataPonts = 96;
        $xlabelInterval = 8;
        $gtype = "hour";
        $title = "Last 96 Hours";     

    } elseif ($time == "l132h") {
        
        $range = $now - (60*60*132);
        $xDataPonts = 132;
        $gtype = "hour";
        $xlabelInterval = 8;
        $title = "Last 132 Hours";

    } elseif ($time == "l7d") {
        
        $timediv = 86400;
        $range = $now - ($timediv*7);
        $xDataPonts = 7;
        $gtype = "wd";
        $xlabelInterval = 1;
        $title = "Last 7 days";
        $xtitle = "Days";
        $ytitle = "Attempted Transfers vs Successful Transfers";

    } elseif ($time == "l14d") {
        
        $timediv = 86400;
        $range = $now - ($timediv*14);
        $xDataPonts = 14;
        $gtype = "wd";
        $xlabelInterval = 2;
        $title = "Last 14 days";
        $xtitle = "Days";
        $ytitle = "Attempted Transfers vs Successful Transfers";

    } elseif ($time == "l30d") {
        
        $timediv = 86400;
        $range = $now - ($timediv*30);
        $xDataPonts = 30;
        $gtype = "wd";
        $xlabelInterval = 5;
        $title = "Last 30 days";
        $xtitle = "Days";
        $ytitle = "Attempted Transfers vs Successful Transfers";

    } elseif ($time == "l90d") {
        
        $timediv = 86400;
        $range = $now - ($timediv*90);
        $xDataPonts = 90;
        $gtype = "wd";
        $xlabelInterval = 10;
        $title = "Last 90 days";
        $xtitle = "Days";
        $ytitle = "Attempted Transfers vs Successful Transfers";

    } elseif ($time == "l6w") {
        
        $timediv = 604800;
        $range = $now - ($timediv*6);
        $xDataPonts = 6;
        $gtype = "wd";
        $xlabelInterval = 1;
        $title = "Last 6 Weeks";
        $xtitle = "Weeks";
        $ytitle = "Attempted Transfers vs Successful Transfers";

    } elseif ($time == "ad") {

        $timediv = 86400;
        $range = 0;
        $gtype = "ad";
    }

    $db = mysql_connect($dbConf['host'], $dbConf['user'], $dbConf['password']);
    mysql_select_db($dbConf['database'],$db);

    $query = sprintf("SELECT log_id,destin_site,logstatus,timestamp FROM site_logs "
             ."WHERE source_site='%s' AND  tool='%s' AND "
             ."timestamp>='%s' ORDER BY timestamp",
             mysql_real_escape_string($sourceSite),
             mysql_real_escape_string($tool),
             mysql_real_escape_string($range));

    $result = mysql_query($query);

    $graph = new Graph(900,400, "auto");
    $graph -> SetScale("textlin");
    $dataSet = array();
    $plots = array();
    $startTime = 0;
    $startTimeSelected = 0;

    while ($myrow = mysql_fetch_row($result)) {
        $dataSet[$myrow[1]][$myrow[3]] = $myrow[2];
        if(!$startTimeSelected) {
             $startTime = $myrow[3];
        }          
    }

    $countlabels = 1;
    if($gtype == "wd") {
         foreach ($dataSet as $dest => $tstamp) {
             $responseOk = array();
             $totalResponses = array();        
             $ylabels[$countlabels]=$dest;             
             $countlabels++;
             foreach ($tstamp as $log => $logStatus) {                 
                 $day = (int)(($log - $range)/$timediv);
#                 echo strftime ("%b %d %Y %H:%M:%S",($log)),"  ",$logStatus,"<br>";

                 if(!isset($responseOk[$day])) {
                     $responseOk[$day] = 0;
                 } 
                 if ($logStatus == "OK") {
                     $responseOk[$day] = $responseOk[$day]+1;                     
                 }

                 if(!isset($totalResponses[$day])) {
                    $totalResponses[$day] = 0;
                 }
                 $totalResponses[$day] = $totalResponses[$day]+1;                                    
             }
             
             $lineplot = new LinePlot(array_fill(0, $xDataPonts+1, 1));
             $lineplot -> SetColor("#000000");             
             for ($i=0; $i<$xDataPonts; $i++) {           
                 if(isset($responseOk[$i]) && isset($totalResponses[$i])) {                  
                     $successRation = (($responseOk[$i]/$totalResponses[$i]));                    
                     $lineplot -> AddArea($i, $i+1, LP_AREA_FILLED, styleByValue(.0, 0.4, 1, 0,$successRation,1));                    
                 }
             }               
             $plots[] = $lineplot;
         }
         #Set up the legend.
         for ($i=0; $i <= 100; $i += 10) 
         {
             $color = styleByValue (0, 0.4, 1, 0, $i/100, 1);
             $colrange = ( $i == 100) ? "100+%" : sprintf ("%d-%d%%", $i, $i+10);
             $graph -> legend -> Add ($colrange, $color);
         }       
         
        #Seting up the values on the x-axis
        for ($i=0; $i <= $xDataPonts; $i++) {
            $date = getdate($range+($timediv*$i));
            $month = $date['mon'];
            $day = $date["mday"];
            $year = $date["year"];
            $xlabels[$i] = "$day-$month-$year";
                        
        }
    } else {
        foreach ($dataSet as $dest => $tstamp) {
            $lineplot = new LinePlot(array_fill(0,$xDataPonts+1,1));
            $lineplot -> SetColor("#000000");        
            $ylabels[$countlabels] = $dest;
            $countlabels++;
            foreach ($tstamp as $log => $logS) {
                #echo $dest." at ".$log." is ".$logS;           
                $hour = $log - $range;    
                $hourNo = (int)($hour/(60*60));
                if($logS == "OK") {
                    $lineplot -> AddArea($hourNo, $hourNo+1, LP_AREA_FILLED,'green');
                } else {
                    $lineplot -> AddArea($hourNo, $hourNo+1, LP_AREA_FILLED,'red');
                }                
            }
            $plots[] = $lineplot;
        }

        $timeLabel =getdate($range);    
        $hours = $timeLabel['hours'];    
        $mins = $timeLabel['minutes'];
        $mins  = ($mins<=9?"0$mins":$mins);

        for ($count =0; $count<= $xDataPonts; $count+=$xlabelInterval) {                  
            $hour = ($hours+$count)%24;            
            $hour = ($hour<=9?"0$hour":$hour);
            $xlabels[$count] =  $hour.":".$mins;
        }
        
        $graph -> legend -> Add('Link Up', 'green');
        $graph -> legend -> Add('Link Down', 'red');
    }
   
    $graph -> legend -> Pos(0.44, 0.98, "center", "bottom");
    $graph -> legend -> SetLayout(LEGEND_HOR);
    $graph -> legend -> SetShadow(0);

    $plot = new AccLinePlot ($plots);
    $graph -> SetScale("textlin",0,sizeof($dataSet));
    $graph -> SetY2Scale("lin",0,sizeof($dataSet));
    $graph -> SetColor("white");
    $graph -> SetMarginColor("white");
    $graph -> img -> SetMargin(66,56+122,40,70);
    $graph -> img -> SetAntiAliasing();
   
    $graph -> title -> Set("Heartbeat Transfer Quality $title");    
    $graph -> title -> SetFont(FF_FONT1, FS_BOLD);
    $graph -> title -> SetColor("black");

    #echo sizeof($xlabels);
    $graph -> xaxis -> SetTitle($xtitle,'middle');
    $graph -> xaxis -> SetTextLabelInterval($xlabelInterval);
    $graph -> xaxis -> SetTickLabels($xlabels);
    $graph -> xaxis -> SetLabelAlign('center');
    $graph -> xaxis -> title -> SetFont(FF_FONT1, FS_BOLD);
    $graph -> xscale->ticks->Set(4,4);

    $graph->yaxis->title->Set("$ytitle");
    $graph->yaxis->title->SetFont(FF_FONT1,FS_BOLD);
    $graph->yaxis->SetTitleMargin(35);
    $graph->yaxis->HideLabels ();
    $graph->yaxis->HideTicks();
    
    $graph->y2axis->scale->ticks->Set (.5,.5);
    $graph->y2axis->SetTickLabels ($ylabels);
    $graph->y2axis->SetTextLabelInterval (2);
    $graph->y2axis->HideFirstTickLabel ();
    $graph->y2axis->HideTicks ();   
     
    $graph -> AddY2 ($plot);
    $graph -> Stroke();
}

function checkTime($time) {

    $permitedOptions = array("l48h", "l72h", "l96h", "l132h", "l7d", "l14d", "l30d", "l90d", "l6w", "ad", "aw", "am");
    $return = 0;
    for($index=0; $index<count($permitedOptions); $index++) {
        if ($time == $permitedOptions[$index]) {
            $return = 1;
        }
    }
    if(!$return) {
        print "Please specify valid value for the filter";
    }
    return $return;
};
?>
