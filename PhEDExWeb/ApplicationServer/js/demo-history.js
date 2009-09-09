//====================================================================================================
//File Name  : demo-history.js
//Purpose    : The javascript functions for gettting block information from Phedex database using web
//             APIs provided by Phedex and then format result to show it to user in YUI datatable.
//====================================================================================================

//Global Variables
var node, widget;   //The widget and node list boxes
var widgetUser;     //The widget currently user will be viewing
var currentstatus;  //The current user view status

//****************************************************************************************************
//Function:InitializeForm
//Purpose :This initializes the form i.e buttons, dialogbox and listbox are created using Yahoo APIs 
//****************************************************************************************************
function InitializeForm()
{
    CreateNodeListBox();    //Create the list box to show node names
    CreateWidgetListBox();  //Create the list box to show available widgets
    
    // Create Yahoo! Buttons
    var objPushBtnGet = new YAHOO.widget.Button({ label:"Submit", id:"buttonGetInfo", container:"BtnOK", onclick: { fn: FormWidget } });
    var objPushBtnReset = new YAHOO.widget.Button({ label:"Reset", id:"buttonReset", container:"BtnReset", onclick: { fn: Reset } });
    
    var handleOK = function() 
    {
        this.hide(); //Hide the messagebox after user clicks OK
    };
    // Create the message box dialog
    dialogUserMsg = new YAHOO.widget.SimpleDialog("dialogUserMsg", {    width: "400px",
                                                                        height: "100px",
                                                                        fixedcenter: true,
                                                                        visible: false,
                                                                        draggable: false,
                                                                        close: true,
                                                                        text: "Phedex History Demo message box",
                                                                        icon: YAHOO.widget.SimpleDialog.ICON_WARN,
                                                                        constraintoviewport: true,
                                                                        buttons: [ { text:"OK", handler:handleOK, isDefault:true}]
                                                                    });
    dialogUserMsg.setHeader("Phedex History Demo"); //Set the header of the message box
    dialogUserMsg.render(document.body);
    currentstatus = {}; //The current status is initialized
    currentstatus['widget'] = "";
    currentstatus['node'] = "";
}

//****************************************************************************************************
//Function:ParseQueryString
//Purpose :This parses the page query and return the key and its values
//****************************************************************************************************
function ParseQueryString(strQuery)
{
    var strTemp = "", indx = 0;
    var arrResult = {};
    var arrQueries = strQuery.split("&");
    for(indx = 0; indx < arrQueries.length; indx++)
    {
        strTemp = arrQueries[indx].split("=");
        if (strTemp[1].length > 0)
        {
            arrResult[strTemp[0]] = unescape(strTemp[1]);
        }
    }
    return arrResult;
}

//****************************************************************************************************
//Function:SetPageValues
//Purpose :This gets the key and its values of page query and sets the list boxes status
//****************************************************************************************************
function SetPageValues(state)
{
    if (state == "")
    {
        widget.selectedIndex = -1; //Set the widget list box
        node.selectedIndex = -1;   //Set the node list box
        return null;
    }
    else
    {
        var statevals = ParseQueryString(state); //Parse the current history state and get the key and its values
        widget.selectedIndex = GetWidgetIndex(statevals.widget); //Set the widget list box
        node.selectedIndex = GetNodeIndex(statevals.node);     //Set the node list box
        return statevals;
    }
}

var bkPageState = YAHOO.util.History.getBookmarkedState("page"); //Get the current bookmarked state
var initialPageState = bkPageState || '';

//****************************************************************************************************
//Function:SortColumn
//Purpose :This sorts the column after checking the current datatable column status and user query
//****************************************************************************************************
function SortColumn(statevals)
{
    if ((widgetUser.dataTable) && (statevals.sortcolumn)) //Check if widget has datatable
    {
        var sortedColumn = widgetUser.dataTable.get('sortedBy'); //Get the object of any column if sorted in datatable
        var objColumn = widgetUser.dataTable.getColumn(statevals.sortcolumn); //Get the object of column
        if (objColumn)
        {
            if (sortedColumn) //Check if any of the column is sorted in datatable
            {
                if ((sortedColumn.key == objColumn.key) && (sortedColumn.dir.substring(7) == statevals.sortdir))
                {
                    return; //Dont sort as there is no change in preferences
                }
            }
            if (statevals.sortdir.toLowerCase() == 'asc')
            {
                widgetUser.dataTable.sortColumn(objColumn, 'YAHOO.widget.DataTable.CLASS_ASC'); //Sort the column in ascending order
            }
            else if (statevals.sortdir.toLowerCase() == 'desc')
            {
                widgetUser.dataTable.sortColumn(objColumn, 'YAHOO.widget.DataTable.CLASS_DESC'); //Sort the column in descending order
            }
        }
    }
}

//****************************************************************************************************
//Function:AfterRender
//Purpose :This is called after datatable is rendered or modified.
//****************************************************************************************************
var AfterRender = function()
{
    var currentState = YAHOO.util.History.getCurrentState("page"); //Get the current state
    var statevals = ParseQueryString(currentState); //Get the current state key value pairs
    SortColumn(statevals); //Sort the column after datatable is rendered
};

//****************************************************************************************************
//Function:SetStatus
//Purpose :This is called by the history navigate functinality to set the status in the web page.
//****************************************************************************************************
var SetStatus = function(state)
{
    var statevals = SetPageValues(state);
    if (statevals)
    {
        if (currentstatus)
        {
            if (!(statevals.widget == currentstatus.widget) || !(statevals.node == currentstatus.node))
            {
                CreateWidget(); //Create widget if not create before or is different
            }
        }
        else
        {
            CreateWidget();     //Create widget if not create before or is different
        }
        SortColumn(statevals);  //Sort the column if widget has datatable
    }
    else
    {
        if (widgetUser)
        {
            widgetUser.onDestroy.fire(); //Destroy the widget if key value paid is nothing
            widgetUser = null;
        }
    }
    currentstatus = statevals; //Store the status for further inspection
};

YAHOO.util.History.register("page", initialPageState, SetStatus);

//****************************************************************************************************
//Function:AddToHistory
//Purpose :This adds the current state of the web page to history for further navigation.
//****************************************************************************************************
function AddToHistory() 
{
    var newState, currentState;
    newState = 'node=' + node.options[node.selectedIndex].text + "&widget=" + widget.options[widget.selectedIndex].text; //Form the query string
    try 
    {
        currentState = YAHOO.util.History.getCurrentState("page");
        if (newState !== currentState) //Check if previous and current state are different to avoid looping
        {
            YAHOO.util.History.navigate("page", newState); //Add current state to history and set values
        }
    }
    catch (e)
    {
        SetPageValues(newState);
    }
}

//Use the Browser History Manager onReady method to initialize the application.
YAHOO.util.History.onReady(function () 
{
    InitializeForm(); //Initializes the form
});

//****************************************************************************************************
//Function:AddItem
//Purpose :This adds item to the listbox
//****************************************************************************************************
function AddItem(listbox,text,value)
{
    var optItem = document.createElement("OPTION");
    optItem.text = text;
    optItem.value = value;
    listbox.options.add(optItem);
}

//****************************************************************************************************
//Function:CreateWidgetListBox
//Purpose :This creates the list box to show available widget types
//****************************************************************************************************
function CreateWidgetListBox()
{
    widget = document.getElementById("menuWidget");
    widget.size = 7;
    AddItem(widget,"Agents","agents");
    AddItem(widget,"Nodes","nodes");
    AddItem(widget,"LinkView","linkview");
}

//****************************************************************************************************
//Function:CreateNodeListBox
//Purpose :This creates the list box to show node names
//****************************************************************************************************
function CreateNodeListBox()
{
    node = document.getElementById("menuNode")
    node.size = 7;
    FillNodeListBox();
}

//****************************************************************************************************
//Function:FormWidget
//Purpose :This gets called when the submit button is clicked. Error handling is done if user hasn't 
//         selected any combination of widget and node
//****************************************************************************************************
function FormWidget()
{
    var nWidgetIndx = widget.options.selectedIndex; //Get selected widget type
    var nNodeIndx = node.options.selectedIndex;     //Get selected node name
    if (nWidgetIndx == -1)
    {
        dialogUserMsg.cfg.setProperty("text","Please select the widget."); //Alert user if input is missing
        dialogUserMsg.show();
        return;
    }
    if (nNodeIndx == -1)
    {
        dialogUserMsg.cfg.setProperty("text","Please select the node."); //Alert user if input is missing
        dialogUserMsg.show();
        return;
    }
    AddToHistory(); //Add this action to history
}

//****************************************************************************************************
//Function:AfterSorting
//Purpose :This gets called if any of the column is sorted in the widget datatable (if present) to 
//         add this action to history
//****************************************************************************************************
//The function that is called after any of the columns is sorted
var AfterSorting = function(oArgs)
{
    var newState, currentState;
    newState = newState = 'node=' + node.options[node.selectedIndex].text + "&widget=" + widget.options[widget.selectedIndex].text + '&sortcolumn=' + oArgs.column.key + '&sortdir=' + oArgs.dir.substring(7);
    try 
    {
        currentState = YAHOO.util.History.getCurrentState("page");
        if (newState !== currentState)  //Check if previous and current state are different to avoid looping
        {
            YAHOO.util.History.navigate("page", newState); //Add current state to history and set values
        }
    }
    catch (e)
    {
    }
};

//****************************************************************************************************
//Function:CreateWidget
//Purpose :Create widget according to user selection and by calling appropriate constructor
//****************************************************************************************************
function CreateWidget()
{
    var strNodeName = node.options[node.selectedIndex].text;
    var strWidget = widget.options[widget.selectedIndex].value;
    if (widgetUser)
    {
        widgetUser.onDestroy.fire(); //Destroy the widget if any already created
        widgetUser = null; 
    }
    if (strWidget == 'agents')
    {
        widgetUser = new PHEDEX.Widget.Agents( strNodeName, 'phedex-main');
        widgetUser.update();
    }
    else if (strWidget == 'nodes')
    {
        widgetUser = new PHEDEX.Widget.Nodes( strNodeName, 'phedex-main');
        widgetUser.update();
    }
    else if (strWidget == 'linkview')
    {
        widgetUser = new PHEDEX.Widget.LinkView( strNodeName, 'phedex-main');
        widgetUser.update();
    }
    if (widgetUser.dataTable)
    {        widgetUser.dataTable.subscribe('columnSortEvent', AfterSorting);  //Assign the function to the event (after column gets sorted)
        widgetUser.dataTable.subscribe('renderEvent', AfterRender);       //Assign the function to the event (after column gets sorted)
    }
}

//****************************************************************************************************
//Function:Reset
//Purpose :This resets the web page
//****************************************************************************************************
function Reset()
{
    widget.options.selectedIndex = -1;  //Reset the widget list box
    node.options.selectedIndex = -1;    //Reset the node list box
    if (widgetUser)
    {
        widgetUser.onDestroy.fire();    //Destroy the widget if present
        widgetUser = null; 
    }
	document.getElementById("phedex-main").innerHTML = "";
	//AddToHistory(); //Add this action also to history
}

//****************************************************************************************************
//Function:InitializeHistory
//Purpose :This initializes the browser history management library.
//****************************************************************************************************
function InitializeHistory()
{
    try 
    {
        YAHOO.util.History.initialize("yui-history-field", "yui-history-iframe");
    }
    catch (e)
    {
        InitializeForm();
    }
}

//****************************************************************************************************
//Function:FillNodeListBox
//Purpose :This function creates the list box and populates it with the node names obtained from the 
//         data service call using nodes API.
//****************************************************************************************************
function FillNodeListBox()
{
    //Callback function used by YUI connection manager on completing the connection request with web API
    funcSuccess = function(jsonNodes)
    {
        try 
        {
            var nNodes = 0, indx = 0;
            nNodes = jsonNodes.node.length; //Get the node count
            var arrTemp = new Array(nNodes);
            for (indx = 0; indx < nNodes; indx++)
            {
                arrTemp[indx] = jsonNodes.node[indx].name; //Add the node name to temporary array for sorting
            }
            arrTemp.sort(); //Sort the array for sorted list of node name
            for (indx = 0; indx < nNodes; indx++)
            {
                AddItem(node, arrTemp[indx], arrTemp[indx]); //Add the node to list box
            }
            if (nNodes > 10)
            {
                //Increase the height of list box if there are many nodes
                node.size = 10;
                widget.size = 10;
            }
            var currentState = YAHOO.util.History.getCurrentState("page"); //Get the current state
            SetStatus(currentState); //Set the current state in the web page
        }
        catch (e)
        {
            alert("Error in populating node list box.");
        }
        return;
    }

    //If YUI connection manager fails communicating with web API, then this callback function is called
    funcFailure = function(objError)
    {
        alert("Error in populating node list box. " + objError.message);
        return;
    }

    var eventSuccess = new YAHOO.util.CustomEvent("event success");
    var eventFailure = new YAHOO.util.CustomEvent("event failure");
    eventSuccess.subscribe(function(type,args) { funcSuccess(args[0]); });
    eventFailure.subscribe(function(type,args) { funcFailure(args[0]); });
    PHEDEX.Datasvc.Call({ api: 'nodes', success_event: eventSuccess, failure_event: eventFailure}); //Make the data service call
}

//*******************************************************************************************************
//Function:GetNodeIndex
//Purpose :This function searches the list box using binary search method to get the index of given node 
//*******************************************************************************************************
function GetNodeIndex(strNodeName)
{
    if (node.options.length == 0)
    {
        return -1;
    }
    var strTemp = '';
    var nLowIndx = 0, nHighIndx = 0, nMidIndx = 0;
	nHighIndx = node.options.length - 1;
	strNodeName = strNodeName.toLowerCase();
	while (nLowIndx <= nHighIndx)
	{
		nMidIndx = Math.round((nLowIndx + nHighIndx)/2);
		strTemp = node.options[nMidIndx].text.toLowerCase();
		if (strTemp > strNodeName)
		{
			nHighIndx = nMidIndx - 1;
		}
		else if (strTemp < strNodeName)
		{
			nLowIndx = nMidIndx + 1;
		}
		else
		{
			return nMidIndx; //Return the index of the node
		}
	}
	return -1;
}

//********************************************************************************************************
//Function:GetWidgetIndex
//Purpose :This function searches the list box using linear search method to get the index of given widget 
//********************************************************************************************************
function GetWidgetIndex(strWidget)
{
    if (widget.options.length == 0)
    {
        return -1;
    }
    var indx = 0;
    var strTemp = '';
    strWidget = strWidget.toLowerCase();
    for(indx = 0; indx < widget.options.length; indx++)
    {
        strTemp = widget.options[indx].text.toLowerCase();
        if (strTemp == strWidget)
        {
            return indx; //Return the index of the widget
        }
    }
    return -1;
}