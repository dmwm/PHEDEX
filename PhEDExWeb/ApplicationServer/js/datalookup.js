//====================================================================================================
//File Name  : datalookup.js
//Purpose    : The javascript functions for gettting block information from Phedex database using web
//             APIs provided by Phedex and then format result to show it to user in YUI datatable.
//====================================================================================================

//Global Variables
var bFormTable;              //The boolean indicated if table has to be formed again or not
var sliderRange;             //The object of the slider for percentage range of the data transfer
var nPgBarIndex;         	 //The unique ID for the progress bar
var recordAllRow;            //The first row (Total row) object of the datatable
var dialogUserMsg;           //The object of the dialog that is used to show user message
var arrQueryBlkNames;        //The input query block names
var totalRow = {};           //The first row JSON object that has the values
var jsonBlkData = [];        //The JSON block data object received from data service call
var regexpDot = null;        //The Regular expression object
var arrBlocks = null;        //The associative array stores all the blocks
var dsBlocks, dtResult;		 //The YUI datasource and datatable
var lowpercent, highpercent; //The lower and higher percentage range of the data transfer
var arrColumns = null, arrColumnNode = null;      //The map that stores current column names and all the node names
var nOrigLowPercent = 0, nOrigHighPercent = 0; 	  //The original low percent and max percent to avoid re-formatting the result
var strOrigBlkQuery = "", strOrigNodeQuery = "";  //The original input block names of the query to avoid re-formatting the result



//****************************************************************************************************
//Function:InitializeForm
//Purpose :This initializes the form i.e buttons and slider are created using Yahoo APIs 
//****************************************************************************************************
function InitializeForm()
{
    // Create Yahoo! Buttons
    var objPushBtnGet = new YAHOO.widget.Button({ label:"Get Block Data Info", id:"buttonGetInfo", container:"GetInfoBtn", onclick: { fn: GetDataInfo } });
    var objPushBtnReset = new YAHOO.widget.Button({ label:"Reset", id:"buttonReset", container:"ResetBtn", onclick: { fn: Reset } });
    
    var Dom = YAHOO.util.Dom;
    var range = 200;          // The range of slider in pixels
    var tickSize = 0;         // This is the pixels count by which the slider moves in fixed pixel increments
    var minThumbDistance = 0; // The minimum distance the thumbs can be from one another
    var initValues = [0,200]; // Initial values for the Slider in pixels
    
    // Create the Yahoo! DualSlider
    var objsliderRange = Dom.get("sliderRange");  //Get the slider DOM object to initialize it
    sliderRange = YAHOO.widget.Slider.getHorizDualSlider(objsliderRange, "sliderLower", "sliderHigher", range, tickSize, initValues);
    sliderRange.minRange = minThumbDistance;
    sliderRange.subscribe('ready', UpdateRange);  //Adding the function to ready event
    sliderRange.subscribe('change', UpdateRange); //Adding the function to change event
    
    document.getElementById("txtboxBlock").value = "";	//Reset the block name text box
    document.getElementById("txtboxNode").value = "";   //Reset the node name text box
    ClearResult();  //Reset the result
    
    var handleOK = function() 
    {
		this.hide(); //Hide the messagebox after user clicks OK
	};
    // Create the message box dialog
	dialogUserMsg = new YAHOO.widget.SimpleDialog("dialogUserMsg", { width: "400px",
	                                                                 height: "100px",
	                                                                 fixedcenter: true,
                                                                     visible: false,
                                                                     draggable: false,
                                                                     close: true,
                                                                     text: "Phedex Data Lookup message box",
                                                                     icon: YAHOO.widget.SimpleDialog.ICON_WARN,
                                                                     constraintoviewport: true,
                                                                     buttons: [ { text:"OK", handler:handleOK, isDefault:true}]
                                                                     });
	dialogUserMsg.setHeader("Phedex Data Lookup"); //Set the header of the message box
	dialogUserMsg.render(document.body);
	
	//Initialize the variables
	nPgBarIndex = 0;
	mapBlocks = null;
	bFormTable = false;
    arrColumnNode = null;
    var strDot = ".";
	regexpDot = new RegExp(strDot);
}

//****************************************************************************************************
//Function:ConvertSliderVal
//Purpose :This gets the actual data transfer percentage value from the slider range value which is 
//         in pixels.
//****************************************************************************************************
function ConvertSliderVal(value)
{
    var temp = 100/(200 - 20);
    return Math.round(value * temp); // Convert the min and max values of slider into percentage range
}

//****************************************************************************************************
//Function:UpdateRange
//Purpose :This updates the data transfer percentage range values as user moves the slider.
//****************************************************************************************************
function UpdateRange()
{
    //Set the values of the percentage range
    document.getElementById("txtRange").innerHTML = ConvertSliderVal(sliderRange.minVal) + " - " + ConvertSliderVal(sliderRange.maxVal-20) + " %"; 
}

//****************************************************************************************************
//Function:ClearResult
//Purpose :This function resets the "Result" elements in the web page for new search
//****************************************************************************************************
function ClearResult()
{    
    document.getElementById("Result").innerHTML = "";       //Reset the result element
    document.getElementById("MissingBlks").innerHTML = "";  //Reset the result element
}

//****************************************************************************************************
//Function:Reset
//Purpose :This function resets all elements in the web page for new search
//****************************************************************************************************
function Reset()
{
    ClearResult();
    nOrigLowPercent = 0;    //Reset the original low percent
    nOrigHighPercent = 0;   //Reset the original high percent
    strOrigBlkQuery = "";   //Reset the original block name query
    strOrigNodeQuery = "";  //Reset the original node filter query
    sliderRange.setValues(0,200);                       //Reset the values of the percentage range in pixels
    document.getElementById("txtboxBlock").value = "";  //Reset the block name text box
    document.getElementById("txtboxNode").value = "";   //Reset the node name text box
    document.getElementById("txtRange").innerHTML = ConvertSliderVal(sliderRange.minVal) + " - " + ConvertSliderVal(sliderRange.maxVal-20) + " %";
}

//****************************************************************************************************
//Function:NewNode
//Purpose :This function creates and returns node object that stores the node information (name,
//         current size that has been transferred so far and percent of transfer completed)
//****************************************************************************************************
function NewNode(name, currentsize, completepercent)
{
    var objNode = new Object(); //create new node object
    objNode.NodeName = name;
    objNode.CurrentSize = currentsize;
    objNode.CompletePercent = completepercent;
    return objNode; //return the node object
}

//****************************************************************************************************
//Function:AddBlockNode
//Purpose :The hash map stores the block name as key and block info ( block name, size, file count,   
//         list of nodes) as its value. This function adds node info to the hash map for the input 
//         block name.
//****************************************************************************************************
function AddBlockNode(strBlockName, nTotalSize, nTotalFiles, objNode)
{
    var objBlock = arrBlocks[strBlockName];
    if (objBlock == null)
    {
        objBlock = new Object(); //create new node object and assign the arguments to the properties of object
        objBlock.BlockName = strBlockName;
        objBlock.TotalSize = nTotalSize;
        objBlock.TotalFiles = nTotalFiles;
        objBlock.MinPercent = objNode.CompletePercent;
        objBlock.MaxPercent = objNode.CompletePercent;
        arrNodes = new Array();
        arrNodes[objNode.NodeName] = objNode;
        objBlock.Nodes = arrNodes;
        arrBlocks[strBlockName] = objBlock;
    }
    else
    {
        arrNodes = objBlock.Nodes;
        arrNodes[objNode.NodeName] = objNode;
        if (objNode.CompletePercent > objBlock.MaxPercent)
        {
            objBlock.MaxPercent = objNode.CompletePercent; //Update the maximum percentage
        }
        else if (objNode.CompletePercent < objBlock.MinPercent)
        {
            objBlock.MinPercent = objNode.CompletePercent; //Update the minimum percentage
        }
    }
}

function InsertData(arrData, strKey, strVal)
{
    var objVal = arrData[strKey]; //Get the value for the key
    if (objVal == null)
    {
        arrData[strKey] = strVal; //Add the value
    }
}

//****************************************************************************************************
//Function:GetDataInfo
//Purpose :This function gets the block information from Phedex database using web APIs provided by 
//         Phedex. First, the input is checked if it is valid or not. If input is invalid, user is
//         alerted with a message. The communication with web API is done using Yahoo User Interface
//         (YUI) library API - connection manager: makes connection using browser specific protocol.
//         The result is obtained in JSON (Javascript Object Notation) format. Again, YUI library API
//         is used to parse the json response and use it for formatting. Finally, result is formatted
//         and is shown to user in YUI datatable.
//****************************************************************************************************
function GetDataInfo()
{
    //debugger; //For debugging purpose
    var strDataInput = document.getElementById("txtboxBlock").value;
    strDataInput = strDataInput.trim(); //Remove the whitespaces from the ends of the string
    if (!strDataInput)
    {
        dialogUserMsg.cfg.setProperty("text","Please enter the query block name(s)."); //Alert user if input is missing
        dialogUserMsg.show();
        ClearResult();
        return;
    }
    lowpercent = ConvertSliderVal(sliderRange.minVal);
    highpercent = ConvertSliderVal(sliderRange.maxVal-20);

    var btnGetInfo = document.getElementById("buttonGetInfo");
    var btnReset = document.getElementById("buttonReset");
    btnGetInfo.disabled = true; //Disable the Get Info button
    btnReset.disabled = true;   //Disable the Reset button
    
    strDataInput = strDataInput.replace(/\n/g, " ");
    var blocknames = strDataInput.split(/\s+/); //Split the blocks names using the delimiter whitespace (" ")
    var indx = 0;
    var strURL = "http://cmsweb.cern.ch/phedex/datasvc/json/prod/blockreplicas?";
    var tempblkname = "";
    arrQueryBlkNames = new Array();
    for (indx = 0; indx < blocknames.length; indx++)
    {
        tempblkname = blocknames[indx].trim(); //Remove the whitespaces in the blocknames
        InsertData(arrQueryBlkNames,tempblkname,"");
        tempblkname = escape(tempblkname);
        strURL =  strURL + 'block=' + tempblkname;
        if (!(indx == (blocknames.length - 1)))
        {
            strURL =  strURL + '&';
        }
    }
    var strNodeInput = document.getElementById("txtboxNode").value;
    if (strOrigBlkQuery == strDataInput) //Check if current query block names and previous query block names are same or not
    {
        //No change in the input query. So, no need make data service call
        if (!(strOrigNodeQuery == strNodeInput))
        {
            arrColumns = FilterNodes(); //Filter the nodes as entered by user
            document.getElementById("MissingBlks").innerHTML = "Please wait... the query is being processed..."; //Show user the status message
            FormatResult(arrColumns); //Do UI updates - show the block info to user in YUI datatable.
        }
        else if (!((nOrigHighPercent == highpercent) && (nOrigLowPercent == lowpercent))) //Check if there is any change in the percentage range
        {
            document.getElementById("MissingBlks").innerHTML = "Please wait... the query is being processed..."; //Show user the status message
            FormatResult(arrColumns); //Do UI updates - show the block info to user in YUI datatable.
        }
        strOrigNodeQuery = strNodeInput;
        btnGetInfo.disabled = false; //Enable the Get Info button
        btnReset.disabled = false;   //Enable the Reset button
        return; 
    }
    
    document.getElementById("Result").innerHTML = "";
    document.getElementById("MissingBlks").innerHTML = "Please wait... the query is being processed..."; //Show user the status message
    //Store the value for future use to check if value has changed or not and then format the result
    nOrigLowPercent = lowpercent; 
    nOrigHighPercent = highpercent;
    strOrigBlkQuery = strDataInput;
    strOrigNodeQuery = strNodeInput;
    
    strURL = "myproxy.php?url=" + "'" + escape(strURL) + "'"; //Use the proxy to overcome the cross-domain issue
    
    //Callback function used by YUI connection manager on completing the connection request with web API
    var callback = {
    //If YUI connection manager succeeds communicating with web API and gets response, then this callback function is called
    success: function(obj) 
    {
        var jsonResponse = obj.responseText; //Get the json reponse returned by web API
        var indxBlock = 0, indxReplica = 0, indxNode = 0;
        try 
        {
			var blk = null, replica = null;
            var blockbytes = 0, blockcount = 0, blockfiles = 0, replicabytes = 0, replicacount = 0;
            jsonBlkData = YAHOO.lang.JSON.parse(jsonResponse); //Use YUI API to parse the received json response
            arrBlocks = new Array();
            if (arrColumnNode)
            {
                arrColumnNode = null;
            }
            arrColumnNode = new Array(); //Create new associative array to store all the node names
            
            blockcount = jsonBlkData.phedex.block.length; //Get the block count from json response
            //Traverse through the blocks in json response to get block information
            for (indxBlock = 0; indxBlock < blockcount; indxBlock++)
            {
                blk = null;
                blk = jsonBlkData.phedex.block[indxBlock]; //Get the block object from the json response
                if (blk)
                {
                    blockbytes = blk.bytes/1; //Get bytes count that has to be transferred
                    blockfiles = blk.files/1; //Get number of files of the block
                    
                    replicacount = blk.replica.length;  //Get the count of replicas (nodes) to whom the block is being transferred
                    //Traverse through the replicas (nodes) for each block to get node information
	                for (indxReplica = 0; indxReplica < replicacount; indxReplica++)
                    {
                        replica = null;
                        replica = blk.replica[indxReplica]; //Get the replica (node) object from the json response
                        if (replica)
                        {
                            replicabytes = replica.bytes/1; //Get the bytes count that was transferred
                            var percentcompleted = 100 * replicabytes/blockbytes; //Calculate the data transfer percenatage
                            if (IsDecimal(percentcompleted))
                            {
                                percentcompleted = percentcompleted.toFixed(2); //Round off the percentage to 2 decimal digits
                            }
                            var objNode = NewNode(replica.node, replicabytes, percentcompleted); //Create new node object to add to hash table
                            AddBlockNode(blk.name, blockbytes, blockfiles, objNode);  //Add the block and its new node info to the hash map
                            InsertData(arrColumnNode,replica.node,""); //Add the node name to the hash map
                        }
                    }
                }
            }
            
            if (blockcount == 0) // Check if there is any block information to show to user
            {
                //No blocks are found for the given input
                if (ArrayLength(arrQueryBlkNames) > 0)
                {
                    var strXmlMsg = GetMissingBlocks(); //Get the block names for which data service returned nothing and show to user
					document.getElementById("Result").innerHTML = ""; //Reset the result
                    document.getElementById("MissingBlks").innerHTML = strXmlMsg; //Show the result to user
                }
            }
            else
            {
                //Do UI updates - show the block info to user
                arrColumns = FilterNodes(); //Filter the results using the node filter
                if (ArrayLength(arrColumns) > 0)
                {
                    FormatResult(arrColumns);
                }
                else
                {
                    bFormTable = true;
                    var strXmlMsg = GetMissingBlocks(); //Get the block names for which data service returned nothing and show to user
                    document.getElementById("MissingBlks").innerHTML = strXmlMsg;
                }
            }
        }
        catch (e)
        {
            alert("Invalid response. Please check the input.");
			ClearResult();
        }
        btnGetInfo.disabled = false; //Enable the Get Info button
        btnReset.disabled = false;   //Enable the Reset button
        return;
    },
    
    //If YUI connection manager fails communicating with web API, then this callback function is called
    failure: function(obj)
    {
        alert("Error in communicating with Phedex and receiving the response.");
        ClearResult(); //Clear the result elements
        btnGetInfo.disabled = false; //Enable the Get Info button
        btnReset.disabled = false;   //Enable the Reset button
        return;
    },
    timeout: 10000 //YUI connection manager timeout in milliseconds.
    };
      
    //Use Yahoo Connection manager to communicate with the web API and get response
    var transaction = YAHOO.util.Connect.asyncRequest('GET', strURL, callback, null);
}

//*****************************************************************************************************
//Function:AddColumns
//Purpose :This adds new columns (nodes) to the datatable and assign the column properties also.
//*****************************************************************************************************
function AddColumns(arrColumns)
{
    var strColumnName = "";
    var dtColumns = [];
    for (strColumnName in arrColumns)
    {
        dtColumns.push({"key":strColumnName,"sortable":true,"formatter":"customProgressBar"});
    }
    return dtColumns;
}

//****************************************************************************************************
//Function:UpdateTotalRow
//Purpose :This adds\updates "Total Row" values in associative array i.e total values of all columns.
//****************************************************************************************************
function UpdateTotalRow(arrTotal, strColumnName, nValue)
{
    var nVal = arrTotal[strColumnName]; //Get the value for the table column
    if (nVal)
    {
        arrTotal[strColumnName] = nVal + nValue; //Update the total value
    }
    else
    {
        arrTotal[strColumnName] = nValue //Add the total value 
    }
}

//****************************************************************************************************
//Function:ShowNode
//Purpose :This checks if the node column has to be shown in the datatable or not by checking the data
//		   transfer percentage of all blocks of that node
//****************************************************************************************************
function ShowNode(strColumnName)
{
    var nTransferPercent = 0, indx = 0, nLength = 0;
    var recsetNode = dtResult.getRecordSet(); //Get the values of the column
    nLength = recsetNode.getLength();
    for (indx = 1; indx < nLength; indx++)
    {
        var recBlock = recsetNode.getRecord(indx);
        nTransferPercent = recBlock.getData(strColumnName);
        if ((nTransferPercent >= lowpercent) && (nTransferPercent <= highpercent)) //Check if percentage is within query range
        {
            return true;  //Show this node to user
        }
    }
    return false; //Do not show this node to user
}

//*****************************************************************************************************
//Function:GetQueryColumns
//Purpose :This gets the list of nodes that match with the given separate expression of the node filter
//*****************************************************************************************************
function GetQueryColumns(strQuery)
{
    var bShow = false, strColumnName = "";
    var arrQueryCols = new Array(); //Create new associative array to store node column names
    for (strColumnName in arrColumns)
    {
        var regexpNodes = new RegExp(strQuery);       //Form the regular expression object
        var bExist = regexpNodes.test(strColumnName); //Check if this node matched with the given expression of input node filter
        if (bExist)
        {
            //Show the node column
            InsertData(arrQueryCols, strColumnName, "");
        }
    }
    return arrQueryCols; //Return the set that has the column names for the input node filter expression
}

//*****************************************************************************************************
//Function:FilterNodes
//Purpose :This filters the result based on the input node filter. Only nodes matching the filter 
//         (separate expressions are ANDed) will be shown as columns in the table.
//*****************************************************************************************************
function FilterNodes()
{
    var indx = 0;
    var strColumnName = "", strName = "", strRegExp = "";
    var strNodeNames = document.getElementById("txtboxNode").value; //Get the node filter
    strNodeNames = strNodeNames.trim(); //Remove the whitespaces from the ends of the string
    if (strNodeNames.length == 0) //If node query box is empty, then show all columns
    {
        return arrColumnNode;
    }
    
    strNodeNames = strNodeNames.replace(/\n/g, " ");
    var arrNodeNames = strNodeNames.split(/\s+/); //Split the blocks names using the delimiter whitespace (" ")
    var arrQueryNodes = new Array();
    for (indx = 0; indx < arrNodeNames.length; indx++)
    {
        strName = arrNodeNames[indx].trim(); //Remove the whitespaces in the blocknames
        InsertData(arrQueryNodes, strName, "");
    }
    
    var nLoop = 0;
    var arrNodeCols = null, arrQueryCols = null;
    var arrTemp = new Array();
    for (strName in arrQueryNodes)
    {
        arrQueryCols = GetQueryColumns(strName); //Get the list of nodes that match with the given separate expression of the node filter 
        if (nLoop == 0) //If first loop, then just copy the result of query to the result column list
        {
            arrNodeCols = arrQueryCols;            
            nLoop++;
        }
        else
        {
            //Find the intersection of query result and seperate expression result
            arrTemp = new Array();
            for (strColumnName in arrQueryCols)
            {
                var obj = arrNodeCols[strColumnName];
			    if (obj == "")
			    {
			        InsertData(arrTemp, strColumnName,""); //Add if both sets have same item
			    }
            }
            arrNodeCols = null;   //Clear the previous result
            arrNodeCols = arrTemp; //The query result is updated with the new value
        }
    }
    return arrNodeCols; //Return the set of nodes to be shown to user
}

//****************************************************************************************************
//Function:HideColumn
//Purpose :This hides the column in the datatable
//****************************************************************************************************
function HideColumn(strColumnName)
{
    var objColumn = dtResult.getColumn(strColumnName); //Get the column object
    if (objColumn)
    {
        dtResult.hideColumn(objColumn); //Hide the column
    }
}

//****************************************************************************************************
//Function:ShowColumn
//Purpose :This shows the column in the datatable
//****************************************************************************************************
function ShowColumn(strColumnName)
{
    var objColumn = dtResult.getColumn(strColumnName); //Get the column object
    if (objColumn)
    {
        dtResult.showColumn(objColumn); //Show the column
    }
}

function ArrayLength(array)
{
    var nLength = 0;
    for (var object in array) 
    {
        nLength++;
    }
    return nLength;
}
 
//****************************************************************************************************
//Function:ShowBlock
//Purpose :This checks if the block row has to be shown in the datatable or not by checking the data
//		   transfer percentage of all block nodes
//****************************************************************************************************
function ShowBlock(objBlock, arrColumn)
{
    var strColumnName = "";
    var jsonNode = null, objNode = null;
    var nTransferPercent = 0, nNodeCount = 0;
    var arrBlkNodes = objBlock.Nodes;
    if (arrBlkNodes)
    {
        nNodeCount = ArrayLength(arrBlkNodes);
        if (nNodeCount < ArrayLength(arrColumnNode))
        {
            objBlock.MinPercent = 0;
        }
        if (!((highpercent < objBlock.MinPercent) || (objBlock.MaxPercent < lowpercent)))
        {
            for (strColumnName in arrColumn)
            {
                objNode = arrBlkNodes[strColumnName]; //Get the block info for the given block name
                if (objNode)
                {
                    nTransferPercent = objNode.CompletePercent;
                }
                else
                {
                    nTransferPercent = 0;
                }
                if ((nTransferPercent >= lowpercent) && (nTransferPercent <= highpercent)) //Check if percentage is within query range
                {
                    return true; //Show this block to user
                }
            }
        }
    }
    return false; //Do not show this block to user
}

//*****************************************************************************************************
//Function:FormatResult
//Purpose :This function takes hash map that has block and block info. This information is formatted to
//         get the actual result in YUI datatable to display to user on browser. jQuery UI API is used
//         to display the data transfer percentage using its progress bar.
//*****************************************************************************************************
function FormatResult(arrColumn)
{
    var data = [];
    var bShow = false;
    var strBlockName = "", strColumnName = "";
    var nCurrentSize = 0, nTransferPercent = 0, nCount = 0;
    var objArr =null, objBlock = null, objNode = null, arrBlkNodes = null;
    var arrTotal = new Array(); //Create new associate array to store all the total row
    
    nPgBarIndex = 0; //Reset the ID of the progress bar    
    for (objArr in arrBlocks)
    {
        objBlock = arrBlocks[objArr];
        if (objBlock == null)
        {
            continue;
        }
        bShow = ShowBlock(objBlock, arrColumn); //Check if the block can be shown to user
        if (bShow)
        {
            nCount++;
            arrBlkNodes = objBlock.Nodes;
            //The block has percentage range within user input query range. So show this block to user
            strBlockName = objBlock.BlockName; //Get the block name
            var row = {"blockname":strBlockName,"blockfiles":objBlock.TotalFiles,"blockbytes":objBlock.TotalSize};
            for (strColumnName in arrColumn)
            {
                arrBlkNodes = objBlock.Nodes;
                objNode = arrBlkNodes[strColumnName]; //Get the node info for the given node name
                if (objNode)
                {
                    nTransferPercent = objNode.CompletePercent;
                    UpdateTotalRow(arrTotal, strColumnName, objNode.CurrentSize);
                }
                else
                {
                    nTransferPercent = 0;
                }
                row[strColumnName] = nTransferPercent;
            }
            //This checks the result obtained from data serice, input block names and shows user if input is invalid
            QueryBlockExists(strBlockName);

            data.push(row);
            UpdateTotalRow(arrTotal, "blockfiles", objBlock.TotalFiles); //Update the values of Total Row for the datatable
            UpdateTotalRow(arrTotal, "blockbytes", objBlock.TotalSize);	//Update the values of Total Row for the datatable
        }
    }
    
    //The custom progress bar format to the node column
    var formatProgressBar = function(elCell, oRecord, oColumn, sData)
    {
        var nSize = oRecord.getData("blockbytes") * sData/100; //Calculate the current size of the block data transferred
        var strHTML = '<div><div id = "BlkProgressBar' + ++nPgBarIndex + '" role="progressbar" aria-valuemin="0" aria-valuemax=100" aria-valuenow="' + sData + '" ';
        var strPerHTML = '';
        if ((sData >= lowpercent) && (sData <= highpercent))  
        {
            //The percentage is within query range
            strHTML = strHTML + 'class="progressbar ui-progressbar ui-widget ui-widget-content ui-corner-all" aria-disabled="true">';
            strPerHTML = '<div class = "percent">' + sData + '% (' + ConvertSize(nSize) + ')</div>';
        }
        else
        {
            //The percentage is NOT within query range. So disable the progress bar
            strHTML = strHTML + 'class="progressbar ui-progressbar ui-widget ui-widget-content ui-corner-all ui-progressbar-disabled ui-state-disabled">';
            strPerHTML = '<div class = "disablepercent">' + sData + '% (' + ConvertSize(nSize) + ')</div>';
        }
        strHTML = strHTML + '<div class="ui-progressbar-value ui-widget-header ui-corner-left" style="width:' + sData + '%;"></div></div>'
        strHTML = '<div>' + strHTML + strPerHTML + '</div>';
        elCell.innerHTML = strHTML;
    };
    
    YAHOO.widget.DataTable.Formatter.customProgressBar = formatProgressBar; //Assign column format with the custom progress bar format
	
    //The custom column format to the bytes column
    var formatBytes = function(elCell, oRecord, oColumn, sData)
    {
        elCell.innerHTML = ConvertSize(sData); //Convert the size to higher ranges and then show it to user
    };
    YAHOO.widget.DataTable.Formatter.customBytes = formatBytes; //Assign column format with the custom bytes format
    
    var dtColumnsDef = [{"key":"blockname", "label":"Block", "sortable":true, "resizeable":true, "width":300},
                        {"key":"blockfiles", "label":"Files", "sortable":true, "resizeable":true, "width":30},
                        {"key":"blockbytes", "label":"Size", "sortable":true, "resizeable":true, "width":70, "formatter":"customBytes"}
                        ];
    dtColumnsDef = Array.prototype.concat(dtColumnsDef, AddColumns(arrColumn));
    var dsCols = ["blockname", "blockfiles", "blockbytes"];
    //Traverse through the node list and add node columns to the datasource
    for (strColumnName in arrColumn)
    {
        dsCols.push(strColumnName);
    }

    //The function that is called after any of the columns is sorted
	//This is used to put the "Total" row always at top of the table
    var AfterSorting = function(oArgs)
    {
        var nRowIndx = dtResult.getRecordIndex(recordAllRow);
        dtResult.deleteRow(nRowIndx); 		    //Delete the Total row from its current position after sorting 
        dtResult.addRow(totalRow, 0); 		    //Add the Total row at top of the table
        recordAllRow = dtResult.getRecord(0); 	//Get the Total row object and store it for future use in this function.
    };
    
    try
    {
        dsBlocks = new YAHOO.util.LocalDataSource(data); //Create new datasource
        dsBlocks.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
        dsBlocks.responseSchema = {"fields":dsCols};
        
        if (nCount > 70) //Use Paginator as there are more blocks to display
        {
            var pagnDtResult = {paginator: new YAHOO.widget.Paginator({rowsPerPage: 50})}; //Paginator configuration to display large number of blocks
            dtResult = new YAHOO.widget.DataTable("Result", dtColumnsDef, dsBlocks, pagnDtResult); //Create new datatable using datasource and column definitions
        }
        else
        {
            dtResult = new YAHOO.widget.DataTable("Result", dtColumnsDef, dsBlocks); //Create new datatable using datasource and column definitions
        }
        dtResult.subscribe('columnSortEvent', AfterSorting);  //Assign the function to the event (after column gets sorted)
    }
    catch (ex)
    {
        alert("Error in adding data to the table");
        return;
    }
    
    if (dtResult.getRecordSet().getLength() > 0)
    {
        var nAllCurrentSize = 0, nValue = 0;
        var nAllBlockFiles = arrTotal["blockfiles"]; //Get the total block file count
        var nAllBlockBytes = arrTotal["blockbytes"]; //Get the total block size
        totalRow = {"blockname":"(All)","blockfiles":nAllBlockFiles,"blockbytes":nAllBlockBytes};
        for (strColumnName in arrColumn)
        {
            nValue = arrTotal[strColumnName]; //Get the node total info
            if (nValue)
            {
                nAllCurrentSize = nValue;
            }
            else
            {
                nAllCurrentSize = 0;
            }
            var percentcompleted = 100 * nAllCurrentSize/nAllBlockBytes; //Calculate the total data transfer percenatage for node
            if (IsDecimal(percentcompleted))
            {
                percentcompleted = percentcompleted.toFixed(2);
            }
            totalRow[strColumnName] = percentcompleted;
        }
        arrTotal = null;//Clear the arrTotal

        try
        {
            dtResult.addRow(totalRow, 0);
            recordAllRow = dtResult.getRecord(0);
        }
        catch(ex)
        {
            alert("Error in adding total row to the table");
        }
        if (ArrayLength(arrColumn) < ArrayLength(arrColumnNode)) //Node filter is on
        {
            //Now check if all visible blocks for the node columns have data transfer percentage range within query range 
            for (strColumnName in arrColumn)
            {
                bShow = ShowNode(strColumnName);
		        if (!bShow)
		        {
		            //Hide the column as the column has all blocks data transfer percentage range out of query range
			        HideColumn(strColumnName);
		        }
            }
        }
    }
    else
    {
        document.getElementById("Result").innerHTML = "";
        bFormTable = true;
    }
    if (ArrayLength(arrQueryBlkNames) > 0)
    {
        var strXmlMsg = GetMissingBlocks(); //Get the block names for which data service returned nothing and show to user
        document.getElementById("MissingBlks").innerHTML = strXmlMsg;
    }
    else
    {
        document.getElementById("MissingBlks").innerHTML = ""; //Clear the user message
    }
}

//*******************************************************************************************************
//Function:IsDecimal
//Purpose :This function checks if input number is decimal or not. Used to display numbers with precison
//*******************************************************************************************************
function IsDecimal(value)
{
    return regexpDot.test(value); 
}

//******************************************************************************************************
//Function:ConvertSize
//Purpose :This function converts the size of the blocks in bytes to that of higher order
//******************************************************************************************************
function ConvertSize(value)
{
    var strvalue = '';
    if (value == 0)
    {
        strvalue = '0 KB';
    }
    else if (value > 1099511627776) //Data size can be converted to TB
    {
        value = value/1099511627776; //Data size is converted to TB
        value = value.toFixed(2);
        strvalue = value + ' TB';
    }
    else if (value > 1073741824) //Data size can be converted to GB
    {
        value = value/1073741824; //Data size is converted to GB
        value = value.toFixed(2);
        strvalue = value + ' GB';
    }
    else if(value > 1048576) //Data size can be converted to MB
    {
        value = value/1048576; //Data size is converted to MB
        value = value.toFixed(2);
        strvalue = value + ' MB';
    }
    else if(value > 1024) //Data size can be converted to KB
    {
        value = value/1024; //Data size is converted to KB
        value = value.toFixed(2);
        strvalue = value + ' KB';
    }
    else
    {
        value = value.toFixed(2);
        strvalue = value + ' Bytes';
    }
    return strvalue;
}

//******************************************************************************************************
//Function:IsNumeric
//Purpose :This function checks if the input is numeric or not.
//******************************************************************************************************
function IsNumeric(value)
{
   return (value - 0) == value;
}

//******************************************************************************************************
//Function:QueryBlockExists
//Purpose :This function checks if the query block name is there in the result obtained from API or not.
//******************************************************************************************************
function QueryBlockExists(blockname)
{
    try
    {
        if (ArrayLength(arrQueryBlkNames) == 0)
        {
            return;
        }
        var indx = 0, wildcharindx = 0;
        var queryblkname = "", strName = "";
        blockname = blockname.toLowerCase();
        //Traverse the set and check if the block is there or not
        for (strName in arrQueryBlkNames)
        {
            queryblkname = strName.toLowerCase();
            wildcharindx = queryblkname.indexOf("*"); //If the input has wild character
            if (wildcharindx > -1)
            {
                queryblkname = queryblkname.substring(0, wildcharindx);
                if (blockname.startsWith(queryblkname)) 
                {
                    delete arrQueryBlkNames[strName];
                    break;
                }
            }
            else if (blockname == queryblkname)
            {
                delete arrQueryBlkNames[strName]; //Remove the blockname from the set as it is there in the result
                break;
            }
        }
    }
    catch(ex)
    {
    }
}

//******************************************************************************************************
//Function:GetMissingBlocks
//Purpose :This function generates the html element to show the missing blocks for which data service
//         didn't return any info.
//******************************************************************************************************
function GetMissingBlocks()
{
    var strName = "", indx = 1;
    var strXmlMsg = 'The query result for the following block(s) is none because [block name is wrong]\\[block data transfer percentage ';
    strXmlMsg = strXmlMsg + "is out of the input range]\\[any of the node names is wrong].<br/>";
    for (strName in arrQueryBlkNames)
    {
        strXmlMsg = strXmlMsg  + indx + ". " + strName + "<br/>";
        indx++;
    }
    return strXmlMsg;
}

//******************************************************************************************************
//Function:startsWith
//Purpose :This is the prototype for the string startswith function. This check if the string starts  
//         with the given argument.
//******************************************************************************************************
String.prototype.startsWith = function(str)
{
    return (this.match("^"+str)==str);
}

//******************************************************************************************************
//Function:trim
//Purpose :This is the prototype for the string trim function. This function removes the whitespaces from   
//         both ends of the given argument string.
//******************************************************************************************************
String.prototype.trim = function()
{
    return (this.replace(/^\s+|\s+$/g,""));
}