/*
 * Created on 23-Sep-2004
 */
package ch.cern.cms.phedex.subscriptions;

import java.io.IOException;
import java.io.InputStream;
import java.net.URL;

import javax.servlet.ServletException;
import javax.servlet.ServletOutputStream;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.jdom.Comment;
import org.jdom.Document;
import org.jdom.Element;
import org.jdom.output.Format;
import org.jdom.output.XMLOutputter;
import org.jdom.transform.XSLTransformException;
import org.jdom.transform.XSLTransformer;

/**
 * @author Simon Metson
 */
public class DisplaySubscriptions extends HttpServlet{
	public void doGet(HttpServletRequest request, HttpServletResponse response)
    throws IOException, ServletException   {
		ServletOutputStream output = response.getOutputStream();
		try{
			if (request.getParameter("xml") != null){
				//Do no transform
				XMLOutputter outputter = new XMLOutputter();
				outputter.setFormat(Format.getPrettyFormat());
				outputter.output(GetSubscriptionsXML.main(), output);
			}else if(request.getParameter("rss") != null){
				InputStream xsl = new URL("http://tuber1.phy.bris.ac.uk:8080/AgentServlet/rss.xsl").openStream();
				XSLTransformer transformer = new XSLTransformer(xsl);
				XMLOutputter outputter = new XMLOutputter();
				outputter.setFormat(Format.getPrettyFormat());
				outputter.output(transformer.transform(GetSubscriptionsXML.main()), output);
			}else{
				InputStream xsl = new URL("http://tuber1.phy.bris.ac.uk:8080/AgentServlet/subs.xsl").openStream();
				XSLTransformer transformer = new XSLTransformer(xsl);
				XMLOutputter outputter = new XMLOutputter();
				outputter.setFormat(Format.getPrettyFormat());
				outputter.output(transformer.transform(GetSubscriptionsXML.main()), output);
			}
		}catch (XSLTransformException xte){
			Document error = new Document();
			Element root = new Element("error");
			Comment about = new Comment("An exception occured while processing your request. Below is all the information I can gether about the cause.");
			error.addContent(about);
			Element xception = new Element("Exception");
		    xception.setText(xte.getMessage());
			XMLOutputter outputter = new XMLOutputter(Format.getPrettyFormat());
		    outputter.output(error, response.getOutputStream());
		}
	}
	
	public void doPost(HttpServletRequest request, HttpServletResponse response)
    throws IOException, ServletException   {doGet(request,response);}
}
