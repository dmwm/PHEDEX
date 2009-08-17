//=================================================================================================
//File Name  : phedex-widget-datalookup.js
//Purpose    : The javascript functions for creating data lookup widget that is used to get block 
//             information from Phedex database using web APIs provided by Phedex and then format 
//             result to show it to user in an YUI datatable.
//=================================================================================================
PHEDEX.namespace('Widget.DataLookup');

//****************************************************************************************************
//Function:PHEDEX.Widget.DataLookup
//Purpose :This initializes the data look up widget i.e variables, form controls 
//****************************************************************************************************
PHEDEX.Widget.DataLookup = function(divWidget,optsWidget) 
{
    var wgtDataLookUp =new PHEDEX.Core.Widget(divWidget,optsWidget); //Create new data lookup widget

    wgtDataLookUp.totalRow = {};            //The first row JSON object that has the values
    wgtDataLookUp.lowpercent=0;             //The lower percentage range of the data transfer
    wgtDataLookUp.highpercent=100;          //The higher percentage range of the data transfer
    wgtDataLookUp.nPgBarIndex = 0;          //The unique ID for the progress bar
    wgtDataLookUp.nOrigLowPercent = 0;      //The original low percent to avoid re-formatting the result
    wgtDataLookUp.nOrigHighPercent = 0;     //The original max percent to avoid re-formatting the result
    wgtDataLookUp.strOrigBlkQuery = "";     //The original input block names of the query to avoid re-formatting the result
    wgtDataLookUp.strOrigNodeQuery = "";    //The original input node names of the query to avoid re-formatting the result
    wgtDataLookUp.bFormTable = false;       //The boolean indicated if table has to be formed again or not
    wgtDataLookUp.recordAllRow = null;      //The first row (Total row) object of the datatable
    wgtDataLookUp.regexpDot = null;         //The Regular expression object
    wgtDataLookUp.arrBlocks = null;         //The associative array stores all the blocks
    wgtDataLookUp.sliderRange = null;       //The object of the slider for percentage range of the data transfer
    wgtDataLookUp.arrColumns = null;        //The map that stores current column names
    wgtDataLookUp.arrColumnNode = null;     //The map that stores all the node (column) names
    wgtDataLookUp.dialogUserMsg = null;     //The object of the dialog that is used to show user message
    wgtDataLookUp.arrQueryBlkNames = null;  //The input query block names

    wgtDataLookUp.dom.content.divInput = document.createElement('div');
    wgtDataLookUp.dom.content.divInput.style.backgroundColor = 'white';
    wgtDataLookUp.dom.content.appendChild(wgtDataLookUp.dom.content.divInput);
    
    //****************************************************************************************************
    //Function:ClearResult
    //Purpose :This function resets the "Result" elements in the web page for new search
    //****************************************************************************************************
    wgtDataLookUp.ClearResult = function()
    {
        wgtDataLookUp.dom.content.divResult.innerHTML = "";      //Reset the result element
        wgtDataLookUp.dom.content.divMissingBlks.innerHTML = ""; //Reset the missing blocks element
    }
    
    //****************************************************************************************************
    //Function:ConvertSliderVal
    //Purpose :This gets the actual data transfer percentage value from the slider range value which is 
    //         in pixels.
    //****************************************************************************************************
    wgtDataLookUp.ConvertSliderVal = function (value)
    {
        var temp = 100/(200 - 20);
        return Math.round(value * temp); //Convert the min and max values of slider into percentage range
    }

    //****************************************************************************************************
    //Function:InitializeValues - Reset
    //Purpose :This function resets all elements in the web page for new search
    //****************************************************************************************************
    wgtDataLookUp.InitializeValues = function()
    {
        wgtDataLookUp.ClearResult();
        wgtDataLookUp.nOrigLowPercent = 0;    //Reset the original low percent
        wgtDataLookUp.nOrigHighPercent = 0;   //Reset the original high percent
        wgtDataLookUp.strOrigBlkQuery = "";   //Reset the original block name query
        wgtDataLookUp.strOrigNodeQuery = "";  //Reset the original node filter query
        wgtDataLookUp.sliderRange.setValues(0,200);               //Reset the values of the percentage range in pixels
        wgtDataLookUp.dom.content.divInput.txtboxBlk.value = "";  //Reset the block name text box
        wgtDataLookUp.dom.content.divInput.txtboxNode.value = ""; //Reset the node name text box
        wgtDataLookUp.dom.content.divInput.txtRange.innerHTML = wgtDataLookUp.ConvertSliderVal(wgtDataLookUp.sliderRange.minVal) + " - " + wgtDataLookUp.ConvertSliderVal(wgtDataLookUp.sliderRange.maxVal-20) + " %";
    }

    //****************************************************************************************************
    //Function:UpdateRange
    //Purpose :This updates the data transfer percentage range values as user moves the slider.
    //****************************************************************************************************
    wgtDataLookUp.UpdateRange = function()
    {
        //Set the values of the percentage range
        wgtDataLookUp.dom.content.divInput.txtRange.innerHTML = wgtDataLookUp.ConvertSliderVal(wgtDataLookUp.sliderRange.minVal) + " - " + wgtDataLookUp.ConvertSliderVal(wgtDataLookUp.sliderRange.maxVal-20) + " %"; 
    }
    
    //****************************************************************************************************
    //Function:NewNode
    //Purpose :This function creates and returns node object that stores the node information (name,
    //         current size that has been transferred so far and percent of transfer completed)
    //****************************************************************************************************
    wgtDataLookUp.NewNode = function(name, currentsize, completepercent)
    {
        var objNode = new Object(); //create new node object
        objNode.NodeName = name;
        objNode.CurrentSize = currentsize;
        objNode.CompletePercent = completepercent;
        return objNode; //return the node object
    }

    //****************************************************************************************************
    //Function:AddBlockNode
    //Purpose :The associative array the block name as key and block info ( block name, size, file count,   
    //         list of nodes) as its value. This function adds node info to the associative array for  
    //         the input block name.
    //****************************************************************************************************
    wgtDataLookUp.AddBlockNode = function(strBlockName, nTotalSize, nTotalFiles, objNode)
    {
        var arrNodes = null;
        var objBlock = wgtDataLookUp.arrBlocks[strBlockName];
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
            wgtDataLookUp.arrBlocks[strBlockName] = objBlock;
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
    
    //*******************************************************************************************************
    //Function:GetDataInfo
    //Purpose :This function gets the block information from Phedex database using web APIs provided by 
    //         Phedex. First, the input is checked if it is valid or not. If input is invalid, user is
    //         alerted with a message. The communication with web API is done using Yahoo User Interface
    //         (YUI) library API - connection manager: makes connection using browser specific protocol.
    //         The result is obtained in JSON (Javascript Object Notation) format. Again, YUI library API
    //         is used to parse the json response and use it for formatting. Finally, result is formatted
    //         and is shown to user in YUI datatable.
    //*******************************************************************************************************
    wgtDataLookUp.GetDataInfo = function()
    {
        //debugger; //For debugging purpose
        var strDataInput = wgtDataLookUp.dom.content.divInput.txtboxBlk.value;
        strDataInput = strDataInput.trim(); //Remove the whitespaces from the ends of the string
        if (!strDataInput)
        {
            wgtDataLookUp.dialogUserMsg.cfg.setProperty("text","Please enter the query block name(s)."); //Alert user if input is missing
            wgtDataLookUp.dialogUserMsg.show();
            wgtDataLookUp.ClearResult();
            return;
        }
        wgtDataLookUp.lowpercent = wgtDataLookUp.ConvertSliderVal(wgtDataLookUp.sliderRange.minVal);
        wgtDataLookUp.highpercent = wgtDataLookUp.ConvertSliderVal(wgtDataLookUp.sliderRange.maxVal - 20);

        wgtDataLookUp.dom.content.divInput.btnGetInfo.disabled = true; //Disable the Get Info button
        wgtDataLookUp.dom.content.divInput.btnReset.disabled = true;   //Disable the Reset button
        
        strDataInput = strDataInput.replace(/\n/g, " ");
        var blocknames = strDataInput.split(/\s+/); //Split the blocks names using the delimiter whitespace (" ")
        var indx = 0;
        wgtDataLookUp.arrQueryBlkNames = new Array();
        for (indx = 0; indx < blocknames.length; indx++)
        {
            blocknames[indx] = blocknames[indx].trim(); //Remove the whitespaces in the blocknames
            wgtDataLookUp.InsertData(wgtDataLookUp.arrQueryBlkNames,blocknames[indx],"");
        }
        var strNodeInput = wgtDataLookUp.dom.content.divInput.txtboxNode.value;
        if (wgtDataLookUp.strOrigBlkQuery == strDataInput) //Check if current query block names and previous query block names are same or not
        {
            //No change in the input query. So, no need make data service call
            if (!(wgtDataLookUp.strOrigNodeQuery == strNodeInput))
            {
                wgtDataLookUp.arrColumns = wgtDataLookUp.FilterNodes(); //Filter the nodes as entered by user
                wgtDataLookUp.dom.content.divMissingBlks.innerHTML = "Please wait... the query is being processed..."; //Show user the status message
                wgtDataLookUp.FormatResult(wgtDataLookUp.arrColumns); //Do UI updates - show the block info to user in YUI datatable.
            }
            else if (!((wgtDataLookUp.nOrigHighPercent == wgtDataLookUp.highpercent) && (wgtDataLookUp.nOrigLowPercent == wgtDataLookUp.lowpercent))) //Check if there is any change in the percentage range
            {
                wgtDataLookUp.dom.content.divMissingBlks.innerHTML = "Please wait... the query is being processed..."; //Show user the status message
                wgtDataLookUp.FormatResult(wgtDataLookUp.arrColumns); //Do UI updates - show the block info to user in YUI datatable.
                wgtDataLookUp.nOrigLowPercent = wgtDataLookUp.lowpercent;
                wgtDataLookUp.nOrigHighPercent = wgtDataLookUp.highpercent;
            }
            wgtDataLookUp.strOrigNodeQuery = strNodeInput;
            wgtDataLookUp.dom.content.divInput.btnGetInfo.disabled = false; //Enable the Get Info button
            wgtDataLookUp.dom.content.divInput.btnReset.disabled = false;   //Enable the Reset button
            return; 
        }
        
        wgtDataLookUp.dom.content.divResult.innerHTML = "";
        wgtDataLookUp.dom.content.divMissingBlks.innerHTML = "Please wait... the query is being processed..."; //Show user the status message
        //Store the value for future use to check if value has changed or not and then format the result
        wgtDataLookUp.nOrigLowPercent = wgtDataLookUp.lowpercent; 
        wgtDataLookUp.nOrigHighPercent = wgtDataLookUp.highpercent;
        wgtDataLookUp.strOrigBlkQuery = strDataInput;
        wgtDataLookUp.strOrigNodeQuery = strNodeInput;
        
        //Callback function used by YUI connection manager on completing the connection request with web API
        wgtDataLookUp.funcSuccess = function(jsonBlkData)
        {
            try 
            {
                var blk = null, replica = null;
                var indxBlock = 0, indxReplica = 0, indxNode = 0;
                var blockbytes = 0, blockcount = 0, blockfiles = 0, replicabytes = 0, replicacount = 0;
                if (wgtDataLookUp.arrBlocks)
                {
                    wgtDataLookUp.arrBlocks = null;
                }
                wgtDataLookUp.arrBlocks = new Array(); //Create new associative array to store all the block info
                
                if (wgtDataLookUp.arrColumnNode)
                {
                    wgtDataLookUp.arrColumnNode = null;
                }
                wgtDataLookUp.arrColumnNode = new Array(); //Create new associative array to store all the node names
                
                blockcount = jsonBlkData.block.length; //Get the block count from json response
                //Traverse through the blocks in json response to get block information
                for (indxBlock = 0; indxBlock < blockcount; indxBlock++)
                {
                    blk = null;
                    blk = jsonBlkData.block[indxBlock]; //Get the block object from the json response
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
                                if (wgtDataLookUp.IsDecimal(percentcompleted))
                                {
                                    percentcompleted = percentcompleted.toFixed(2); //Round off the percentage to 2 decimal digits
                                }
                                var objNode = wgtDataLookUp.NewNode(replica.node, replicabytes, percentcompleted); //Create new node object to add to hash table
                                wgtDataLookUp.AddBlockNode(blk.name, blockbytes, blockfiles, objNode);  //Add the block and its new node info to the hash map
                                wgtDataLookUp.InsertData(wgtDataLookUp.arrColumnNode,replica.node,"");  //Add the node name to the hash map
                            }
                        }
                    }
                }
                
                if (blockcount == 0) // Check if there is any block information to show to user
                {
                    //No blocks are found for the given input
                    if (wgtDataLookUp.ArrayLength(wgtDataLookUp.arrQueryBlkNames) > 0)
                    {
                        var strXmlMsg = wgtDataLookUp.GetMissingBlocks(); //Get the block names for which data service returned nothing and show to user
                        wgtDataLookUp.dom.content.divResult.innerHTML = ""; //Reset the result
                        wgtDataLookUp.dom.content.divMissingBlks.innerHTML = strXmlMsg; //Show the result to user
                    }
                }
                else
                {
                    //Do UI updates - show the block info to user
                    wgtDataLookUp.arrColumns = wgtDataLookUp.FilterNodes(); //Filter the results using the node filter
                    if (wgtDataLookUp.ArrayLength(wgtDataLookUp.arrColumns) > 0)
                    {
                        wgtDataLookUp.FormatResult(wgtDataLookUp.arrColumns);
                    }
                    else
                    {
                        wgtDataLookUp.bFormTable = true;
                        var strXmlMsg = wgtDataLookUp.GetMissingBlocks(); //Get the block names for which data service returned nothing and show to user
                        wgtDataLookUp.dom.content.divMissingBlks.innerHTML = strXmlMsg;
                    }
                }
            }
            catch (e)
            {
                alert("Error in processing the received response. Please check the input.");
                wgtDataLookUp.ClearResult();
                wgtDataLookUp.bFormTable = true;
            }
            wgtDataLookUp.dom.content.divInput.btnGetInfo.disabled = false; //Enable the Get Info button
            wgtDataLookUp.dom.content.divInput.btnReset.disabled = false;   //Enable the Reset button
            return;
        }
        
        //If YUI connection manager fails communicating with web API, then this callback function is called
        wgtDataLookUp.funcFailure = function(objError)
        {
            alert("Error in communicating with Phedex and receiving the response. " + objError.message);
            wgtDataLookUp.ClearResult(); //Clear the result elements
            wgtDataLookUp.bFormTable = true;
            wgtDataLookUp.dom.content.divInput.btnGetInfo.disabled = false; //Enable the Get Info button
            wgtDataLookUp.dom.content.divInput.btnReset.disabled = false;   //Enable the Reset button
            return;
        }

        wgtDataLookUp.eventSuccess = new YAHOO.util.CustomEvent("event success");
        wgtDataLookUp.eventFailure = new YAHOO.util.CustomEvent("event failure");

        wgtDataLookUp.eventSuccess.subscribe(function(type,args) { wgtDataLookUp.funcSuccess(args[0]); });
        wgtDataLookUp.eventFailure.subscribe(function(type,args) { wgtDataLookUp.funcFailure(args[0]); });
        
        PHEDEX.Datasvc.Call({ api: 'blockreplicas', args:{block:blocknames}, success_event: wgtDataLookUp.eventSuccess, failure_event: wgtDataLookUp.eventFailure});
    }

    //****************************************************************************************************
    //Function:BuildWidget
    //Purpose :This builds the widget by adding the required form controls for input.
    //****************************************************************************************************
    wgtDataLookUp.BuildWidget = function(domWidgetInput)
    {
        var TxtBoxBlk = document.createElement('textarea');
        TxtBoxBlk.className = 'txtboxBlkNode';
        TxtBoxBlk.rows = 4;
        TxtBoxBlk.cols = 40;
        
        var TxtBoxNode = document.createElement('textarea');
        TxtBoxNode.className = 'txtboxBlkNode';
        TxtBoxNode.rows = 4;
        TxtBoxNode.cols = 40;
        
        var tableInput = document.createElement('table');
        tableInput.border = 0;
        tableInput.cellspacing = 3;
        tableInput.cellpadding = 3;
        var tableRow = tableInput.insertRow(0);
        
        var tableCell1 = tableRow.insertCell(0);
        var tableCell2 = tableRow.insertCell(1);
        tableCell1.innerHTML = '<div class="sometext">Enter data block(s) name (separated by whitespace):</div>';
        tableCell1.appendChild(TxtBoxBlk);
        tableCell2.innerHTML = '<div class="sometext">Enter node(s) name (separated by whitespace):</div>';
        tableCell2.appendChild(TxtBoxNode);
        
        domWidgetInput.txtboxBlk = TxtBoxBlk;
        domWidgetInput.txtboxNode = TxtBoxNode;
        domWidgetInput.appendChild(tableInput);
        
        var tableSlider = document.createElement('table');
        tableSlider.border = 0;
        tableSlider.cellspacing = 3;
        tableSlider.className = 'yui-skin-sam';
        tableRow = tableSlider.insertRow(0);
        
        tableCell1 = tableRow.insertCell(0);
        tableCell2 = tableRow.insertCell(1);
        var tableCell3 = tableRow.insertCell(2);
        
        tableCell1.innerHTML = '<span class="sometext">Select data transfer percentage range:</span>&nbsp;&nbsp;';
        var divSliderRange = document.createElement('div');
        divSliderRange.className = 'yui-h-slider';
        divSliderRange.title = 'Move the slider to select the range';
        
        var divSliderLower = document.createElement('div');
        divSliderLower.className = 'yui-slider-thumb';
        divSliderLower.innerHTML = '<img src="/images/left-thumb.png"/>';
        var divSliderHigher = document.createElement('div');
        divSliderHigher.className = 'yui-slider-thumb';
        divSliderHigher.innerHTML = '<img src="/images/right-thumb.png"/>';
        divSliderRange.appendChild(divSliderLower);
        divSliderRange.appendChild(divSliderHigher);
        tableCell2.appendChild(divSliderRange);
        
        domWidgetInput.divSliderRange = divSliderRange;
        domWidgetInput.divSliderLower = divSliderLower;
        domWidgetInput.divSliderHigher = divSliderHigher;
        
        var TxtRange = document.createElement('span');
        TxtRange.className = 'sometext';
        TxtRange.innerHTML = '0 - 100';
        tableCell3.appendChild(TxtRange);
        domWidgetInput.txtRange = TxtRange;
        domWidgetInput.appendChild(tableSlider);
        
        var range = 200;          // The range of slider in pixels
        var tickSize = 0;         // This is the pixels count by which the slider moves in fixed pixel increments
        var minThumbDistance = 0; // The minimum distance the thumbs can be from one another
        var initValues = [0,200]; // Initial values for the Slider in pixels
        
        // Create the Yahoo! DualSlider
        wgtDataLookUp.sliderRange = YAHOO.widget.Slider.getHorizDualSlider(divSliderRange, divSliderLower, divSliderHigher, range, tickSize, initValues);
        wgtDataLookUp.sliderRange.minRange = minThumbDistance;
        wgtDataLookUp.sliderRange.subscribe('ready', wgtDataLookUp.UpdateRange);  //Adding the function to ready event
        wgtDataLookUp.sliderRange.subscribe('change', wgtDataLookUp.UpdateRange); //Adding the function to change event
        domWidgetInput.appendChild(tableSlider);
        
        var btnGetInfo = document.createElement('span');
        var btnReset = document.createElement('span');
        btnGetInfo.className = 'yui-skin-sam';
        btnReset.className = 'yui-skin-sam';
        domWidgetInput.btnGetInfo = btnGetInfo;
        domWidgetInput.btnReset = btnReset;
        domWidgetInput.appendChild(btnGetInfo);
        domWidgetInput.appendChild(btnReset);
        
        // Create Yahoo! Buttons
        var objPushBtnGet = new YAHOO.widget.Button({ label:"Get Block Data Info", id:"datalookup-btnGetInfo", container:btnGetInfo, onclick: { fn: wgtDataLookUp.GetDataInfo } });
        var objPushBtnReset = new YAHOO.widget.Button({ label:"Reset", id:"datalookup-btnReset", container:btnReset, onclick: { fn: wgtDataLookUp.InitializeValues } });
    }

    wgtDataLookUp.BuildWidget(wgtDataLookUp.dom.content.divInput);

    wgtDataLookUp.dom.content.divResult = document.createElement('div');
    wgtDataLookUp.dom.content.appendChild(wgtDataLookUp.dom.content.divResult);
    wgtDataLookUp.dom.content.divMissingBlks = document.createElement('div');
    wgtDataLookUp.dom.content.divMissingBlks.className = 'sometext';
    wgtDataLookUp.dom.content.appendChild(wgtDataLookUp.dom.content.divMissingBlks);
    wgtDataLookUp.dom.param.appendChild(document.createTextNode('Phedex Data Lookup'));
    wgtDataLookUp.build();
    var cntrlInput = new PHEDEX.Core.Control({text:'Show\\Hide Data Lookup Input', payload:{render:wgtDataLookUp.dom.title, target:wgtDataLookUp.dom.content.divInput} } );
    cntrlInput.Show();

    var strDot = ".";
    wgtDataLookUp.regexpDot = new RegExp(strDot);

    wgtDataLookUp.InitializeValues();
	
    wgtDataLookUp.handleOK = function() 
    {
	    this.hide(); //Hide the messagebox after user clicks OK
    };
    // Create the message box dialog
    wgtDataLookUp.dialogUserMsg = new YAHOO.widget.SimpleDialog("dialogUserMsg", { width: "400px",
                                                                     height: "100px",
                                                                     fixedcenter: true,
                                                                     visible: false,
                                                                     draggable: false,
                                                                     close: true,
                                                                     text: "Phedex Data Lookup message box",
                                                                     icon: YAHOO.widget.SimpleDialog.ICON_WARN,
                                                                     constraintoviewport: true,
                                                                     buttons: [ { text:"OK", handler:wgtDataLookUp.handleOK, isDefault:true}]
                                                                     });
    wgtDataLookUp.dialogUserMsg.setHeader("Phedex Data Lookup"); //Set the header of the message box
    wgtDataLookUp.dialogUserMsg.render(wgtDataLookUp.dom.content);
    wgtDataLookUp.finishLoading();

    //****************************************************************************************************
    //Function:UpdateTotalRow
    //Purpose :This adds\updates "Total Row" values in associative array i.e total values of all columns.
    //****************************************************************************************************
    wgtDataLookUp.UpdateTotalRow = function(arrTotal, strColumnName, nValue)
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
    wgtDataLookUp.ShowNode = function(strColumnName)
    {
        var nTransferPercent = 0, indx = 0, nLength = 0;
        var recsetNode = wgtDataLookUp.dataTable.getRecordSet(); //Get the values of the column
        nLength = recsetNode.getLength();
        for (indx = 1; indx < nLength; indx++)
        {
            var recBlock = recsetNode.getRecord(indx);
            nTransferPercent = recBlock.getData(strColumnName);
            if ((nTransferPercent >= wgtDataLookUp.lowpercent) && (nTransferPercent <= wgtDataLookUp.highpercent)) //Check if percentage is within query range
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
    wgtDataLookUp.GetQueryColumns = function(strQuery)
    {
        var bShow = false, strColumnName = "";
        var arrQueryCols = new Array(); //Create new associative array to store node column names
        for (strColumnName in wgtDataLookUp.arrColumnNode)
        {
            var regexpNodes = new RegExp(strQuery);       //Form the regular expression object
            var bExist = regexpNodes.test(strColumnName); //Check if this node matched with the given expression of input node filter
            if (bExist)
            {
                //Show the node column
                wgtDataLookUp.InsertData(arrQueryCols, strColumnName, "");
            }
        }
        return arrQueryCols; //Return the set that has the column names for the input node filter expression
    }

    //*****************************************************************************************************
    //Function:FilterNodes
    //Purpose :This filters the result based on the input node filter. Only nodes matching the filter 
    //         (separate expressions are ANDed) will be shown as columns in the table.
    //*****************************************************************************************************
    wgtDataLookUp.FilterNodes = function()
    {
        var indx = 0;
        var strColumnName = "", strName = "";
        var strNodeNames = wgtDataLookUp.dom.content.divInput.txtboxNode.value; //Get the node filter
        strNodeNames = strNodeNames.trim(); //Remove the whitespaces from the ends of the string
        if (strNodeNames.length == 0) //If node query box is empty, then show all columns
        {
            return wgtDataLookUp.arrColumnNode;
        }
        
        strNodeNames = strNodeNames.replace(/\n/g, " ");
        var arrNodeNames = strNodeNames.split(/\s+/); //Split the blocks names using the delimiter whitespace (" ")
        var arrQueryNodes = new Array();
        for (indx = 0; indx < arrNodeNames.length; indx++)
        {
            strName = arrNodeNames[indx].trim(); //Remove the whitespaces in the blocknames
            wgtDataLookUp.InsertData(arrQueryNodes, strName, "");
        }
        
        var nLoop = 0;
        var arrNodeCols = null, arrQueryCols = null;
        var arrTemp = new Array();
        for (strName in arrQueryNodes)
        {
            arrQueryCols = wgtDataLookUp.GetQueryColumns(strName); //Get the list of nodes that match with the given separate expression of the node filter 
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
			            wgtDataLookUp.InsertData(arrTemp, strColumnName,""); //Add if both sets have same item
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
    wgtDataLookUp.HideColumn = function(strColumnName)
    {
        var objColumn = wgtDataLookUp.dataTable.getColumn(strColumnName); //Get the column object
        if (objColumn)
        {
            wgtDataLookUp.dataTable.hideColumn(objColumn); //Hide the column
        }
    }

    //****************************************************************************************************
    //Function:ShowColumn
    //Purpose :This shows the column in the datatable
    //****************************************************************************************************
    wgtDataLookUp.ShowColumn = function(strColumnName)
    {
        var objColumn = wgtDataLookUp.dataTable.getColumn(strColumnName); //Get the column object
        if (objColumn)
        {
            wgtDataLookUp.dataTable.showColumn(objColumn); //Show the column
        }
    }
     
    //****************************************************************************************************
    //Function:ShowBlock
    //Purpose :This checks if the block row has to be shown in the datatable or not by checking the data
    //		   transfer percentage of all block nodes
    //****************************************************************************************************
    wgtDataLookUp.ShowBlock = function(objBlock, arrColumn)
    {
        var strColumnName = "";
        var jsonNode = null, objNode = null;
        var nTransferPercent = 0, nNodeCount = 0;
        var arrBlkNodes = objBlock.Nodes;
        if (arrBlkNodes)
        {
            nNodeCount = wgtDataLookUp.ArrayLength(arrBlkNodes);
            if (nNodeCount < wgtDataLookUp.ArrayLength(wgtDataLookUp.arrColumnNode))
            {
                objBlock.MinPercent = 0;
            }
            if (!((wgtDataLookUp.highpercent < objBlock.MinPercent) || (objBlock.MaxPercent < wgtDataLookUp.lowpercent)))
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
                    if ((nTransferPercent >= wgtDataLookUp.lowpercent) && (nTransferPercent <= wgtDataLookUp.highpercent)) //Check if percentage is within query range
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
    //Purpose :This function takes associative array that has block and block info. This information is 
    //         formatted to get the actual result in YUI datatable to display to user on browser. jQuery UI 
    //         progress bar is used to display the data transfer percentage.
    //*****************************************************************************************************
    wgtDataLookUp.FormatResult = function(arrColumn)
    {
        var data = [];
        var bShow = false;
        var strBlockName = "", strColumnName = "";
        var nCurrentSize = 0, nTransferPercent = 0, nCount = 0;
        var objArr =null, objBlock = null, objNode = null, arrBlkNodes = null;
        var arrTotal = new Array(); //Create new associate array to store all the total row
        
        wgtDataLookUp.nPgBarIndex = 0; //Reset the ID of the progress bar    
        for (objArr in wgtDataLookUp.arrBlocks)
        {
            objBlock = wgtDataLookUp.arrBlocks[objArr];
            if (objBlock == null)
            {
                continue;
            }
            bShow = wgtDataLookUp.ShowBlock(objBlock, arrColumn); //Check if the block can be shown to user
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
                        wgtDataLookUp.UpdateTotalRow(arrTotal, strColumnName, objNode.CurrentSize);
                    }
                    else
                    {
                        nTransferPercent = 0;
                    }
                    row[strColumnName] = nTransferPercent;
                }
                //This checks the result obtained from data serice, input block names and shows user if input is invalid
                wgtDataLookUp.QueryBlockExists(strBlockName);

                data.push(row);
                wgtDataLookUp.UpdateTotalRow(arrTotal, "blockfiles", objBlock.TotalFiles); //Update the values of Total Row for the datatable
                wgtDataLookUp.UpdateTotalRow(arrTotal, "blockbytes", objBlock.TotalSize);	//Update the values of Total Row for the datatable
            }
        }
        
        //The custom progress bar format to the node column
        var formatProgressBar = function(elCell, oRecord, oColumn, sData)
        {
            var nSize = oRecord.getData("blockbytes") * sData/100; //Calculate the current size of the block data transferred
            var strHTML = '<div><div id = "BlkProgressBar' + ++wgtDataLookUp.nPgBarIndex + '" role="progressbar" aria-valuemin="0" aria-valuemax=100" aria-valuenow="' + sData + '" ';
            var strPerHTML = '';
            if ((sData >= wgtDataLookUp.lowpercent) && (sData <= wgtDataLookUp.highpercent))  
            {
                //The percentage is within query range
                strHTML = strHTML + 'class="progressbar ui-progressbar ui-widget ui-widget-content ui-corner-all" aria-disabled="true">';
                strPerHTML = '<div class = "percent">' + sData + '% (' + wgtDataLookUp.ConvertSize(nSize) + ')</div>';
            }
            else
            {
                //The percentage is NOT within query range. So disable the progress bar
                strHTML = strHTML + 'class="progressbar ui-progressbar ui-widget ui-widget-content ui-corner-all ui-progressbar-disabled ui-state-disabled">';
                strPerHTML = '<div class = "disablepercent">' + sData + '% (' + wgtDataLookUp.ConvertSize(nSize) + ')</div>';
            }
            strHTML = strHTML + '<div class="ui-progressbar-value ui-widget-header ui-corner-left" style="width:' + sData + '%;"></div></div>'
            strHTML = '<div>' + strHTML + strPerHTML + '</div>';
            elCell.innerHTML = strHTML;
        };
        
        YAHOO.widget.DataTable.Formatter.customProgressBar = formatProgressBar; //Assign column format with the custom progress bar format
    	
        //The custom column format to the bytes column
        var formatBytes = function(elCell, oRecord, oColumn, sData)
        {
            elCell.innerHTML = wgtDataLookUp.ConvertSize(sData); //Convert the size to higher ranges and then show it to user
        };
        YAHOO.widget.DataTable.Formatter.customBytes = formatBytes; //Assign column format with the custom bytes format
        
        var dtColumnsDef = [{"key":"blockname", "label":"Block", "sortable":true, "resizeable":true, "width":300},
                            {"key":"blockfiles", "label":"Files", "sortable":true, "resizeable":true, "width":30},
                            {"key":"blockbytes", "label":"Size", "sortable":true, "resizeable":true, "width":70, "formatter":"customBytes"}
                            ];
        var dsCols = ["blockname", "blockfiles", "blockbytes"];
        //Traverse through the node list and add node columns to the datasource
        for (strColumnName in arrColumn)
        {
            dtColumnsDef.push({"key":strColumnName,"sortable":true,"formatter":"customProgressBar"});
            dsCols.push(strColumnName);
        }

        //The function that is called after any of the columns is sorted
	    //This is used to put the "Total" row always at top of the table
        var AfterSorting = function(oArgs)
        {
            var nRowIndx = wgtDataLookUp.dataTable.getRecordIndex(wgtDataLookUp.recordAllRow);
            wgtDataLookUp.dataTable.deleteRow(nRowIndx); 		    //Delete the Total row from its current position after sorting 
            wgtDataLookUp.dataTable.addRow(wgtDataLookUp.totalRow, 0); 		    //Add the Total row at top of the table
            wgtDataLookUp.recordAllRow = wgtDataLookUp.dataTable.getRecord(0); 	//Get the Total row object and store it for future use in this function.
        };
        
        try
        {
            if (wgtDataLookUp.dataTable)
            {
                wgtDataLookUp.dataTable.destroy();
                wgtDataLookUp.dataTable = null;
                wgtDataLookUp.dataSource = null;
            }
            wgtDataLookUp.dataSource = new YAHOO.util.LocalDataSource(data); //Create new datasource
            wgtDataLookUp.dataSource.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
            wgtDataLookUp.dataSource.responseSchema = {"fields":dsCols};
        
            if (nCount > 70) //Use Paginator as there are more blocks to display
            {
                var pagnDtResult = {paginator: new YAHOO.widget.Paginator({rowsPerPage: 50})}; //Paginator configuration to display large number of blocks
                wgtDataLookUp.dataTable = new YAHOO.widget.DataTable(wgtDataLookUp.dom.content.divResult, dtColumnsDef, wgtDataLookUp.dataSource, pagnDtResult); //Create new datatable using datasource and column definitions
            }
            else
            {
                wgtDataLookUp.dataTable = new YAHOO.widget.DataTable(wgtDataLookUp.dom.content.divResult, dtColumnsDef, wgtDataLookUp.dataSource); //Create new datatable using datasource and column definitions
            }	
            wgtDataLookUp.dataTable.subscribe('columnSortEvent', AfterSorting);  //Assign the function to the event (after column gets sorted)
        }
        catch (ex)
        {
            alert("Error in adding data to the table");
            return;
        }
        
        if (wgtDataLookUp.dataTable.getRecordSet().getLength() > 0)
        {
            var nAllCurrentSize = 0, nValue = 0;
            var nAllBlockFiles = arrTotal["blockfiles"]; //Get the total block file count
            var nAllBlockBytes = arrTotal["blockbytes"]; //Get the total block size
            wgtDataLookUp.totalRow = {"blockname":"(All)","blockfiles":nAllBlockFiles,"blockbytes":nAllBlockBytes};
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
                if (wgtDataLookUp.IsDecimal(percentcompleted))
                {
                    percentcompleted = percentcompleted.toFixed(2);
                }
                wgtDataLookUp.totalRow[strColumnName] = percentcompleted;
            }
            arrTotal = null;//Clear the arrTotal

            try
            {
                wgtDataLookUp.dataTable.addRow(wgtDataLookUp.totalRow, 0);
                wgtDataLookUp.recordAllRow = wgtDataLookUp.dataTable.getRecord(0);
            }
            catch(ex)
            {
                alert("Error in adding total row to the table");
            }
            if (wgtDataLookUp.ArrayLength(arrColumn) < wgtDataLookUp.ArrayLength(wgtDataLookUp.arrColumnNode)) //Node filter is on
            {
                //Now check if all visible blocks for the node columns have data transfer percentage range within query range 
                for (strColumnName in arrColumn)
                {
                    bShow = wgtDataLookUp.ShowNode(strColumnName);
		            if (!bShow)
		            {
		                //Hide the column as the column has all blocks data transfer percentage range out of query range
			            wgtDataLookUp.HideColumn(strColumnName);
		            }
                }
            }
        }
        else
        {
            wgtDataLookUp.dom.content.divResult.innerHTML = "";
            wgtDataLookUp.bFormTable = true;
        }
        if (wgtDataLookUp.ArrayLength(wgtDataLookUp.arrQueryBlkNames) > 0)
        {
            var strXmlMsg = wgtDataLookUp.GetMissingBlocks(); //Get the block names for which data service returned nothing and show to user
            wgtDataLookUp.dom.content.divMissingBlks.innerHTML = strXmlMsg;
        }
        else
        {
            wgtDataLookUp.dom.content.divMissingBlks.innerHTML = ""; //Clear the user message
        }
    }

    //******************************************************************************************************
    //Function:QueryBlockExists
    //Purpose :This function checks if the query block name is there in the result obtained from API or not.
    //******************************************************************************************************
    wgtDataLookUp.QueryBlockExists = function(blockname)
    {
        try
        {
            if (wgtDataLookUp.ArrayLength(wgtDataLookUp.arrQueryBlkNames) == 0)
            {
                return;
            }
            var indx = 0, wildcharindx = 0;
            var queryblkname = "", strName = "";
            blockname = blockname.toLowerCase();
            //Traverse the set and check if the block is there or not
            for (strName in wgtDataLookUp.arrQueryBlkNames)
            {
                queryblkname = strName.toLowerCase();
                wildcharindx = queryblkname.indexOf("*"); //If the input has wild character
                if (wildcharindx > -1)
                {
                    queryblkname = queryblkname.substring(0, wildcharindx);
                    if (blockname.startsWith(queryblkname)) 
                    {
                        delete wgtDataLookUp.arrQueryBlkNames[strName];
                        break;
                    }
                }
                else if (blockname == queryblkname)
                {
                    delete wgtDataLookUp.arrQueryBlkNames[strName]; //Remove the blockname from the set as it is there in the result
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
    wgtDataLookUp.GetMissingBlocks = function()
    {
        var strName = "", indx = 1;
        var strXmlMsg = 'The query result for the following block(s) is none because [block name is wrong]\\[block data transfer percentage ';
        strXmlMsg = strXmlMsg + "is out of the input range]\\[any of the node names is wrong].<br/>";
        for (strName in wgtDataLookUp.arrQueryBlkNames)
        {
            strXmlMsg = strXmlMsg  + indx + ". " + strName + "<br/>";
            indx++;
        }
        return strXmlMsg;
    }


    //****************************************************************************************************
    //Function:ArrayLength
    //Purpose :This gets the length of the associative array.
    //****************************************************************************************************
    wgtDataLookUp.ArrayLength = function(array)
    {
        var nLength = 0;
        for (var object in array)
        {
            nLength++;
        }
        return nLength;
    }

    //*******************************************************************************************************
    //Function:IsDecimal
    //Purpose :This function checks if input number is decimal or not. Used to display numbers with precison
    //*******************************************************************************************************
    wgtDataLookUp.IsDecimal = function(value)
    {
        return wgtDataLookUp.regexpDot.test(value); 
    }

    //******************************************************************************************************
    //Function:ConvertSize
    //Purpose :This function converts the size of the blocks in bytes to that of higher order
    //******************************************************************************************************
    wgtDataLookUp.ConvertSize = function(value)
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

    //****************************************************************************************************
    //Function:InsertData
    //Purpose :This inserts data to associative array if not present else leave it.
    //****************************************************************************************************
    wgtDataLookUp.InsertData = function(arrData, strKey, strVal)
    {
        var objVal = arrData[strKey]; //Get the value for the key
        if (objVal == null)
        {
            arrData[strKey] = strVal; //Add the value if key is not present
        }
    }
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
