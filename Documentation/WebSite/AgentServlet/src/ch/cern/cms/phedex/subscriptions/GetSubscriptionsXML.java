/*
 * Created on 30-Sep-2004
 *
 * TODO To change the template for this generated file go to
 * Window - Preferences - Java - Code Style - Code Templates
 */
package ch.cern.cms.phedex.subscriptions;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

import org.jdom.Comment;
import org.jdom.Document;
import org.jdom.Element;

import com.senserecords.xml.DatabaseXML;

/**
 * @author Simon
 *
 * TODO To change the template for this generated type comment go to
 * Window - Preferences - Java - Code Style - Code Templates
 */
public class GetSubscriptionsXML {

	public static Document main() {
		try{
			//This gets the number and total size of files in all streams
			String streamsql = "select sum(md.value) as total_size, count(md.guid) as number_of_files, info.stream " +
					" from T_REPLICA_METADATA md, (" +
					" select guid, VALUE as stream from T_REPLICA_METADATA" +
					" where ATTRIBUTE='POOL_dataset'" +
					" and VALUE in (select DISTINCT stream from T_SUBSCRIPTIONS)" +
					" ) info" +
					" where md.guid in(info.guid)" +
					"and md.ATTRIBUTE='filesize'" +
					" group by info.stream";
			
			//This gets the number of files at each destination node
			String destsql = "select subs.destination, subs.stream, DECODE(files.count, null, '0', files.count) as file_count from " +
					"(select DISTINCT destination, stream from T_SUBSCRIPTIONS) subs " +
					"LEFT JOIN " +
					"(select count(guid) as count, NODE from T_REPLICA_STATE " +
					"where guid in (select guid from T_REPLICA_METADATA " +
					"where ATTRIBUTE='POOL_dataset'  " +
					"and VALUE in (select DISTINCT stream from T_SUBSCRIPTIONS)) " +
					"and NODE in(select DISTINCT destination from T_SUBSCRIPTIONS) " +
					"group by NODE) files " +
					"on files.NODE = subs.destination order by subs.destination";
				
			//This gets the details of subscriptions
			String subssql = "select * from T_SUBSCRIPTIONS";
			
			//Connect to the database
			String driverName = "oracle.jdbc.driver.OracleDriver";
			Class.forName(driverName);
			String serverName = "oradev9.cern.ch";
	        	String portNumber = "1521";
	        	String sid = "D9";
	        	String url = "jdbc:oracle:thin:@" + serverName + ":" + portNumber + ":" + sid;
				
			String username = "cms_transfermgmt";
			String password = "smallAND_round";
			Connection conn = DriverManager.getConnection(url, username, password);
			
			//Set up the xml output from database
			DatabaseXML dbxml = new DatabaseXML();
			
			Document out = new Document();
			
			Element root = new Element("root");
			Element dest = new Element("destinations");
			Element stream = new Element("streams");
			Element subs = new Element("subscriptions");
			subs.addContent(dbxml.getRecords(conn, subssql).detachRootElement());
			dest.addContent(dbxml.getRecords(conn, destsql).detachRootElement());
			stream.addContent(dbxml.getRecords(conn, streamsql).detachRootElement());
			root.addContent(stream);
			root.addContent(dest);
			root.addContent(subs);
			
			out.addContent(root);
            return out;
			
		// handle any errors 
		} catch (SQLException ex) {
			Document error = new Document();
			Element root = new Element("error");
			Comment about = new Comment("An SQL exception occured while processing your request. Below is all the information I can gether about the cause.");
			error.addContent(about);
			Element SQLException = new Element("SQLException");
		    SQLException.setText(ex.getMessage());
		    Element SQLState = new Element("SQLState");
		    SQLState.setText(ex.getSQLState()); 
		    Element VendorError = new Element("VendorError");
		    VendorError.setText(String.valueOf(ex.getErrorCode()));
			return error;
	    } catch (Exception ex) {
	    	Document error = new Document();
			Element root = new Element("error");
			Comment about = new Comment("An exception occured while processing your request. Below is all the information I can gether about the cause.");
			error.addContent(about);
			Element xception = new Element("Exception");
		    xception.setText(ex.getMessage());
			return error;
		}	

	}
}
