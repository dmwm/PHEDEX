<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:template match="/root">
		<html>
			<head>
				<title>Phedex Stream Subscriptions</title>
				<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1"/>
				<link href="style.css" rel="stylesheet" type="text/css"/>
				<link rel="SHORTCUT ICON" href="favicon.ico"/>
				<link rel="alternate" type="application/rss+xml" title="RSS feed" href="display.html?rss=true"/>
			</head>
			<body>
				<h1>
					<u>Phedex Stream Subscriptions</u>
				</h1>
				<form name="form1" method="post" action="">
					<p>Select T1(s) to edit subscriptions: <select name="select">
							<option selected="true">Select T1:</option>
							<option>-------------</option>
							<xsl:for-each select="all_destinations/results/result_set/row">
								<option>
									<xsl:value-of select="destination"/>
								</option>
							</xsl:for-each>
						</select>
					</p>
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
							<xsl:for-each select="all_destinations/results/result_set/row">
								<td>
									<p align="center" class="tableheading">
										<xsl:value-of select="destination"/>
									</p>
								</td>
							</xsl:for-each>
						</tr>
						<xsl:for-each select="streams/results/result_set/row">
							<tr align="center" valign="middle">
								<td>
									<p align="center">
										<xsl:element name="input">
											<xsl:attribute name="name"><xsl:value-of select="stream"/></xsl:attribute>
											<xsl:attribute name="type">checkbox</xsl:attribute>
											<xsl:attribute name="value">1</xsl:attribute>
										</xsl:element>
									</p>
								</td>
								<td>
									<p align="center">
										<xsl:value-of select="stream"/>
									</p>
								</td>
								<td>
									<p align="center">
										<xsl:value-of select="total_size"/>
									</p>
								</td>
								<td>
									<p align="center">
										<xsl:value-of select="number_of_files"/>
									</p>
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
						</xsl:for-each>
					</table>
					<input type="submit" name="Submit" value="Select"/>
					<input type="reset" name="Reset" value="Reset"/>
				</form>
			</body>
		</html>
	</xsl:template>
</xsl:stylesheet>
