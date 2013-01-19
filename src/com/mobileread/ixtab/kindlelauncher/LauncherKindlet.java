package com.mobileread.ixtab.kindlelauncher;

import java.awt.BorderLayout;
import java.awt.Component;
import java.awt.Container;
import java.awt.GridLayout;
import ixtab.jailbreak.Jailbreak;

import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.PrintStream;
import java.security.AllPermission;
import java.util.ArrayList;
import java.util.TreeMap;

import com.amazon.kindle.kindlet.AbstractKindlet;
import com.amazon.kindle.kindlet.KindletContext;
import com.mobileread.ixtab.kindlelauncher.ui.UIAdapter;

public class LauncherKindlet extends AbstractKindlet implements ActionListener {

	private static final long serialVersionUID = 1L;

	private final Jailbreak jailbreak = new Jailbreak();
	private KindletContext context;
	private Container panel;
	private TreeMap tm = new TreeMap();
	
	// temporary, for testing.
	private Component status;
	
	public void create(KindletContext context) {
		this.context = context;
	}

	public void destroy() {
		// TODO Auto-generated method stub
		super.destroy();
	}

	
	
	public void start() {
	
		// just in case, it's probably not needed.
		if (panel == null) {
			panel = getUI().newPanel(new BorderLayout());
		} else {
			panel.removeAll();
		}
		
		Container root = context.getRootContainer();
		root.setLayout(new BorderLayout());
		// again, just in case
		root.removeAll();
		
		root.add(panel, BorderLayout.CENTER);
		
		/* everything below here is experimental. */
		root.add(getUI().newLabel("LIST OF APPLICATIONS: (click to run)"), BorderLayout.NORTH);

		GridLayout grid = new GridLayout(0, 1);
		Container buttonsPanel = getUI().newPanel(grid);
		
		jailbreak.enable();
		jailbreak.getContext().requestPermission(new AllPermission());

		
		try {
			
			File file_location = new File("/mnt/us/documents");
			
			String cmd[] = new String[] {"/bin/sh", "parse.sh"}; 
			
			Runtime rtime = Runtime.getRuntime();
			Process processer = rtime.exec(cmd,null,file_location);
			
			processer.waitFor();

		    String line;

		    /* Meh we could do this... processer.getErrorStream() But we don't want the trash
		     * */

	            BufferedReader input = new BufferedReader(new InputStreamReader(processer.getInputStream()));
	            while((line=input.readLine()) != null){
	                
	                /* No doubt there is a better way */
	                String item[]=split2(line,"¬");  
	                
	                /* link the name to the button label */
	            	Component looper = getUI().newButton(item[0], this);
	                
	            	/* Making a list */
	            	tm.put(item[0], item[1]);
	            	
	            	/* a point of reference, meh, it'll do */
	            	looper.setName(item[0]);
	            	
	                buttonsPanel.add(looper);
	            }

	            input.close();
			
	            /* Just in case... */
	            OutputStream outputStream = processer.getOutputStream();
	            PrintStream printStream = new PrintStream(outputStream);
	            printStream.println();
	            printStream.flush();
	            printStream.close();

	            
            } catch(Exception e) {
            e.printStackTrace();
           
        }

		root.add(buttonsPanel, BorderLayout.CENTER);
		
		status = getUI().newLabel("sample label: south");
		root.add(status, BorderLayout.SOUTH);
		
		setStatus(String.valueOf(tm.size()));
	}

	public void stop() {
		// TODO Auto-generated method stub
		super.stop();
	}

	public void actionPerformed(ActionEvent e) {
		Component src = (Component) e.getSource();

		String namer = src.getName();
	
		setStatus(namer);

	      String runner = (String)tm.get(namer);
	      setStatus(runner);
	      try {
				
	      Runtime.getRuntime().exec(runner);
	      } catch (NullPointerException ex) {
				String report = ex.getMessage();// .replaceAll("\\n", "");
				setStatus(report);
			} catch (SecurityException ex) {
				String report = ex.getMessage();// .replaceAll("\\n", "");
				setStatus(report);
			} catch (IOException ex) {
				String report = ex.getMessage();//.replaceAll("\\n", ""); setStatus(report); //
			 setStatus(report);
			 } 
		catch (Throwable ex) {
				String report = ex.getMessage();// .replaceAll("\\n", "");
				setStatus(report);
			}

	     // one ride per customer... ???
	     stop();
	}
	
	private void setStatus(String text) {
		getUI().setText(status, text);
	}

	// pure convenience method.
	private static UIAdapter getUI() {
		return UIAdapter.INSTANCE;
	}
	
		
	// Fixup the lack of handy split method.
	
	   public static String[] split2(String input, String separator){
    	
    	int separatorlen = separator.length();
    	
    	ArrayList arrAux = new ArrayList();
    	String sAux = "" + input;
    	int pos = sAux.indexOf(separator);
    	while (pos>=0){
    		String token = sAux.substring(0,pos);
    		arrAux.add(token);
    		sAux = sAux.substring(pos+separatorlen);
    		pos = sAux.indexOf(separator);
    	}
    	if (sAux.length()>0)
    		arrAux.add(sAux);
    	String[] res = new String[arrAux.size()];
    	for (int i = 0; i<res.length; i++){
    		res[i] = (String)arrAux.get(i);
    	}
    	return res;
    }
	
	
}
