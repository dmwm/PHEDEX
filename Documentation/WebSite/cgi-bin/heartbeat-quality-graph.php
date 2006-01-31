<?php
include ("./jpgraph/jpgraph.php");
include ("./jpgraph/jpgraph_bar.php");
include ("../cgi-bin/phedex-utils.php");

#Input parameters
$sourceSite = $_REQUEST['source'];
$tool = $_REQUEST['tool'];
$time = $_REQUEST['filter'];
$type = $_REQUEST['type'];
$xlabels = array();
$ylabels = array();
$fullspan = "no";
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

    $styles = array("#e66266", "#fff8a9", "#7bea81", "#8d4dff", "#ffbc71", "#a57e81",
                  "#baceac", "#00ccff", "#63aafe", "#ccffff", 
                  "#99ccff", "#ff99cc", "#cc99ff", "#ffcc99", "#3366ff", "#33cccc");

    $now = time();
    if($type == "attempted") {
        $ytitle = "Total Attempted Transfers";
    } elseif ($type == "success") {
        $ytitle = "Total Successful Transfers";
    } elseif ($type == "failure") {
        $ytitle = "Total Failed Transfer";
    }

   if ($time == "l7d") {
        
        $timediv = 86400;
        $range = $now - ($timediv*7);
        $xDataPonts = 7;
        $gtype = "wd";
        $xlabelInterval = 1;
        $title = "Last 7 days";
        $xtitle = "Days";

    } elseif ($time == "l14d") {
        
        $timediv = 86400;
        $range = $now - ($timediv*14);
        $xDataPonts = 14;
        $gtype = "wd";
        $xlabelInterval = 2;
        $title = "Last 14 days";
        $xtitle = "Days";

    } elseif ($time == "l30d") {
        
        $timediv = 86400;
        $range = $now - ($timediv*30);
        $xDataPonts = 30;
        $gtype = "wd";
        $xlabelInterval = 5;
        $title = "Last 30 days";
        $xtitle = "Days";

    } elseif ($time == "l90d") {
        
        $timediv = 86400;
        $range = $now - ($timediv*90);
        $xDataPonts = 90;
        $gtype = "wd";
        $xlabelInterval = 10;
        $title = "Last 90 days";
        $xtitle = "Days";

    } elseif ($time == "l6w") {
        
        $timediv = 604800;
        $range = $now - ($timediv*6);
        $xDataPonts = 6;
        $gtype = "wd";
        $xlabelInterval = 1;
        $title = "Last 6 Weeks";
        $xtitle = "Weeks";

    } elseif ($time == "ad") {

        $timediv = 86400;
        $range = 0;
        $gtype = "wd";
        $fullspan = "day";
        $xDataPonts = 0;
        $xlabelInterval = 10;
        $title = "Daily Since Start";
        $xtitle = "Days";

    } elseif ($time == "aw") {

        $timediv = 604800;
        $range = 0;
        $gtype = "wd";
        $fullspan = "week";
        $xDataPonts = 0;
        $xlabelInterval = 1;
        $title = "Weekly Since Start";
        $xtitle = "Weeks";

    } elseif ($time == "am") {
        $timediv = 2419200;
        $range = 0;
        $gtype = "wd";
        $fullspan = "month";
        $xDataPonts = 0;
        $xlabelInterval = 1;
        $title = "Monthly Since Start";
        $xtitle = "Months";
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
             $startTimeSelected = 1;             
        }          
    }    
    mysql_close($db);    
    if($fullspan == "day" || $fullspan == "week" || $fullspan == "month") {
        $xDataPonts = (ceil((time() - $startTime)/$timediv));
        $xlabelInterval = (ceil($xDataPonts/10));
    }

    $countlabels = 1;
    $siteCount = 0;
    if($gtype == "wd") {
         foreach ($dataSet as $dest => $tstamp) {    
             
             $plotData = array();        
             $ylabels[$countlabels]=$dest;             
             $countlabels++;
             foreach ($tstamp as $log => $logStatus) {           
      
                 if($fullspan == "day" || $fullspan == "week" || $fullspan == "month") {
                     $day = (int)(($log - $startTime) / $timediv);
                 } else { 
                     $day = (int)(($log - $range)/$timediv);
                 }     
            
                 if($type == "attempted") {
                     if(!isset($plotData[$day])) {
                        $plotData[$day] = 0;
                     }
                     $plotData[$day] = $plotData[$day]+1;   

                 } elseif($type =="success") {                     
                     if($logStatus == "OK") {
                         if(!isset($plotData[$day])) {
                             $plotData[$day] = 0;
 		         }
                         $plotData[$day] = $plotData[$day]+1;
                     }            
                 } elseif($type == "failure") {
	            if($logStatus == "NOK") {
                         if(!isset($plotData[$day])) {
                             $plotData[$day] = 0;
 		         }
                         $plotData[$day] = $plotData[$day]+1;
                     }            
                 }
             }   

             # Assign zero value for the days for which we don't have any data.
             # Otherwise jpgraph doesn't seems to be happy.

             for ($index=0; $index <= $xDataPonts; $index++) {
                 if(! isset($plotData[$index]))  {
                      $plotData[$index] = 0;
                 }     
             }            
             $barplot = new BarPlot($plotData);
	     $barplot->SetFillColor ($styles[$siteCount % count($styles)]);
             $barplot -> SetLegend($dest);
             $siteCount++;
             $plots[] = $barplot;
         }       
         
        #Seting up the values on the x-axis
        for ($i=0; $i <= $xDataPonts; $i++) {
            
	    if($fullspan == "day" || $fullspan == "week" || $fullspan == "month") {
                $date = getdate($startTime+($timediv*$i));
            } else {
                $date = getdate($range+($timediv*$i));
            }

            $month = $date['mon'];
            $day = $date["mday"];
            $year = $date["year"];
            if($fullspan == "month") {
                $xlabels[$i] = "$month-$year";
            } else {
                $xlabels[$i] = "$day-$month-$year";
            }
                        
        }
    }

    $plot = new AccBarPlot($plots);
    $plot->SetWidth(0.65);  
    
    $legendcols = (count($plots) > 25 ? 2 : 1);
    $graph->SetScale("textlin");
    $graph->SetColor("white");
    $graph->SetMarginColor("white");
    $graph->img->SetMargin(65,56 + 122,40,40);
    $graph->img->SetAntiAliasing();
   
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

    $graph->legend->Pos(0.01, 0.5, "right", "center");
    $graph->legend->SetColumns($legendcols);
    $graph->legend->SetShadow(0);
   
    $graph -> Add($plot);
    $graph -> Stroke();
}

function checkTime($time) {

    $permitedOptions = array("l7d","l14d", "l30d", "l90d", "l6w", "ad", "aw", "am");
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
