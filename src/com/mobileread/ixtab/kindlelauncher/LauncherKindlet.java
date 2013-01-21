package com.mobileread.ixtab.kindlelauncher;

import java.awt.BorderLayout;
import java.awt.Component;
import java.awt.Container;
import java.awt.GridLayout;
import ixtab.jailbreak.Jailbreak;

import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
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


		jailbreak.enable();
		jailbreak.getContext().requestPermission(new AllPermission());

		// Tidy up...

		File tmpDir = new File("/tmp");
		String target_file;

		File[] listOfFiles = tmpDir.listFiles();

		for (int i = 0; i < listOfFiles.length; i++) {
			if (listOfFiles[i].isFile()) {
				target_file = listOfFiles[i].getName();
				if (target_file.startsWith("background")) {
					listOfFiles[i].delete();
				}
			}
		}

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

		root.add(getUI().newLabel("APPLICATIONS: "), BorderLayout.NORTH);

		GridLayout grid = new GridLayout(0, 1);
		Container buttonsPanel = getUI().newPanel(grid);

		String tempfilelocation = "";

		try {

			// Internalise the script...
			InputStream is = getClass().getResourceAsStream("/parse.sh");

			File tempFile = java.io.File.createTempFile("parse", "sh");

			tempfilelocation = tempFile.getAbsolutePath();

			OutputStream os = new FileOutputStream(tempFile);

			byte[] buffer = new byte[4096];
			int bytesRead;
			while ((bytesRead = is.read(buffer)) != -1) {
				os.write(buffer, 0, bytesRead);
			}
			buffer = null; // Clear the buffer

			os.flush();
			os.close();
			
			String cmd[] = new String[] { "/bin/sh", tempfilelocation };

			Runtime rtime = Runtime.getRuntime();
			
			// Let's tidy up some known offenders...
			rtime.exec("/usr/bin/killall -9 matchbox-keyboard", null);
			rtime.exec("/usr/bin/killall -9 kterm", null);
			rtime.exec("/usr/bin/killall -9 skipstone", null);
			
			// Okay now now our script.
			Process processer = rtime.exec(cmd, null);// ,file_location);

			processer.waitFor();

			String line;

			BufferedReader input = new BufferedReader(new InputStreamReader(
					processer.getInputStream()));
			while ((line = input.readLine()) != null) {

				String item[] = split2(line, "¬");

				Component looper = getUI().newButton(item[0], this);

				tm.put(item[0], item[1]);
				looper.setName(item[0]);

				buttonsPanel.add(looper);
			}

			input.close();

			OutputStream outputStream = processer.getOutputStream();
			PrintStream printStream = new PrintStream(outputStream);
			printStream.println();
			printStream.flush();
			printStream.close();

			// This doesn't seem to fire when I would expect so... ->
			// tempFile.deleteOnExit();
			tempFile.delete();

		} catch (Exception e) {
			e.printStackTrace();
		}

		root.add(buttonsPanel, BorderLayout.CENTER);

		status = getUI().newLabel(String.valueOf(tm.size()) + " options loaded");
		root.add(status, BorderLayout.SOUTH);

	}

	public void stop() {

		super.stop();
		super.destroy();
	}

	public void actionPerformed(ActionEvent e) {
		Component src = (Component) e.getSource();

		String namer = src.getName();

		String runner = (String) tm.get(namer);

		File tempFile = null;
		try {
			// Make our own background process runner...
			// These get left lying around...
			Runtime rtime = Runtime.getRuntime();
			tempFile = java.io.File.createTempFile("background", "sh");

			BufferedWriter bw = new BufferedWriter(new FileWriter(tempFile));

			bw.write("#!/bin/sh");
			bw.newLine();
			// Here we add our parsed runtime...
			bw.write(runner + " &");
			bw.newLine();
			bw.close();

			String chmodder[] = { "/bin/sh", tempFile.getAbsolutePath() };
			Process slowtime = rtime.exec(chmodder, null);
			slowtime.waitFor();

			setStatus(runner);

		} catch (NullPointerException ex) {
			String report = ex.getMessage();
			setStatus(report);
		} catch (SecurityException ex) {
			String report = ex.getMessage();
			setStatus(report);
		} catch (IOException ex) {
			String report = ex.getMessage();
			setStatus(report);
		} catch (Throwable ex) {
			String report = ex.getMessage();
			setStatus(report);
		}

		try {

			// Until something better turns up...

			Runtime.getRuntime()
					.exec("lipc-set-prop com.lab126.appmgrd stop app://com.lab126.booklet.kindlet");
		} catch (Throwable ex) {
		}

	}

	private void setStatus(String text) {
		getUI().setText(status, text);
	}

	// pure convenience method.
	private static UIAdapter getUI() {
		return UIAdapter.INSTANCE;
	}

	// Fixup the lack of handy split method.

	public static String[] split2(String input, String separator) {

		int separatorlen = separator.length();

		ArrayList arrAux = new ArrayList();
		String sAux = "" + input;
		int pos = sAux.indexOf(separator);
		while (pos >= 0) {
			String token = sAux.substring(0, pos);
			arrAux.add(token);
			sAux = sAux.substring(pos + separatorlen);
			pos = sAux.indexOf(separator);
		}
		if (sAux.length() > 0)
			arrAux.add(sAux);
		String[] res = new String[arrAux.size()];
		for (int i = 0; i < res.length; i++) {
			res[i] = (String) arrAux.get(i);
		}
		return res;
	}

}
