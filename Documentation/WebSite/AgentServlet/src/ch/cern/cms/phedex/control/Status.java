/*
 * Created on 16-Jul-2004
 */
package ch.cern.cms.phedex.control;

import java.io.IOException;
import java.io.PrintWriter;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.jdom.Document;
import org.jdom.output.Format;
import org.jdom.output.XMLOutputter;
import org.jdom.transform.XSLTransformer;

import com.senserecords.xml.DatabaseXML;

/**
 * @author Simon Metson
 */
public class Status  extends HttpServlet{

	public void doGet(HttpServletRequest request, HttpServletResponse response)
    throws IOException, ServletException   {
		try{
			String sql = "select a.node_name, a.host_string as host, b.agent, " +
					"DECODE(b.state, 1, 'OK', 2, 'WARNING', 3, 'DOWN', b.state) AS agent_state, " +
					"DECODE(c.host_state, 1, 'OK', 2, 'WARNING', 3, 'DOWN', c.host_state) AS host_state " +
			"from t_nodes a, t_Lookup b, " +
				"(select a1.host_string, max(b1.state) AS host_state " +
				"from t_nodes a1, t_Lookup b1 " +
				"where a1.node_name = b1.node " + 
				"GROUP by a1.host_string) c " +
			"where a.node_name = b.node AND a.host_string = c.host_string " +
			"ORDER by c.host_state DESC, a.host_string ";
			
			String driverName = "oracle.jdbc.driver.OracleDriver";
			Class.forName(driverName);
			String serverName = "oradev9.cern.ch";
            String portNumber = "1521";
            String sid = "D9";
            String url = "jdbc:oracle:thin:@" + serverName + ":" + portNumber + ":" + sid;
			
			String username = "cms_transfermgmt";
            String password = "smallAND_round";
            Connection conn = DriverManager.getConnection(url, username, password);
            
			DatabaseXML test = new DatabaseXML();
            XMLOutputter outputter = new XMLOutputter();
            outputter.setFormat(Format.getPrettyFormat());
            
            XSLTransformer transformer = new XSLTransformer("http://project-bristol-cms-grid.web.cern.ch/project-bristol-cms-grid/nodes.xsl");
            Document out = transformer.transform(test.getRecords(conn, sql));
            
            PrintWriter output = response.getWriter ();
            
            outputter.output(out, output);
            //outputter.output(test.getRecords(conn, sql), System.out);
            
		}catch (IOException e) {
			PrintWriter output = response.getWriter ();
			output.println(e.getMessage());
			e.printStackTrace(output);   
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
	public void doPost( HttpServletRequest request, HttpServletResponse response) throws IOException, ServletException {
		doGet(request,response);
	}
}
