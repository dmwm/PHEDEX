/**
* The class is used to create the block location module to view block information given the block name(s).
* The block information is obtained from Phedex database using web APIs provided by Phedex and is formatted to 
* show it to user in a YUI datatable.
* @namespace PHEDEX.Module
* @class BlockLocation
* @constructor
* @param sandbox {PHEDEX.Sandbox} reference to a PhEDEx sandbox object
* @param string {string} a string to use as the base-name of the <strong>Id</strong> for this module
*/
PHEDEX.namespace('Module');
PHEDEX.Module.BlockLocation = function(sandbox, string) {
    Yla(this, new PHEDEX.Module(sandbox, string));
    log('Module: creating a genuine "' + string + '"', 'info', string);

    var _sbx = sandbox,
        _strBlocksName = "",       //The block names input
        _strNodesName = "",        //The node name input
        _totalRow = {},            //The first row JSON object that has the values
        _nPgBarIndex = 0,          //The unique ID for the progress bar
        _lowpercent = 0,           //The lower percentage range of the data transfer
        _highpercent = 100,        //The higher percentage range of the data transfer
        _nOrigLowPercent = 0,      //The original low percent to avoid re-formatting the result
        _nOrigHighPercent = 0,     //The original max percent to avoid re-formatting the result
        _strOrigBlkQuery = "",     //The original input block names of the query to avoid re-formatting the result
        _strOrigNodeQuery = "",    //The original input node names of the query to avoid re-formatting the result
        _bFormTable = false,       //The boolean indicated if table has to be formed again or not
        _recordAllRow = null,      //The first row (Total row) object of the datatable
        _regexpDot = null,         //The Regular expression object
        _arrBlocks = null,         //The associative array stores all the blocks
        _sliderRange = null,       //The object of the slider for percentage range of the data transfer
        _arrColumns = null,        //The map that stores current column names
        _arrColumnNode = null,     //The map that stores all the node (column) names
        _arrQueryBlkNames = null,  //The input query block names
        _divInput, _divResult, _divMissingBlks, _dataTable; //The input, result, info HTML elements

    /**
    * This function resets the "Result" elements in the web page for new search.
    * @method _clearResult
    * @private
    */
    var _clearResult = function() {
        _divResult.innerHTML = "";      //Reset the result element
        _divMissingBlks.innerHTML = ""; //Reset the missing blocks element
        log('The result is cleared', 'info', this.me)
    }

    /**
    * This gets the actual data transfer percentage value from the slider range value which is in pixels.
    * @method _convertSliderVal
    * @param value {object} is actual slider value in pixels that has to be calibrated in range 0-100 %.
    * @private
    */
    var _convertSliderVal = function(value) {
        return Math.round(value * (100 / (200 - 20))); //Convert the min and max values of slider into percentage range
    }

    /**
    * This function resets all elements in the web page for new search.
    * @method _initializeValues
    * @private
    */
    var _initializeValues = function() {
        _clearResult();
        _nOrigLowPercent = 0;    //Reset the original low percent
        _nOrigHighPercent = 0;   //Reset the original high percent
        _strOrigBlkQuery = "";   //Reset the original block name query
        _strOrigNodeQuery = "";  //Reset the original node filter query
        _strBlocksName = "";     //Reset the query block names
        _strNodesName = "";      //Reset the query node names
        _sliderRange.setValues(0, 200);  //Reset the values of the percentage range in pixels
        _divInput.txtboxBlk.value = "";  //Reset the block name text box
        _divInput.txtboxNode.value = ""; //Reset the node name text box
        _divInput.txtRange.innerHTML = _convertSliderVal(_sliderRange.minVal) + " - " + _convertSliderVal(_sliderRange.maxVal - 20) + " %";
        log('The module is initialized', 'info', this.me)
    }

    /**
    * This updates the data transfer percentage range values as user moves the slider.
    * @method _updateRange
    * @private
    */
    var _updateRange = function() {
        _divInput.txtRange.innerHTML = _convertSliderVal(_sliderRange.minVal) + " - " + _convertSliderVal(_sliderRange.maxVal - 20) + " %";
        log('The slider value is updated', 'info', this.me)
    }

    /**
    * This function creates and returns node object that stores the node information (name, 
    * current size that has been transferred so far and percent of transfer completed).
    * @method _newNode
    * @param name {String} is node name.
    * @param currentsize {Integer} is current size that has been transferred to node.
    * @param completepercent {Integer} is percentage of block that has been transferred.
    * @private
    */
    var _newNode = function(name, currentsize, completepercent) {
        var objNode = new Object(); //create new node object
        objNode.NodeName = name;
        objNode.CurrentSize = currentsize;
        objNode.CompletePercent = completepercent;
        return objNode; //return the node object
    }

    /**
    * The associative array the block name as key and block info ( block name, size, file count, list of 
    * nodes) as its value. This function adds node info to the associative array for the input block name.
    * @method _addBlockNode
    * @param strBlockName {String} is block name.
    * @param nTotalSize {Integer} is actual size of block that has to be transferred to node.
    * @param nTotalFiles {Integer} is number of files in the block that has to be transferred.
    * @param objNode {Object} is object that has information of node .
    * @private
    */
    var _addBlockNode = function(strBlockName, nTotalSize, nTotalFiles, objNode) {
        var arrNodes = null, objBlock = _arrBlocks[strBlockName];
        if (objBlock == null) {
            objBlock = new Object(); //create new node object and assign the arguments to the properties of object
            objBlock.BlockName = strBlockName;
            objBlock.TotalSize = nTotalSize;
            objBlock.TotalFiles = nTotalFiles;
            objBlock.MinPercent = objNode.CompletePercent;
            objBlock.MaxPercent = objNode.CompletePercent;
            arrNodes = new Array();
            arrNodes[objNode.NodeName] = objNode;
            objBlock.Nodes = arrNodes;
            _arrBlocks[strBlockName] = objBlock;
        }
        else {
            arrNodes = objBlock.Nodes;
            arrNodes[objNode.NodeName] = objNode;
            if (objNode.CompletePercent > objBlock.MaxPercent) {
                objBlock.MaxPercent = objNode.CompletePercent; //Update the maximum percentage
            }
            else if (objNode.CompletePercent < objBlock.MinPercent) {
                objBlock.MinPercent = objNode.CompletePercent; //Update the minimum percentage
            }
        }
    }
    
    /**
    * This function gets the block information from Phedex database using web APIs provided by Phedex given 
    * the name of blocks and nodes in regular expression format.
    * The result is formatted and is shown to user in YUI datatable.
    * @method _getDataInfo
    * @private
    */
    var _getDataInfo = function() {
        var nLowPercent = _convertSliderVal(_sliderRange.minVal),
            nHighPercent = _convertSliderVal(_sliderRange.maxVal - 20),
            strNodeInput = _divInput.txtboxNode.value,
            strBlkInput = _divInput.txtboxBlk.value;
        if (!strBlkInput) {
            banner("Please enter the query block name(s).", 'warn'); //Inform user if input is missing
            _clearResult();
            return;
        }
        _sbx.notify('module', '*', 'doSetArgs', { "block": strBlkInput, "nodename": strNodeInput, "lowpercent": nLowPercent, "highpercent": nHighPercent });
    }

    /**
    * This builds the input component of the module by adding the required form controls for input.
    * @method _buildInput
    * @param domInput {HTML Element} is HTML element where the input component of the module is built.
    * @private
    */
    var _buildInput = function(domInput) {
        var TxtBoxBlk, TxtBoxNode, tableInput, tableRow, tableCell1, tableCell2, tableSlider, tableCell3, divSliderRange,
            divSliderLower, divSliderHigher, TxtRange, btnGetInfo, btnReset, objPushBtnGet, objPushBtnReset,
            range = 200,          // The range of slider in pixels
            tickSize = 0,         // This is the pixels count by which the slider moves in fixed pixel increments
            minThumbDistance = 0, // The minimum distance the thumbs can be from one another
            initValues = [0, 200]; // Initial values for the Slider in pixels

        TxtBoxBlk = document.createElement('textarea');
        TxtBoxBlk.className = 'txtboxBlkNode';
        TxtBoxBlk.rows = 4;
        TxtBoxBlk.cols = 40;

        TxtBoxNode = document.createElement('textarea');
        TxtBoxNode.className = 'txtboxBlkNode';
        TxtBoxNode.rows = 4;
        TxtBoxNode.cols = 40;
        TxtBoxNode.title = 'enter a whitespace-separated group of regular expressions. Separate expressions are ANDed, use "|" to OR terms in a single expression';

        tableInput = document.createElement('table');
        tableInput.border = 0;
        tableInput.cellspacing = 3;
        tableInput.cellpadding = 3;
        tableRow = tableInput.insertRow(0);

        tableCell1 = tableRow.insertCell(0);
        tableCell2 = tableRow.insertCell(1);
        tableCell1.innerHTML = '<div>Enter data block(s) name (separated by whitespace):</div>';
        tableCell1.appendChild(TxtBoxBlk);
        tableCell2.innerHTML = '<div>Enter node(s) name (separated by whitespace):</div>';
        tableCell2.appendChild(TxtBoxNode);

        domInput.txtboxBlk = TxtBoxBlk;
        domInput.txtboxNode = TxtBoxNode;
        domInput.appendChild(tableInput);

        tableSlider = document.createElement('table');
        tableSlider.border = 0;
        tableSlider.cellspacing = 3;
        tableSlider.className = 'yui-skin-sam';
        tableRow = tableSlider.insertRow(0);

        tableCell1 = tableRow.insertCell(0);
        tableCell2 = tableRow.insertCell(1);
        tableCell3 = tableRow.insertCell(2);

        tableCell1.innerHTML = '<span>Select data transfer percentage range:</span>&nbsp;&nbsp;';
        divSliderRange = document.createElement('div');
        divSliderRange.className = 'yui-h-slider';
        divSliderRange.title = 'Move the slider to select the range';

        divSliderLower = document.createElement('div');
        divSliderLower.className = 'yui-slider-thumb';
        divSliderLower.innerHTML = '<img src="/images/left-thumb.png"/>';
        divSliderHigher = document.createElement('div');
        divSliderHigher.className = 'yui-slider-thumb';
        divSliderHigher.innerHTML = '<img src="/images/right-thumb.png"/>';
        divSliderRange.appendChild(divSliderLower);
        divSliderRange.appendChild(divSliderHigher);
        tableCell2.appendChild(divSliderRange);

        domInput.divSliderRange = divSliderRange;
        domInput.divSliderLower = divSliderLower;
        domInput.divSliderHigher = divSliderHigher;

        TxtRange = document.createElement('span');
        TxtRange.innerHTML = '0 - 100';
        tableCell3.appendChild(TxtRange);
        domInput.txtRange = TxtRange;
        domInput.appendChild(tableSlider);

        // Create the Yahoo! DualSlider
        _sliderRange = Yw.Slider.getHorizDualSlider(divSliderRange, divSliderLower, divSliderHigher, range, tickSize, initValues);
        _sliderRange.minRange = minThumbDistance;
        _sliderRange.subscribe('ready', _updateRange);  //Adding the function to ready event
        _sliderRange.subscribe('change', _updateRange); //Adding the function to change event
        domInput.appendChild(tableSlider);

        btnGetInfo = document.createElement('span');
        btnReset = document.createElement('span');
        btnGetInfo.className = 'yui-skin-sam';
        btnReset.className = 'yui-skin-sam';
        domInput.btnGetInfo = btnGetInfo;
        domInput.btnReset = btnReset;
        domInput.appendChild(btnGetInfo);
        domInput.appendChild(btnReset);

        // Create Yahoo! Buttons
        objPushBtnGet = new Yw.Button({ label: "Get Block Data Info", id: "datalookup-btnGetInfo", container: btnGetInfo, onclick: { fn: _getDataInfo} });
        objPushBtnReset = new Yw.Button({ label: "Reset", id: "datalookup-btnReset", container: btnReset, onclick: { fn: _initializeValues} });
        log('The input component has been built', 'info', this.me)
    }

    /**
    * This builds the module by adding the required form controls for input and output.
    * @method _buildModule
    * @param domModule {HTML Element} is HTML element where the module has to be built.
    * @private
    */
    var _buildModule = function(domModule) {
        var strDot = ".", cntrlInput;
        _regexpDot = new RegExp(strDot);
        domModule.content.divInput = document.createElement('div');
        domModule.content.divInput.style.backgroundColor = 'white';
        _divInput = domModule.content.divInput;
        domModule.content.appendChild(_divInput);
        _buildInput(_divInput);

        domModule.content.divResult = document.createElement('div');
        _divResult = domModule.content.divResult;
        domModule.content.appendChild(_divResult);

        domModule.content.divMissingBlks = document.createElement('div');
        _divMissingBlks = domModule.content.divMissingBlks;
        domModule.content.appendChild(domModule.content.divMissingBlks);

        cntrlInput = new PHEDEX.Component.Control(PxS, {
            payload: {
                text: 'Show Input',
                title: 'This shows the input component.',
                target: _divInput,
                animate: true,
                className: 'float-right phedex-core-control-widget phedex-core-control-widget-inactive'
            }
        });

        domModule.title.appendChild(cntrlInput.el);
        cntrlInput.Show();
        _initializeValues();
        log('The module has been built completely', 'info', this.me)
    }

    /**
    * This adds\updates "Total Row" values in associative array i.e total values of all columns.
    * @method _updateTotalRow
    * @param arrTotal {Array} is associative array that has total of all column values.
    * @param strColumnName {String} is column name.
    * @param nValue {String} is column value.
    * @private
    */
    var _updateTotalRow = function(arrTotal, strColumnName, nValue) {
        var nVal = arrTotal[strColumnName]; //Get the value for the table column
        if (nVal) {
            arrTotal[strColumnName] = nVal + nValue; //Update the total value
        }
        else {
            arrTotal[strColumnName] = nValue //Add the total value 
        }
    }

    /**
    * This checks if the node column has to be shown in the datatable or not by checking the data transfer 
    * percentage of all blocks of that node
    * @method _showNode
    * @param strColumnName {String} is column name.
    * @private
    */
    var _showNode = function(strColumnName) {
        var nTransferPercent = 0, indx, recBlock,
        recsetNode = _dataTable.getRecordSet(), //Get the values of the column
        nLength = recsetNode.getLength();
        for (indx = 1; indx < nLength; indx++) {
            recBlock = recsetNode.getRecord(indx);
            nTransferPercent = recBlock.getData(strColumnName);
            if ((nTransferPercent >= _lowpercent) && (nTransferPercent <= _highpercent)) //Check if percentage is within query range
            {
                return true;  //Show this node to user
            }
        }
        return false; //Do not show this node to user
    }

    /**
    * This gets the list of nodes that match with the given separate expression of the node filter.
    * @method _getQueryColumns
    * @param strQuery {String} is regular expression query.
    * @private
    */
    var _getQueryColumns = function(strQuery) {
        var bShow = false, strColumnName = "", bExist, regexpNodes,
        arrQueryCols = new Array(); //Create new associative array to store node column names
        for (strColumnName in _arrColumnNode) {
            regexpNodes = new RegExp(strQuery);       //Form the regular expression object
            bExist = regexpNodes.test(strColumnName); //Check if this node matched with the given expression of input node filter
            if (bExist) {
                //Show the node column
                _insertData(arrQueryCols, strColumnName, "");
            }
        }
        return arrQueryCols; //Return the set that has the column names for the input node filter expression
    }

    /**
    * This filters the result based on the input node filter. Only nodes matching the filter 
    * (separate expressions are ANDed) will be shown as columns in the table.
    * @method _filterNodes
    * @private
    */
    var _filterNodes = function() {
        var indx, nLoop = 0, strColumnName = "", strName = "", arrNodeNames, arrQueryNodes,
            arrTemp, arrNodeCols = null, arrQueryCols = null,
            strNodeNames = _strNodesName.trim(); //Remove the whitespaces from the ends of the string
        if (strNodeNames.length == 0) //If node query box is empty, then show all columns
        {
            return _arrColumnNode;
        }

        strNodeNames = strNodeNames.replace(/\n/g, " ");
        arrNodeNames = strNodeNames.split(/\s+/); //Split the blocks names using the delimiter whitespace (" ")
        arrQueryNodes = new Array();
        for (indx = 0; indx < arrNodeNames.length; indx++) {
            strName = arrNodeNames[indx].trim(); //Remove the whitespaces in the blocknames
            _insertData(arrQueryNodes, strName, "");
        }

        arrTemp = new Array();
        for (strName in arrQueryNodes) {
            arrQueryCols = _getQueryColumns(strName); //Get the list of nodes that match with the given separate expression of the node filter 
            if (nLoop == 0) //If first loop, then just copy the result of query to the result column list
            {
                arrNodeCols = arrQueryCols;
                nLoop++;
            }
            else {
                //Find the intersection of query result and seperate expression result
                arrTemp = new Array();
                for (strColumnName in arrQueryCols) {
                    if (arrNodeCols[strColumnName] == "") {
                        _insertData(arrTemp, strColumnName, ""); //Add if both sets have same item
                    }
                }
                arrNodeCols = null;   //Clear the previous result
                arrNodeCols = arrTemp; //The query result is updated with the new value
            }
        }
        return arrNodeCols; //Return the set of nodes to be shown to user
    }

    /**
    * This hides the column in the datatable of the module.
    * @method _hideColumn
    * @param strColumnName {String} is column name.
    * @private
    */
    var _hideColumn = function(strColumnName) {
        var objColumn = _dataTable.getColumn(strColumnName); //Get the column object
        if (objColumn) {
            _dataTable._hideColumn(objColumn); //Hide the column
        }
    }

    /**
    * This shows the column in the datatable of the module.
    * @method _showColumn
    * @param strColumnName {String} is column name.
    * @private
    */
    var _showColumn = function(strColumnName) {
        var objColumn = _dataTable.getColumn(strColumnName); //Get the column object
        if (objColumn) {
            _dataTable._showColumn(objColumn); //Show the column
        }
    }

    /**
    * This checks if the block row has to be shown in the datatable or not by checking the data
    * transfer percentage of all block nodes.
    * @method _showBlock
    * @param objBlock {Object} is block object that has block details.
    * @param arrColumn {Array} has column names.
    * @private
    */
    var _showBlock = function(objBlock, arrColumn) {
        var strColumnName = "", jsonNode = null, objNode = null, nTransferPercent = 0, nNodeCount = 0, arrBlkNodes = objBlock.Nodes;
        if (arrBlkNodes) {
            nNodeCount = _arrayLength(arrBlkNodes);
            if (nNodeCount < _arrayLength(_arrColumnNode)) {
                objBlock.MinPercent = 0;
            }
            if (!((_highpercent < objBlock.MinPercent) || (objBlock.MaxPercent < _lowpercent))) {
                for (strColumnName in arrColumn) {
                    objNode = arrBlkNodes[strColumnName]; //Get the block info for the given block name
                    if (objNode) {
                        nTransferPercent = objNode.CompletePercent;
                    }
                    else {
                        nTransferPercent = 0;
                    }
                    if ((nTransferPercent >= _lowpercent) && (nTransferPercent <= _highpercent)) //Check if percentage is within query range
                    {
                        return true; //Show this block to user
                    }
                }
            }
        }
        return false; //Do not show this block to user
    }

    /**
    * This function formats the result obtained from data service, applies filter if any and shows the result in  
    * YUI datatable.
    * @method _formatResult
    * @param arrColumn {Array} has column names that has to be shown on UI. The columns vary depending on input filter.
    * @private
    */
    var _formatResult = function(arrColumn) {
        var data = [], bShow = false, strBlockName = "", strColumnName = "", nCurrentSize = 0, nTransferPercent = 0, nCount = 0,
            objArr = null, objBlock = null, objNode = null, arrBlkNodes = null, dtColumnsDef, dsCols,
            arrTotal = new Array(); //Create new associate array to store all the total row

        _nPgBarIndex = 0; //Reset the ID of the progress bar    
        for (objArr in _arrBlocks) {
            objBlock = _arrBlocks[objArr];
            if (objBlock == null) {
                continue;
            }
            bShow = _showBlock(objBlock, arrColumn); //Check if the block can be shown to user
            if (bShow) {
                nCount++;
                arrBlkNodes = objBlock.Nodes;
                //The block has percentage range within user input query range. So show this block to user
                strBlockName = objBlock.BlockName; //Get the block name
                var row = { "blockname": strBlockName, "blockfiles": objBlock.TotalFiles, "blockbytes": objBlock.TotalSize };
                for (strColumnName in arrColumn) {
                    arrBlkNodes = objBlock.Nodes;
                    objNode = arrBlkNodes[strColumnName]; //Get the node info for the given node name
                    if (objNode) {
                        nTransferPercent = objNode.CompletePercent;
                        _updateTotalRow(arrTotal, strColumnName, objNode.CurrentSize);
                    }
                    else {
                        nTransferPercent = 0;
                    }
                    row[strColumnName] = nTransferPercent;
                }
                //This checks the result obtained from data serice, input block names and shows user if input is invalid
                _queryBlockExists(strBlockName);

                data.push(row);
                _updateTotalRow(arrTotal, "blockfiles", objBlock.TotalFiles); //Update the values of Total Row for the datatable
                _updateTotalRow(arrTotal, "blockbytes", objBlock.TotalSize); //Update the values of Total Row for the datatable
            }
        }
        log('The data for the datatable has been formed by processing the data service response', 'info', this.me)

        //The custom progress bar format to the node column
        Yw.DataTable.Formatter.customProgressBar = function(elCell, oRecord, oColumn, sData) {
            var strPerHTML = '',
                nSize = oRecord.getData("blockbytes") * sData / 100, //Calculate the current size of the block data transferred
                strHTML = '<div><div id = "BlkProgressBar' + ++_nPgBarIndex + '" role="progressbar" aria-valuemin="0" aria-valuemax=100" aria-valuenow="' + sData + '" ';
            if ((sData >= _lowpercent) && (sData <= _highpercent)) {
                //The percentage is within query range
                strHTML = strHTML + 'class="progressbar ui-progressbar ui-widget ui-widget-content ui-corner-all" aria-disabled="true">';
                strPerHTML = '<div class = "percent">' + sData + '% (' + PHEDEX.Util.format.bytes(nSize) + ')</div>';
            }
            else {
                //The percentage is NOT within query range. So disable the progress bar
                strHTML = strHTML + 'class="progressbar ui-progressbar ui-widget ui-widget-content ui-corner-all ui-progressbar-disabled ui-state-disabled">';
                strPerHTML = '<div class = "disablepercent">' + sData + '% (' + PHEDEX.Util.format.bytes(nSize) + ')</div>';
            }
            strHTML = strHTML + '<div class="ui-progressbar-value ui-widget-header ui-corner-left" style="width:' + sData + '%;"></div></div>'
            strHTML = '<div>' + strHTML + strPerHTML + '</div>';
            elCell.innerHTML = strHTML;
        };

        dtColumnsDef = [{ "key": "blockname", "label": "Block", "sortable": true, "resizeable": true, "width": 300 },
                            { "key": "blockfiles", "label": "Files", "sortable": true, "resizeable": true, "width": 30 },
                            { "key": "blockbytes", "label": "Size", "sortable": true, "resizeable": true, "width": 70, "formatter": "customBytes" }
                            ];
        dsCols = ["blockname", "blockfiles", "blockbytes"];
        //Traverse through the node list and add node columns to the datasource
        for (strColumnName in arrColumn) {
            dtColumnsDef.push({ "key": strColumnName, "sortable": true, "formatter": "customProgressBar" });
            dsCols.push(strColumnName);
        }

        //The function that is called after any of the columns is sorted
        //This is used to put the "Total" row always at top of the table
        var afterSorting = function(oArgs) {
            var nRowIndx = _dataTable.getRecordIndex(_recordAllRow);
            _dataTable.deleteRow(nRowIndx); 		    //Delete the Total row from its current position after sorting 
            _dataTable.addRow(_totalRow, 0); 		    //Add the Total row at top of the table
            _recordAllRow = _dataTable.getRecord(0); 	//Get the Total row object and store it for future use in this function.
        };

        try {
            if (_dataTable) {
                _dataTable.destroy();
                _dataTable = null;
                dataSource = null;
            }
            dataSource = new Yu.LocalDataSource(data); //Create new datasource
            dataSource.responseType = YuDS.TYPE_JSARRAY;
            dataSource.responseSchema = { "fields": dsCols };

            if (nCount > 70) //Use Paginator as there are more blocks to display
            {
                var pagnDtResult = { paginator: new Yw.Paginator({ rowsPerPage: 50 }) }; //Paginator configuration to display large number of blocks
                _dataTable = new Yw.DataTable(_divResult, dtColumnsDef, dataSource, pagnDtResult); //Create new datatable using datasource and column definitions
            }
            else {
                _dataTable = new Yw.DataTable(_divResult, dtColumnsDef, dataSource); //Create new datatable using datasource and column definitions
            }
            log('The datatable in module has been created with data corresponding to user input', 'info', this.me)
            _dataTable.subscribe('columnSortEvent', afterSorting);  //Assign the function to the event (after column gets sorted)
        }
        catch (e) {
            banner("Error in creating datatable.", 'error');
            log("Error in creating datatable. " + e.name + " - " + e.message, 'error');
            return;
        }

        if (_dataTable.getRecordSet().getLength() > 0) {
            var nAllCurrentSize = 0, nValue = 0, percentcompleted,
            nAllBlockFiles = arrTotal["blockfiles"], //Get the total block file count
            nAllBlockBytes = arrTotal["blockbytes"]; //Get the total block size
            _totalRow = { "blockname": "(All)", "blockfiles": nAllBlockFiles, "blockbytes": nAllBlockBytes };
            for (strColumnName in arrColumn) {
                nValue = arrTotal[strColumnName]; //Get the node total info
                if (nValue) {
                    nAllCurrentSize = nValue;
                }
                else {
                    nAllCurrentSize = 0;
                }
                percentcompleted = 100 * nAllCurrentSize / nAllBlockBytes; //Calculate the total data transfer percenatage for node
                if (_isDecimal(percentcompleted)) {
                    percentcompleted = percentcompleted.toFixed(2);
                }
                _totalRow[strColumnName] = percentcompleted;
            }
            arrTotal = null; //Clear the arrTotal

            try {
                _dataTable.addRow(_totalRow, 0);
                log('The total row (1st row) is added to datatable', 'info', this.me)
                _recordAllRow = _dataTable.getRecord(0);
            }
            catch (ex) {
                log("Error in adding total row to the table", 'error');
            }
            if (_arrayLength(arrColumn) < _arrayLength(_arrColumnNode)) //Node filter is on
            {
                //Now check if all visible blocks for the node columns have data transfer percentage range within query range 
                for (strColumnName in arrColumn) {
                    bShow = _showNode(strColumnName);
                    if (!bShow) {
                        //Hide the column as the column has all blocks data transfer percentage range out of query range
                        _hideColumn(strColumnName);
                    }
                }
                log('The node filter is applied by hiding unnecessary columns in datatable', 'info', this.me)
            }
        }
        else {
            _divResult.innerHTML = "";
            _bFormTable = true;
        }
        if (_arrayLength(_arrQueryBlkNames) > 0) {
            _divMissingBlks.innerHTML = _getMissingBlocks(); //Get the block names for which data service returned nothing and show to user
        }
        else {
            _divMissingBlks.innerHTML = ""; //Clear the user message
        }
    }

    /**
    * This function checks if the query block name is there in the result obtained from API or not.
    * @method _queryBlockExists
    * @param blockname {String} is name of block whose information would be checked if it matches input filter or not.
    * @private
    */
    var _queryBlockExists = function(blockname) {
        try {
            if (_arrayLength(_arrQueryBlkNames) == 0) {
                return;
            }
            var indx = 0, wildcharindx = 0, queryblkname = "", strName = "";
            blockname = blockname.toLowerCase();
            //Traverse the set and check if the block is there or not
            for (strName in _arrQueryBlkNames) {
                queryblkname = strName.toLowerCase();
                wildcharindx = queryblkname.indexOf("*"); //If the input has wild character
                if (wildcharindx > -1) {
                    queryblkname = queryblkname.substring(0, wildcharindx);
                    if (blockname.startsWith(queryblkname)) {
                        delete _arrQueryBlkNames[strName];
                        break;
                    }
                }
                else if (blockname == queryblkname) {
                    delete _arrQueryBlkNames[strName]; //Remove the blockname from the set as it is there in the result
                    break;
                }
            }
        }
        catch (ex) {
            log('Error in checking if query block name exists in result', 'error', this.me)
        }
    }

    /**
    * This function generates the html element to show the missing blocks for which data service didn't return any info.
    * @method _getMissingBlocks
    * @private
    */
    var _getMissingBlocks = function() {
        var strName = "", indx = 1,
        strXmlMsg = 'The query result for the following block(s) is none because [block name is wrong]\\[block data transfer percentage ';
        strXmlMsg = strXmlMsg + "is out of the input range]\\[any of the node names is wrong].<br/>";
        for (strName in _arrQueryBlkNames) {
            strXmlMsg = strXmlMsg + indx + ". " + strName + "<br/>";
            indx++;
        }
        return strXmlMsg;
    }

    /**
    * This gets the length of the associative array.
    * @method _arrayLength
    * @param array {Array} is array whose length has to be found.
    * @private
    */
    var _arrayLength = function(array) {
        var nLength = 0;
        for (var object in array) {
            nLength++;
        }
        return nLength;
    }

    /**
    * This function checks if input number is decimal or not. Used to display numbers with precison.
    * @method _isDecimal
    * @param value {String} would be checked if it has decimal values or not.
    * @private
    */
    var _isDecimal = function(value) {
        return _regexpDot.test(value);
    }

    /**
    * This inserts data to associative array if not present else leave it.
    * @method _insertData
    * @param array {Array} is associative array in which (key, value) pair has to be inserted.
    * @param strKey {String} is key.
    * @param strVal {String} is value.
    * @private
    */
    var _insertData = function(arrData, strKey, strVal) {
        var objVal = arrData[strKey]; //Get the value for the key
        if (objVal == null) {
            arrData[strKey] = strVal; //Add the value if key is not present
        }
    }

    //Callback function used by YUI connection manager on completing the connection request with web API
    this.funcSuccess = function(jsonBlkData) {
        try {
            log('The data service response is received and ready for processing', 'info', this.me)
            var blk = null, replica = null, indxBlock = 0, indxReplica = 0, indxNode = 0,
                blockbytes = 0, blockcount = 0, blockfiles = 0, replicabytes = 0, replicacount = 0;
            if (_arrBlocks) {
                _arrBlocks = null;
            }
            _arrBlocks = new Array(); //Create new associative array to store all the block info

            if (_arrColumnNode) {
                _arrColumnNode = null;
            }
            _arrColumnNode = new Array(); //Create new associative array to store all the node names

            if (!jsonBlkData.block) {
                throw new Error('data incomplete for ' + context.api);
            }
            blockcount = jsonBlkData.block.length; //Get the block count from json response
            //Traverse through the blocks in json response to get block information
            for (indxBlock = 0; indxBlock < blockcount; indxBlock++) {
                blk = null;
                blk = jsonBlkData.block[indxBlock]; //Get the block object from the json response
                if (blk) {
                    blockbytes = blk.bytes / 1; //Get bytes count that has to be transferred
                    blockfiles = blk.files / 1; //Get number of files of the block

                    replicacount = blk.replica.length;  //Get the count of replicas (nodes) to whom the block is being transferred
                    //Traverse through the replicas (nodes) for each block to get node information
                    for (indxReplica = 0; indxReplica < replicacount; indxReplica++) {
                        replica = null;
                        replica = blk.replica[indxReplica]; //Get the replica (node) object from the json response
                        if (replica) {
                            replicabytes = replica.bytes / 1; //Get the bytes count that was transferred
                            var percentcompleted = 100 * replicabytes / blockbytes; //Calculate the data transfer percenatage
                            if (_isDecimal(percentcompleted)) {
                                percentcompleted = percentcompleted.toFixed(2); //Round off the percentage to 2 decimal digits
                            }
                            var objNode = _newNode(replica.node, replicabytes, percentcompleted); //Create new node object to add to hash table
                            _addBlockNode(blk.name, blockbytes, blockfiles, objNode);  //Add the block and its new node info to the hash map
                            _insertData(_arrColumnNode, replica.node, "");  //Add the node name to the hash map
                        }
                    }
                }
            }

            if (blockcount == 0) // Check if there is any block information to show to user
            {
                //No blocks are found for the given input
                if (_arrayLength(_arrQueryBlkNames) > 0) {
                    var strXmlMsg = _getMissingBlocks(); //Get the block names for which data service returned nothing and show to user
                    _divResult.innerHTML = ""; //Reset the result
                    _divMissingBlks.innerHTML = strXmlMsg; //Show the result to user
                }
            }
            else {
                //Do UI updates - show the block info to user
                _arrColumns = _filterNodes(); //Filter the results using the node filter
                if (_arrayLength(_arrColumns) > 0) {
                    _formatResult(_arrColumns);
                }
                else {
                    _bFormTable = true;
                    var strXmlMsg = _getMissingBlocks(); //Get the block names for which data service returned nothing and show to user
                    _divMissingBlks.innerHTML = strXmlMsg;
                }
            }
        }
        catch (e) {
            banner("Error in processing the received response. Please check the input.", 'error');
            _clearResult();
            _bFormTable = true;
        }
        return;
    }

    //If YUI connection manager fails communicating with web API, then this callback function is called
    this.funcFailure = function(objError) {
        banner("Error in communicating with data service and receiving the response.", 'error');
        log("Error in communicating with data service and receiving the response. " + objError.message, 'error');
        _clearResult(); //Clear the result elements
        _bFormTable = true;
        return;
    }

    this.eventSuccess = new YuCE("event success", this);
    this.eventFailure = new YuCE("event failure", this);

    this.eventSuccess.subscribe(function(type, args) { this.funcSuccess(args[0]); });
    this.eventFailure.subscribe(function(type, args) { this.funcFailure(args[0]); });

    /**
    * This function gets the block information from Phedex database using web APIs provided by Phedex given 
    * the block names in regular expression format.
    * The result is formatted and is shown to user in YUI datatable.
    * @method _getBlockInfo
    * @private
    */
    this._getBlockInfo = function() {
        var indx, blocknames, strNodeInput,
        strDataInput = _strBlocksName.trim(),
        strNodeInput = _strNodesName.trim();
        if (!strDataInput) {
            banner("Please enter the query block name(s).", 'warn'); //Inform user if input is missing
            _clearResult();
            return;
        }
        strDataInput = strDataInput.replace(/\n/g, " ");
        blocknames = strDataInput.split(/\s+/); //Split the blocks names using the delimiter whitespace (" ")
        _arrQueryBlkNames = new Array();
        for (indx = 0; indx < blocknames.length; indx++) {
            blocknames[indx] = blocknames[indx].trim(); //Remove the whitespaces in the blocknames
            _insertData(_arrQueryBlkNames, blocknames[indx], "");
        }
        if (_strOrigBlkQuery == strDataInput) //Check if current query block names and previous query block names are same or not
        {
            //No change in the input query. So, no need make data service call
            if (!(_strOrigNodeQuery == strNodeInput)) {
                _arrColumns = _filterNodes(); //Filter the nodes as entered by user
                _divMissingBlks.innerHTML = "Please wait... the query is being processed..."; //Show user the status message
                _formatResult(_arrColumns); //Do UI updates - show the block info to user in YUI datatable.
            }
            else if (!((_nOrigHighPercent == _highpercent) && (_nOrigLowPercent == _lowpercent))) //Check if there is any change in the percentage range
            {
                _divMissingBlks.innerHTML = "Please wait... the query is being processed..."; //Show user the status message
                _formatResult(_arrColumns); //Do UI updates - show the block info to user in YUI datatable.
                _nOrigLowPercent = _lowpercent;
                _nOrigHighPercent = _highpercent;
            }
            _strOrigNodeQuery = strNodeInput;
            return;
        }

        _divResult.innerHTML = "";
        _divMissingBlks.innerHTML = "Please wait... the query is being processed..."; //Show user the status message
        //Store the value for future use to check if value has changed or not and then format the result
        _nOrigLowPercent = _lowpercent;
        _nOrigHighPercent = _highpercent;
        _strOrigBlkQuery = strDataInput;
        _strOrigNodeQuery = strNodeInput;

        PHEDEX.Datasvc.Call({ api: 'blockreplicas', args: { block: blocknames }, success_event: this.eventSuccess, failure_event: this.eventFailure });
    }

    //Used to construct the block location module.
    _construct = function() {
        return {
            /**
            * This inits the Phedex.BlockLocation module and notify to sandbox about its status.
            * @method initData
            */
            initData: function() {
                this.dom.title.innerHTML = 'Phedex Block Location';
                _buildModule(this.dom);
                if (!_strBlocksName) {
                    _sbx.notify('module', 'needArguments', this.id);
                    return;
                }
                _sbx.notify(this.id, 'initData');
            },
            /**
            * Sets the category for the module whose information has to be shown on navigator.
            * @method setArgs
            * @param {Object} args is the object that has arguments for the module
            */
            setArgs: function(args) {
                if (!args) { return; }
                if (args.block) { _strBlocksName = args.block; }
                else { _strBlocksName = ""; }
                _divInput.txtboxBlk.value = _strBlocksName; //This is temporary. Just to set the name of block in the input textbox when the module is called from other modules.
                if (!(typeof (args.nodename) == 'undefined')) { _strNodesName = args.nodename; }
                if (args.lowpercent) { _lowpercent = args.lowpercent; }
                if (args.highpercent) { _highpercent = args.highpercent; }
                this.dom.title.innerHTML = 'setting parameters...';
                _sbx.notify(this.id, 'setArgs');
                log('Block Name is set to ' + _strBlocksName, 'info', _me);
            },
            /**
            * This gets the block information from Phedex data service for the given block name through sandbox.
            * @method getData
            */
            getData: function() {
                this.dom.title.innerHTML = 'Getting Block Information...';
                this._getBlockInfo();
                this.dom.title.innerHTML = 'Phedex Block Location';
                return;
            },

            isStateValid: function() {
              if (_strBlocksName) { return true; }
              return false;
            }
        };
    };
    Yla(this, _construct(), true);
    return this;
};
log('loaded...','info','blocklocation');
