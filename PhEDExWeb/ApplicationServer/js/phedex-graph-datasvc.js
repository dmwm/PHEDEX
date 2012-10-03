/*
   functions for manipulate data from DataService
*/

// 256 colors, first 14 are compatible with the cmsweb

var colors = [
    "#e66266",
    "#fff8a9",
    "#7bea81",
    "#8d4dff",
    "#ffbc71",
    "#a57e81",
    "#baceac",
    "#00ccff",
    "#ccffff",
    "#ff99cc",
    "#cc99ff",
    "#ffcc99",
    "#3366ff",
    "#33cccc",
    "#f77377",
    "#1009ba",
    "#8cfb92",
    "#9e5e10",
    "#10cd82",
    "#b68f92",
    "#cbdfbd",
    "#11dd10",
    "#dd1010",
    "#10aadd",
    "#ddaa10",
    "#10ddaa",
    "#447710",
    "#44dddd",
    "#088488",
    "#211acb",
    "#9d0ca3",
    "#af6f21",
    "#21de93",
    "#c7a0a3",
    "#dcf0ce",
    "#22ee21",
    "#ee2121",
    "#21bbee",
    "#eebb21",
    "#21eebb",
    "#558821",
    "#55eeee",
    "#199599",
    "#322bdc",
    "#ae1db4",
    "#c08032",
    "#32efa4",
    "#d8b1b4",
    "#ed01df",
    "#33ff32",
    "#ff3232",
    "#32ccff",
    "#ffcc32",
    "#32ffcc",
    "#669932",
    "#66ffff",
    "#2aa6aa",
    "#433ced",
    "#bf2ec5",
    "#d19143",
    "#4300b5",
    "#e9c2c5",
    "#fe12f0",
    "#441043",
    "#104343",
    "#43dd10",
    "#10dd43",
    "#4310dd",
    "#77aa43",
    "#771010",
    "#3bb7bb",
    "#544dfe",
    "#d03fd6",
    "#e2a254",
    "#5411c6",
    "#fad3d6",
    "#0f2301",
    "#552154",
    "#215454",
    "#54ee21",
    "#21ee54",
    "#5421ee",
    "#88bb54",
    "#882121",
    "#4cc8cc",
    "#655e0f",
    "#e150e7",
    "#f3b365",
    "#6522d7",
    "#0be4e7",
    "#203412",
    "#663265",
    "#326565",
    "#65ff32",
    "#32ff65",
    "#6532ff",
    "#99cc65",
    "#993232",
    "#5dd9dd",
    "#766f20",
    "#f261f8",
    "#04c476",
    "#7633e8",
    "#1cf5f8",
    "#314523",
    "#774376",
    "#437676",
    "#761043",
    "#431076",
    "#764310",
    "#aadd76",
    "#aa4343",
    "#6eeaee",
    "#878031",
    "#037209",
    "#15d587",
    "#8744f9",
    "#2d0609",
    "#425634",
    "#885487",
    "#548787",
    "#872154",
    "#542187",
    "#875421",
    "#bbee87",
    "#bb5454",
    "#7ffbff",
    "#989142",
    "#14831a",
    "#26e698",
    "#98550a",
    "#3e171a",
    "#536745",
    "#996598",
    "#659898",
    "#983265",
    "#653298",
    "#986532",
    "#ccff98",
    "#cc6565",
    "#900c10",
    "#a9a253",
    "#25942b",
    "#37f7a9",
    "#a9661b",
    "#4f282b",
    "#647856",
    "#aa76a9",
    "#76a9a9",
    "#a94376",
    "#7643a9",
    "#a97643",
    "#dd10a9",
    "#dd7676",
    "#a11d21",
    "#bab364",
    "#36a53c",
    "#4808ba",
    "#ba772c",
    "#60393c",
    "#758967",
    "#bb87ba",
    "#87baba",
    "#ba5487",
    "#8754ba",
    "#ba8754",
    "#ee21ba",
    "#ee8787",
    "#b22e32",
    "#cbc475",
    "#47b64d",
    "#5919cb",
    "#cb883d",
    "#714a4d",
    "#869a78",
    "#cc98cb",
    "#98cbcb",
    "#cb6598",
    "#9865cb",
    "#cb9865",
    "#ff32cb",
    "#ff9898",
    "#c33f43",
    "#dcd586",
    "#58c75e",
    "#6a2adc",
    "#dc994e",
    "#825b5e",
    "#97ab89",
    "#dda9dc",
    "#a9dcdc",
    "#dc76a9",
    "#a976dc",
    "#dca976",
    "#1043dc",
    "#10a9a9",
    "#d45054",
    "#ede697",
    "#69d86f",
    "#7b3bed",
    "#edaa5f",
    "#936c6f",
    "#a8bc9a",
    "#eebaed",
    "#baeded",
    "#ed87ba",
    "#ba87ed",
    "#edba87",
    "#2154ed",
    "#21baba",
    "#e56165",
    "#fef7a8",
    "#7ae980",
    "#8c4cfe",
    "#febb70",
    "#a47d80",
    "#b9cdab",
    "#ffcbfe",
    "#cbfefe",
    "#fe98cb",
    "#cb98fe",
    "#fecb98",
    "#3265fe",
    "#32cbcb",
    "#f67276",
    "#0f08b9",
    "#8bfa91",
    "#9d5d0f",
    "#0fcc81",
    "#b58e91",
    "#cadebc",
    "#10dc0f",
    "#dc0f0f",
    "#0fa9dc",
    "#dca90f",
    "#0fdca9",
    "#43760f",
    "#43dcdc",
    "#078387",
    "#2019ca",
    "#9c0ba2",
    "#ae6e20",
    "#20dd92",
    "#c69fa2",
    "#dbefcd",
    "#21ed20",
    "#ed2020",
    "#20baed",
    "#edba20",
    "#20edba",
    "#548720",
    "#54eded",
    "#189498",
    "#312adb",
    "#ad1cb3",
    "#bf7f31",
];

/*
transferhistory(d, graph, by, hide_mss)

       d : data from datasvc::transferrequest
   graph : 'rate', 'volume', 'acc_volume'
      by : 'source', 'destination', 'link', default link
hide_mss : whether to show mss nodes
*/

function transferhistory(d, graph, by, hide_mss)
{
    var l;
    var history = {};
    var node = {};
    var tbin = {};
    var node_total = {};
    var title = "Transfer Rate";
    var ylabel = "Transfer Rate [MB/s]";
    var yfactor = 1000000;
    var yunit = "MB/s";

    for (l in d.phedex.link)
    {
        var link = d.phedex.link[l];
        // take care of hide_mss
        if (hide_mss == 'y')
        {
            if (isMSS(link.from) || isMSS(link.to))
            {
                continue;
            }
        }
        var label;
        // take care of by
        if (by == 'src')
        {
            label = link.from;
        }
        else if (by == 'dst')
        {
            label = link.to;
        }
        else if (by == 'link')
        {
            label = link.from +' to '+link.to;
        }
        else // default link
        {
            label = link.from +' to '+link.to;
        }

        var t;
        for (t in link.transfer)
        {
            var transfer = link.transfer[t];
            var timebin = transfer.timebin;

            // create history[timebin] if it was not there
            if (history[timebin] == null)
            {
                history[timebin] = {};
            }
            
            // create history[timebin][node] if it was not there
            if (history[timebin][label] == null)
            {
                history[timebin][label] = 0;
            }

            if (node_total[label] == null)
            {
                node_total[label] = 0;
            }

            if (graph == 'rate')
            {
                history[timebin][label] += transfer.rate;
                node_total[label] += transfer.rate;
            }
            else if (graph == 'volume')
            {
                history[timebin][label] += transfer.done_bytes;
                node_total[label] += transfer.done_bytes;
            }
            else if (graph == 'acc_volume')
            {
                history[timebin][label] += transfer.done_bytes;
                node_total[label] += transfer.done_bytes;
            }
            else if (graph == 'attempt')
            {
                history[timebin][label] += transfer.try_files;
                node_total[label] += transfer.try_files;
            }
            else if (graph == 'success')
            {
                history[timebin][label] += transfer.done_files;
                node_total[label] += transfer.done_files;
            }
            else if (graph == 'failure')
            {
                history[timebin][label] += transfer.fail_files;
                node_total[label] += transfer.fail_files;
            }

            node[label] = 1;
            tbin[timebin] = 1;
        }
    }
//    var nodes = Object.keys(node).sort();
    var tbins = Object.keys(tbin).sort();
    var result = [];
    var total = [];
    var n;

    for (n in node_total)
    {
        total.push({node: n, value: node_total[n]});
    }

    total.sort(function (a, b)
        {
            if (a.value < b.value)
                return 1;
            if (a.value > b.value)
                return -1;
            return 0;
        }
    );

    var nodes = [];
    var count = 0;
    for (n in total)
    {
        nodes.push(total[n].node);
        count = count + 1;
        if (count > 200)
            break;
    }

    var i, j;

    for (i in nodes)
    {
        var rdata = [];
        var acc = 0;
        var val;
        for (j in tbins)
        {
            if (history[tbins[j]][nodes[i]])
            {
                val = history[tbins[j]][nodes[i]];
            }
            else
            {
                val = 0;
            }
            if (graph == 'acc_volume')
            {
                rdata.push(val + acc);
            }
            else
            {
                rdata.push(val);
            }
            acc += val;
        }
        result.push({name: nodes[i], data: rdata});
    }

    if (graph == 'rate')
    {
        yunit = "MB/s";
        title = "Transfer Rate";
        ylabel = "Transfer Rate ["+yunit+"]";
        yfactor = 1000000;
    }
    else if (graph == 'volume')
    {
        yunit = "TB";
        title = "Transfer Volume";
        ylabel = "Transfer Volume ["+yunit+"]";
        yfactor = 1000000000000;
    }
    else if (graph == 'acc_volume')
    {
        yunit = "TB";
        title = "Cumulative Transfer Volume";
        ylabel = "Data Transferred ["+yunit+"]";
        yfactor = 1000000000000;
    }
    else if (graph == 'attempt')
    {
        yunit = "Files";
        title = "Number of Attempted Transfers";
        ylabel = "Attempted Transfers ["+yunit+"]";
        yfactor = 1;
    }
    else if (graph == 'success')
    {
        yunit = "Files";
        title = "Number of Successful Transfers";
        ylabel = "Successful Transfers ["+yunit+"]";
        yfactor = 1;
    }
    else if (graph == 'failure')
    {
        yunit = "Files";
        title = "Number of Failed Transfers";
        ylabel = "Failed Transfers ["+yunit+"]";
        yfactor = 1;
    }


    return {series: result, xcat: tbins, title: title, ylabel: ylabel, yfactor: yfactor, yunit: yunit};
}

function nodeusagehistory(d, graph, by, hide_mss)
{
    var l;
    var history = {};
    var node = {};
    var tbin = {};
    var node_total = {};
    var title = "Volume dwiRoutedQueued";
    var ylabel = "Queued Data [TB]";
    var yfactor = 1000000000000;
    var yunit = "TB";

    for (l in d.phedex.node)
    {
        var n = d.phedex.node[l];
        // take care of hide_mss
        if (hide_mss == 'y')
        {
            if (isMSS(n.name))
            {
                continue;
            }
        }
        var label = n.name;
        var u;
        for (u in n.usage)
        {
            var usage = n.usage[u];
            var timebin = usage.timebin;

            // create history[timebin] if it was not there
            if (history[timebin] == null)
            {
                history[timebin] = {};
            }
            
            // create history[timebin][node] if it was not there
            if (history[timebin][label] == null)
            {
                history[timebin][label] = 0;
            }

            if (node_total[label] == null)
            {
                node_total[label] = 0;
            }

            if (graph == 'routed')
            {
                history[timebin][label] += usage.cust_dest_bytes + usage.noncust_dest_bytes;
                node_total[label] += usage.cust_dest_bytes + usage.noncust_dest_bytes;
            }
            else if (graph == 'resident')
            {
                history[timebin][label] += usage.cust_node_bytes + usage.noncust_node_bytes;
                node_total[label] += usage.cust_dest_bytes + usage.noncust_node_bytes;
            }
            else if (graph == 'requested')
            {
                history[timebin][label] += usage.request_bytes;
                node_total[label] += usage.request_bytes;
            }
            else if (graph == 'idle')
            {
                history[timebin][label] += usage.idle_bytes;
                node_total[label] += usage.idle_bytes;
            }

            node[label] = 1;
            tbin[timebin] = 1;
        }
    }

    var tbins = Object.keys(tbin).sort();
    var result = [];
    var total = [];
    var n;

    for (n in node_total)
    {
        total.push({node: n, value: node_total[n]});
    }

    total.sort(function (a, b)
        {
            if (a.value < b.value)
                return 1;
            if (a.value > b.value)
                return -1;
            return 0;
        }
    );

    var nodes = [];
    for (n in total)
    {
        nodes.push(total[n].node);
    }

    var i, j;

    for (i in nodes)
    {
        var rdata = [];
        var val;
        for (j in tbins)
        {
            if (history[tbins[j]][nodes[i]])
            {
                val = history[tbins[j]][nodes[i]];
            }
            else
            {
                val = 0;
            }
            rdata.push(val);
        }
        result.push({name: nodes[i], data: rdata});
    }

    yunit = 'TB';
    yfactor = 1000000000000;
    if (graph == 'queued')
    {
        title = "Volume of Queued Data";
        ylabel = "Queued Data ["+yunit+"]";
    }
    else if (graph == 'resident')
    {
        title = "Volume of Resident Data";
        ylabel = "Data Resident ["+yunit+"]";
    }
    else if (graph == 'routed')
    {
        title = "Volume of Routed Data";
        ylabel = "Routed Data ["+yunit+"]";
    }
    else if (graph == 'idle')
    {
        title = "Volume of Idle Data";
        ylabel = "Idle Data ["+yunit+"]";
    }
    else if (graph == 'requested')
    {
        title = "Volume of Requested Data";
        ylabel = "Requested Data ["+yunit+"]";
    }

    return {series: result, xcat: tbins, title: title, ylabel: ylabel, yfactor: yfactor, yunit: yunit};
}

function time2string(d)
{
    var date = new Date(d * 1000);
    var year = date.getUTCFullYear();
    var month = date.getUTCMonth();
    var day = date.getUTCDate();
    var hour = date.getUTCHours();
    var minute = date.getUTCMinutes();
    var second = date.getUTCSeconds();

    return year+(month < 10?"-0":"-")+month+(day< 10?"-0":"-")+day+(hour < 10?" 0":" ")+hour+(minute < 10?":0":":")+minute+(second < 10 ? ":0":":")+second;
}

function routerhistory(d, graph, by, hide_mss)
{
    var l;
    var history = {};
    var node = {};
    var tbin = {};
    var node_total = {};
    var title = "Volume of Queued Data";
    var ylabel = "Queued Data [TB]";
    var yfactor = 1000000000000;
    var yunit = "TB";

    for (l in d.phedex.link)
    {
        var link = d.phedex.link[l];
        // take care of hide_mss
        if (hide_mss == 'y')
        {
            if (isMSS(link.from) || isMSS(link.to))
            {
                continue;
            }
        }
        var label;
        // take care of by
        if (by == 'src')
        {
            label = link.from;
        }
        else if (by == 'dst')
        {
            label = link.to;
        }
        else if (by == 'link')
        {
            label = link.from +' to '+link.to;
        }
        else // default link
        {
            label = link.from +' to '+link.to;
        }

        var r;
        for (r in link.route)
        {
            var route = link.route[r];
            var timebin = route.timebin;

            // create history[timebin] if it was not there
            if (history[timebin] == null)
            {
                history[timebin] = {};
            }
            
            // create history[timebin][node] if it was not there
            if (history[timebin][label] == null)
            {
                history[timebin][label] = 0;
            }

            if (node_total[label] == null)
            {
                node_total[label] = 0;
            }

            if (graph == 'routed')
            {
                history[timebin][label] += route.route_bytes;
                node_total[label] += route.route_bytes;
            }
            else if (graph == 'requested')
            {
                history[timebin][label] += route.request_bytes;
                node_total[label] += route.request_bytes;
            }
            else if (graph == 'idle')
            {
                history[timebin][label] += route.idle_bytes;
                node_total[label] += route.idle_bytes;
            }
            else if (graph == 'queued')
            {
                history[timebin][label] += route.pend_bytes;
                node_total[label] += route.pend_bytes;
            }

            node[label] = 1;
            tbin[timebin] = 1;
        }
    }

    var tbins = Object.keys(tbin).sort();
    var result = [];
    var total = [];
    var n;

    for (n in node_total)
    {
        total.push({node: n, value: node_total[n]});
    }

    total.sort(function (a, b)
        {
            if (a.value < b.value)
                return 1;
            if (a.value > b.value)
                return -1;
            return 0;
        }
    );

    var nodes = [];
    var count = 0;
    for (n in total)
    {
        nodes.push(total[n].node);
        count = count + 1;
        if (count > 200)
            break;
    }

    var i, j;

    for (i in nodes)
    {
        var rdata = [];
        var val;
        for (j in tbins)
        {
            if (history[tbins[j]][nodes[i]])
            {
                val = history[tbins[j]][nodes[i]];
            }
            else
            {
                val = 0;
            }
            rdata.push(val);
        }
        result.push({name: nodes[i], data: rdata});
    }

    yunit = 'TB';
    yfactor = 1000000000000;
    if (graph == 'queued')
    {
        title = "Volume of Queued Data";
        ylabel = "Queued Data ["+yunit+"]";
    }
    else if (graph == 'resident')
    {
        title = "Volume of Resident Data";
        ylabel = "Data Resident ["+yunit+"]";
    }
    else if (graph == 'routed')
    {
        title = "Volume of Routed Data";
        ylabel = "Routed Data ["+yunit+"]";
    }
    else if (graph == 'idle')
    {
        title = "Volume of Idle Data";
        ylabel = "Idle Data ["+yunit+"]";
    }
    else if (graph == 'requested')
    {
        title = "Volume of Requested Data";
        ylabel = "Requested Data ["+yunit+"]";
    }

    return {series: result, xcat: tbins, title: title, ylabel: ylabel, yfactor: yfactor, yunit: yunit};
}

function time2string(d)
{
    var date = new Date(d * 1000);
    var year = date.getUTCFullYear();
    var month = date.getUTCMonth();
    var day = date.getUTCDate();
    var hour = date.getUTCHours();
    var minute = date.getUTCMinutes();
    var second = date.getUTCSeconds();

    return year+(month < 10?"-0":"-")+month+(day< 10?"-0":"-")+day+(hour < 10?" 0":" ")+hour+(minute < 10?":0":":")+minute+(second < 10 ? ":0":":")+second;
}

function isMSS(d)
{
    return (d.match(/_MSS$/))? true: false;
}

function subtitle(start)
{
    var unit = start.substr(start.length - 1, 1);
    var type = start.substr(0, 1);
    var units;
    var value;
    var s = 0;
    var e;
    var d = new Date();
    var this_hour = parseInt(d.getTime()/(1000*60*60))*(60*60);
    var since;

    if (unit != null)
    {
        e = start.length - 1;
    }

    if (type == '-')
    {
        s = 1;
    }

    value = start.substring(s, e);

    switch(unit)
    {
    case 'h':
        units = 'Hours';
        since = this_hour - (value * 3600);
        break;
    case 'd':
        units = 'Days';
        since = this_hour - (value * 86400);
        break;
    default:
        units = 'Hours';
        since = value;
        value = parseInt((this_hour - value)/3600);
        break;
    }

    var d1 = new Date(since * 1000);
    var d2 = new Date(this_hour * 1000);
    var st = "<font size=-2>"+value + " " + units + " from " + Highcharts.dateFormat('%Y-%m-%d %H:%M', d1) + " to " + Highcharts.dateFormat('%Y-%m-%d %H:%M', d2) + " UTC</font>";

    return st;

}

