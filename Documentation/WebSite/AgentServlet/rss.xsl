<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:template match="/">
		<html>
			<head>
				<title>Phedex Stream Subscriptions</title>
				<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1"/>
				<link href="style.css" rel="stylesheet" type="text/css"/>
				<LINK REL="SHORTCUT ICON" HREF="favicon.ico"/>
			</head>
			<body>
				<h1>
					<u>Phedex Stream Subscriptions</u>
				</h1>
				<form name="form1" method="post" action="">
					<input type="submit" name="Submit" value="Select"/>
					<input type="reset" name="Reset" value="Reset"/>
					<table width="100%" border="0" cellspacing="0" cellpadding="3">
						<tr align="center" valign="middle" bgcolor="#006633">
							<td width="15">
								<p align="center" class="tableheading">Select</p>
							</td>
							<td>
								<p align="center" class="tableheading">Stream</p>
							</td>
							<td>
								<p align="center" class="tableheading">Size</p>
							</td>
							<td bgcolor="#006633">
								<p align="center" class="tableheading"># of files</p>
							</td>
							<xsl:for-each select="/root/destinations/results/result_set/row">
								<td>
									<p align="center" class="tableheading">
										<xsl:value-of select="destination"/>
									</p>
								</td>
							</xsl:for-each>
						</tr>
						<tr align="center" valign="middle">
							<td>
								<p align="center">
									<input type="checkbox" name="checkbox" value="checkbox"/>
								</p>
							</td>
							<td>
								<p align="center">Simon's dataset</p>
							</td>
							<td>
								<p align="center">100M</p>
							</td>
							<td>
								<p align="center">100</p>
							</td>
							<td valign="top">
								<p align="center">
									<img src="tick.jpg"/>
								</p>
							</td>
							<td valign="top">
								<p align="center">
									<img src="cross.jpg"/>
								</p>
							</td>
							<td valign="top">
								<p align="center">
									<img src="cross.jpg"/>
								</p>
							</td>
							<td valign="top">
								<p align="center">
									<img src="cross.jpg"/>
								</p>
							</td>
							<td valign="top">
								<p align="center">
									<img src="cross.jpg"/>
								</p>
							</td>
							<td valign="top">
								<p align="center">
									<img src="tick.jpg"/>
								</p>
							</td>
							<td valign="top">
								<p align="center">
									<img src="tick.jpg"/>
								</p>
							</td>
						</tr>
					</table>
					<input type="submit" name="Submit" value="Select"/>
					<input type="reset" name="Reset" value="Reset"/>
				</form>
			</body>
		</html>
	</xsl:template>
</xsl:stylesheet>
