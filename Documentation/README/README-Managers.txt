{\rtf1\mac\ansicpg10000\uc1\deff0\stshfdbch0\stshfloch0\stshfhich0\stshfbi0\deflang1033\deflangfe1033{\upr{\fonttbl{\f0\fnil\fcharset256\fprq2{\*\panose 00020206030504050203}Times New Roman;}
}{\*\ud{\fonttbl{\f0\fnil\fcharset256\fprq2{\*\panose 00020206030504050203}Times New Roman;}}}}{\colortbl;\red0\green0\blue0;\red0\green0\blue255;\red0\green255\blue255;\red0\green255\blue0;\red255\green0\blue255;\red255\green0\blue0;
\red255\green255\blue0;\red255\green255\blue255;\red0\green0\blue128;\red0\green128\blue128;\red0\green128\blue0;\red128\green0\blue128;\red128\green0\blue0;\red128\green128\blue0;\red128\green128\blue128;\red192\green192\blue192;}{\stylesheet{
\ql \li0\ri0\widctlpar\aspalpha\aspnum\faauto\adjustright\rin0\lin0\itap0 \lang2057\langfe1033\cgrid\langnp2057\langfenp1033 \snext0 Normal;}{\*\cs10 \additive Default Paragraph Font;}{\*
\ts11\tsrowd\trftsWidthB3\trpaddl108\trpaddr108\trpaddfl3\trpaddft3\trpaddfb3\trpaddfr3\trcbpat1\trcfpat1\tscellwidthfts0\tsvertalt\tsbrdrt\tsbrdrl\tsbrdrb\tsbrdrr\tsbrdrdgl\tsbrdrdgr\tsbrdrh\tsbrdrv 
\ql \li0\ri0\widctlpar\aspalpha\aspnum\faauto\adjustright\rin0\lin0\itap0 \fs20\lang1024\langfe1024\cgrid\langnp1024\langfenp1024 \snext11 Normal Table;}{\*\cs15 \additive \ul\cf2 \sbasedon10 \styrsid4148593 Hyperlink;}}{\*\rsidtbl \rsid4148593}{\info
{\author Tim Barrass}{\operator Tim Barrass}{\creatim\yr2004\mo8\dy19\min36}{\revtim\yr2004\mo8\dy19\min56}{\version3}{\edmins14}{\nofpages2}{\nofwords321}{\nofchars1835}{\*\company University of Bristol}{\nofcharsws2253}{\vern24577}}
\ftnbj\aenddoc\noxlattoyen\expshrtn\noultrlspc\dntblnsbdb\nospaceforul\formshade\horzdoc\dghspace180\dgvspace180\dghorigin1701\dgvorigin1984\dghshow0\dgvshow0
\jexpand\viewkind1\viewscale100\pgbrdrhead\pgbrdrfoot\splytwnine\ftnlytwnine\htmautsp\nolnhtadjtbl\useltbaln\alntblind\lytcalctblwd\lyttblrtgr\lnbrkrule\nobrkwrptbl\rsidroot12669697 \fet0\sectd 
\linex0\headery708\footery708\colsx708\endnhere\sectdefaultcl\sectrsid12669697\sftnbj {\*\pnseclvl1\pnucrm\pnstart1\pnindent720\pnhang{\pntxta .}}{\*\pnseclvl2\pnucltr\pnstart1\pnindent720\pnhang{\pntxta .}}{\*\pnseclvl3\pndec\pnstart1\pnindent720\pnhang
{\pntxta .}}{\*\pnseclvl4\pnlcltr\pnstart1\pnindent720\pnhang{\pntxta )}}{\*\pnseclvl5\pndec\pnstart1\pnindent720\pnhang{\pntxtb (}{\pntxta )}}{\*\pnseclvl6\pnlcltr\pnstart1\pnindent720\pnhang{\pntxtb (}{\pntxta )}}{\*\pnseclvl7
\pnlcrm\pnstart1\pnindent720\pnhang{\pntxtb (}{\pntxta )}}{\*\pnseclvl8\pnlcltr\pnstart1\pnindent720\pnhang{\pntxtb (}{\pntxta )}}{\*\pnseclvl9\pnlcrm\pnstart1\pnindent720\pnhang{\pntxtb (}{\pntxta )}}\pard\plain 
\ql \li0\ri0\widctlpar\aspalpha\aspnum\faauto\adjustright\rin0\lin0\itap0 \lang2057\langfe1033\cgrid\langnp2057\langfenp1033 {\insrsid4148593 Using Manager scripts
\par ================
\par 
\par The manager scripts allow you to perform basic management functions on the TMDB: add new nodes, remove nodes, make new neighbour-links; reallocate files already placed in distribution based on source node, destination node or POOL_dataset.
\par 
\par The manager scripts are
\par 
\par + NodeManager.pl
\par \tab Used to manage node entries in the TMDB.
\par + ReallocationManager.pl
\par }\pard \ql \li720\ri0\widctlpar\aspalpha\aspnum\faauto\adjustright\rin0\lin720\itap0\pararsid4148593 {\insrsid4148593 Used to reallocate files already in distribution to new destinations, and retrigger distribution.
\par }\pard \ql \li0\ri0\widctlpar\aspalpha\aspnum\faauto\adjustright\rin0\lin0\itap0\pararsid4148593 {\insrsid4148593 
\par 
\par 
\par Typical tasks that you might want to perform include:
\par ----------------
\par 
\par + Add a new node
\par Assume that you have a node A, and want to add a neighbour, B-
\par 
\par ./NodeManager.pl add-node \\\\
\par \tab -name B \\\\
\par \tab -host b-host.some.internet.address \\\\
\par \tab -cat }{\field{\*\fldinst {\insrsid4148593  HYPERLINK "http://cat-contact-string" }{\insrsid4148593 {\*\datafield 
00d0c9ea79f9bace118c8200aa004ba90b02000000170000001a00000068007400740070003a002f002f006300610074002d0063006f006e0074006100630074002d0073007400720069006e0067000000e0c9ea79f9bace118c8200aa004ba90b3400000068007400740070003a002f002f006300610074002d0063006f00
6e0074006100630074002d0073007400720069006e0067000000}}}{\fldrslt {\cs15\ul\cf2\insrsid4148593\charrsid6703026 http://cat-contact-string}}}{\insrsid4148593  \\\\
\par \tab -neighbours A
\par \tab -db theDBTNSname \\\\
\par \tab -user DBusername \\\\
\par \tab -password DBpassword
\par 
\par if you want the new node to have multiple neighbours, create a comma delimited list, for example
\par \tab 
\par \tab -neighbours A,X,Y,Z
\par 
\par + Remove a node
\par And assume you want to remove it again
\par 
\par ./NodeManager.pl remove-node \\\\
\par \tab -name B \\\\
\par \tab -db theDBTNSname \\\\
\par \tab -user DBusername \\\\
\par \tab -password DBpassword
\par 
\par These are relatively trivial cases- more complicated cases need more work. For example
\par 
\par ! Break link and add
\par Imagine you have the existing network A-B, and you want to add C between A and B to create A-C-B. First you need to remove the existing link, then create the new node.
\par 
\par ./NodeManager.pl remove-link \\\\
\par \tab -name B \\\\
\par \tab -neighbours A
\par \tab -db theDBTNSname \\\\
\par \tab -user DBusername \\\\
\par \tab -password DBpassword
\par 
\par ./NodeManager.pl add-node \\\\
\par \tab -name C \\\\
\par \tab -host b-host.some.internet.address \\\\
\par \tab -cat }{\field{\*\fldinst {\insrsid4148593  HYPERLINK "http://cat-contact-string" }{\insrsid4148593 {\*\datafield 
00d0c9ea79f9bace118c8200aa004ba90b0200000003000000e0c9ea79f9bace118c8200aa004ba90b3400000068007400740070003a002f002f006300610074002d0063006f006e0074006100630074002d0073007400720069006e0067000000}}}{\fldrslt {\cs15\ul\cf2\insrsid4148593\charrsid6703026 
http://cat-contact-string}}}{\insrsid4148593  \\\\
\par \tab -neighbours A,B
\par \tab -db theDBTNSname \\\\
\par \tab -user DBusername \\\\
\par \tab -password DBpassword
\par 
\par ! Remove linking node and restore/ create link
\par Imagine that you\rquote ve gone throught he above process but want to remove C- then you need to remove C first, then restore the A-B link
\par 
\par ./NodeManager.pl remove-node \\\\
\par \tab -name B \\\\
\par \tab -db theDBTNSname \\\\
\par \tab -user DBusername \\\\
\par \tab -password DBpassword
\par 
\par ./NodeManager.pl new-neighbours \\\\
\par \tab -name B \\\\
\par \tab -neighbours A
\par \tab -db theDBTNSname \\\\
\par \tab -user DBusername \\\\
\par \tab -password DBpassword
\par }{\insrsid12669697 
\par }}