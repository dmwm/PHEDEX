// From A List Apart (www.alistapart.com), "Zebra Tables" in No. 173.

// Work around a bug in IE related to element attributes
function hasClass(obj) {
  var result = false;
  if (obj.getAttributeNode("class") != null) {
    result = obj.getAttributeNode("class").value;
  }
  return result;
}   

// Strip even/odd rows of a table
function stripe(id) {
  var even = false; // flag rows even/odd
  
  // default colours to use for even/odd rows
  var evenColor = arguments[1] ? arguments[1] : "#fff";
  var oddColor = arguments[2] ? arguments[2] : "#eee";
  
  // find the named table, or abort if not found
  var table = document.getElementById(id);
  if (! table) { return; }
    
  // process all <td>s in all <tr>s in all <tbody>ies in the table,
  // but skip all rows and cells which already have set either a
  // "class" attribute or backgroundColor
  var tbodies = table.getElementsByTagName("tbody");
  for (var h = 0; h < tbodies.length; h++) {
    var trs = tbodies[h].getElementsByTagName("tr");
    for (var i = 0; i < trs.length; i++) {
      if (!hasClass(trs[i]) && ! trs[i].style.backgroundColor) {
        var tds = trs[i].getElementsByTagName("td");
        for (var j = 0; j < tds.length; j++) {
          var mytd = tds[j];
	  if (! hasClass(mytd) && ! mytd.style.backgroundColor) {
	    mytd.style.backgroundColor = even ? evenColor : oddColor;
          }
        }
      }
      // flip from odd to even, or vice-versa
      even = ! even;
    }
  }
}
