/*
 * Created on 30-Sep-2004
 *
 * TODO To change the template for this generated file go to
 * Window - Preferences - Java - Code Style - Code Templates
 */
package ch.cern.cms.phedex.subscriptions;

import org.jdom.output.*;
/**
 * @author Simon
 *
 * Simple test of the GetSubscriptionsXML class
 * as opposed to using the Tomcat server
 * 
 */
public class Tester {

	public static void main(String[] args) {
		try{
			System.out.println();
			XMLOutputter outputter = new XMLOutputter(Format.getPrettyFormat());
			outputter.output(GetSubscriptionsXML.main(), System.out);
		}catch (Exception e){
			e.printStackTrace();
		}
		
	}
}
