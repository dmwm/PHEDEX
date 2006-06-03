// From A List Apart (www.alistapart.com), "Zebra Tables" in No. 173.

// Work around a bug in IE related to element attributes
function hasClass(obj) {
  var result = null;
  var attr = obj.getAttributeNode("class");
  if (attr != null) { result = attr.value; }
  return result;
}   

function hasColor(obj) {
  var result = null;
  var attr = obj.getAttributeNode("bgcolor");
  if (attr != null) { result = attr.value; }
  return result;
}   

// Strip even/odd rows of a table
function stripe() {
  // default colours to use for even/odd rows
  var evenColor = arguments[0] ? arguments[0] : "#fff";
  var oddColor = arguments[1] ? arguments[1] : "#eee";
  var className = 'striped';
  
  // process all td's in all tr's in all tbody'ies in the table's,
  // but skip all rows and cells which already have set either a
  // "class" attribute or backgroundColor
  var tables = document.getElementsByTagName ("table");
  for (var g = 0; g < tables.length; g++) {
    var even = false; // flag rows even/odd
    var table = tables[g];
    if (hasClass (table) != className) continue;

    var tbodies = table.getElementsByTagName("tbody");
    for (var h = 0; h < tbodies.length; h++) {
      var trs = tbodies[h].getElementsByTagName("tr");
      for (var i = 0; i < trs.length; i++) {
        if (trs[i].getElementsByTagName("th").length) continue;
        if (!hasClass(trs[i]) && ! trs[i].style.backgroundColor) {
          var tds = trs[i].getElementsByTagName("td");
          for (var j = 0; j < tds.length; j++) {
            var mytd = tds[j];
	    if (! hasClass(mytd) && ! hasColor (mytd) && ! mytd.style.backgroundColor)
	      mytd.style.backgroundColor = even ? evenColor : oddColor;
          }
        }
        // flip from odd to even, or vice-versa
        even = ! even;
      }
    }
  }
}
