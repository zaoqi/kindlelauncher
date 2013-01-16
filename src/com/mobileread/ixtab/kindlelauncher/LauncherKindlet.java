package com.mobileread.ixtab.kindlelauncher;

import ixtab.jailbreak.Jailbreak;

import java.awt.BorderLayout;
//import java.awt.Button;
import java.awt.Component;
import java.awt.Container;
import java.awt.GridLayout;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.File;
//import java.io.IOException;
import java.security.AllPermission;
import java.util.ArrayList;
import java.util.Iterator;

import javax.swing.JButton;

import com.amazon.kindle.kindlet.AbstractKindlet;
import com.amazon.kindle.kindlet.KindletContext;
//import com.mobileread.ixtab.kindlelauncher.util.FileUtil;
import com.mobileread.ixtab.kindlelauncher.util.ExtensionsLoader;
import com.mobileread.ixtab.kindlelauncher.util.Extension;
import com.mobileread.ixtab.kindlelauncher.ui.UIAdapter;

public class LauncherKindlet extends AbstractKindlet implements ActionListener {

	private final Jailbreak jailbreak = new Jailbreak();

	private KindletContext context;
	private Container panel;
	private String runthing;

	// temporary, for testing.
	private Component button1, button2, status;

	private static final long serialVersionUID = 1L;

	private File mScript;
	private String mArgs;

	/**
	 * Creates a new launch script menu item.
	 * 
	 * @param name
	 *            The text to show
	 * @param priority
	 *            The order of this item in comparison to others
	 * @param script
	 *            The shell script or command to run
	 * @param args
	 *            The arguments of the script
	 */
	// public LauncherScript(String name, int priority, File script, String
	// args) {
	// super(name, priority);

	// }

	private ArrayList mExtensions;
	/**
	 * The default {@link ExtensionsLoader} that reads from /mnt/us/extensions
	 */
	private static final ExtensionsLoader EXTENSIONS_LOADER = new ExtensionsLoader(
			new File("/mnt/us/extensions"));

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

		// FIXME We want to grab out the values parsed and run them like below.

		// this.mScript = script;
		// this.mArgs = args;

		/**
		 * Let's setup some useful file readers for the future
		 */

		// FileUtil filer = new FileUtil();
		runthing = "/mnt/us/usr/bin/soundkloud";

		jailbreak.enable();
		jailbreak.getContext().requestPermission(new AllPermission());

		Container root = context.getRootContainer();
		root.setLayout(new BorderLayout());
		// again, just in case
		root.removeAll();

		root.add(panel, BorderLayout.CENTER);

		try {

			/**
			 * Loads the extensions using {@link ExtensionsLoader}
			 */
			// FIXME GAH!!! why is this returning no results???
			mExtensions = EXTENSIONS_LOADER.loadExtensions(); //

		} catch (Throwable ex) {
			root.add(getUI().newLabel("exception!!: " + ex.getMessage()),
					BorderLayout.NORTH);
		}

		/* everything below here is experimental. */
		root.add(getUI().newLabel("sample label: north"), BorderLayout.NORTH);

		// those "200" bits are also only for testing.
		// GridLayout grid = new GridLayout(2, 1, 200, 200);

		GridLayout grid = new GridLayout(mExtensions.size() + 2, 1);
		Container buttonsPanel = getUI().newPanel(grid);

		button1 = getUI().newButton("BUTTON 1", this);

		try {

			if (!mExtensions.isEmpty()) {
				Iterator it = mExtensions.iterator();
				while (it.hasNext()) {
					Extension ext = (Extension) it.next();
					buttonsPanel.add(
							getUI().newButton(
									ext.getId() + ") " + ext.getName(), this),
							BorderLayout.NORTH);
				}
			} else {
				buttonsPanel.add(getUI().newButton("was empty", this),
						BorderLayout.NORTH);

			}

		} catch (Throwable ex) {
		}

		button2 = getUI().newButton("BUTTON 2", this);
		buttonsPanel.add(button1);
		buttonsPanel.add(button2);

		root.add(buttonsPanel, BorderLayout.CENTER);

		status = getUI().newLabel("sample label: south - STATUS");
		root.add(status, BorderLayout.SOUTH);
	}

	public void stop() {
		// TODO Auto-generated method stub
		super.stop();
	}

	public void actionPerformed(ActionEvent e) {
		Object src = e.getSource();
		// if (src == button1) {
		// setStatus("button 1 was pressed");
		//
		// } else if (src == button2) {
		// setStatus("button 2 was pressed");

		//FIXME Currently this does nothing useful. Just holds a bit of logic to nastily grab values to status from a button on a 5.
		
		try {
			// This kinda thing???
			// Runtime.getRuntime().exec(((Button)src).getLabel().trim());

			// FIXME Make this grab the right type from the UI adaptor
			String report = ((JButton) src).getText();

			setStatus(report);

		} catch (NullPointerException ex) {
			String report = ex.getMessage();// .replaceAll("\\n", "");
			setStatus(report);
		} catch (SecurityException ex) {
			String report = ex.getMessage();// .replaceAll("\\n", "");
			setStatus(report);
		}
		/*
		 * catch (IOException ex) { String report =
		 * ex.getMessage();//.replaceAll("\\n", ""); setStatus(report); //
		 * setStatus(ex.getMessage()); }
		 */
		catch (Throwable ex) {
			String report = ex.getMessage();// .replaceAll("\\n", "");
			setStatus(report);
		}
		// };
	}

	private void setStatus(String text) {
		getUI().setText(status, text);
	}

	// pure convenience method.
	private static UIAdapter getUI() {
		return UIAdapter.INSTANCE;
	}
}
