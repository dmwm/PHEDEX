/*
 * Created on 22-Jul-2004
 */
package ch.cern.cms.phedex.control;

import java.io.IOException;
import java.io.PrintWriter;
import java.sql.*;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
/**
 * @author Simon Metson
 */
public class Control extends HttpServlet{
	public void doGet(HttpServletRequest request, HttpServletResponse response)
    throws IOException, ServletException   {
		//Need to check referrer and have some kind of log in thing here.
		try{
			String driverName = "oracle.jdbc.driver.OracleDriver";
			Class.forName(driverName);
			String serverName = "oradev9.cern.ch";
            String portNumber = "1521";
            String sid = "D9";
            String url = "jdbc:oracle:thin:@" + serverName + ":" + portNumber + ":" + sid;
			
			String username = "cms_transfermgmt";
            String password = "smallAND_round";
            
            
            String sql = "UPDATE t_lookup SET state = '" + request.getParameter("st") +
        	"' WHERE node='" + request.getParameter("nd") +
        	"' AND agent='" + request.getParameter("ag") +"'";
            
            Connection conn = DriverManager.getConnection(url, username, password);
            Statement stmt = conn.createStatement();
		    ResultSet rs = stmt.executeQuery(sql);
		    response.sendRedirect("status.html");
        } catch (SQLException ex) {
            // handle any errors 
        	PrintWriter output = response.getWriter ();
        	output.println("<h1>SQL Error</h1>");
        	output.println("<p>");
        	output.println("SQLException: " + ex.getMessage()); 
        	output.println("SQLState: " + ex.getSQLState()); 
        	output.println("VendorError: " + ex.getErrorCode());
        	output.println("</p>");
        } catch (Exception ex) {
        	PrintWriter output = response.getWriter ();
            ex.printStackTrace(output);
        }
	}
	public void doPost(HttpServletRequest request, HttpServletResponse response)
    throws IOException, ServletException   {
		try{
			String driverName = "oracle.jdbc.driver.OracleDriver";
			Class.forName(driverName);
			String serverName = "oradev9.cern.ch";
            String portNumber = "1521";
            String sid = "D9";
            String url = "jdbc:oracle:thin:@" + serverName + ":" + portNumber + ":" + sid;
			
			String username = "cms_transfermgmt";
            String password = "smallAND_round";
            
            
            String sql = "UPDATE t_lookup SET state = '" + request.getParameter("st") +
            	"' WHERE node='" + request.getParameter("nd") +
            	"' AND agent='" + request.getParameter("ag") +"'";
            
            Connection conn = DriverManager.getConnection(url, username, password);
            Statement stmt = conn.createStatement();
		    ResultSet rs = stmt.executeQuery(sql);
		    response.sendRedirect("status.html");
        } catch (SQLException ex) {
            // handle any errors 
        	PrintWriter output = response.getWriter ();
        	output.println("<h1>SQL Error</h1>");
        	output.println("<p>");
        	output.println("SQLException: " + ex.getMessage()); 
        	output.println("SQLState: " + ex.getSQLState()); 
        	output.println("VendorError: " + ex.getErrorCode());
        	output.println("</p>");
        } catch (Exception ex) {
        	PrintWriter output = response.getWriter ();
            ex.printStackTrace(output);
        }
	}
}
