package com.mobileread.ixtab.kindlelauncher;

import ixtab.jailbreak.Jailbreak;
import ixtab.jailbreak.SuicidalKindlet;

import java.awt.BorderLayout;
import java.awt.Component;
import java.awt.Container;
import java.awt.Font;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.awt.GridLayout;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Iterator;
import java.util.Map;
import java.util.Map.Entry;
import java.util.TreeMap;

import com.amazon.kindle.kindlet.KindletContext;
import com.mobileread.ixtab.kindlelauncher.resources.ResourceLoader;
import com.mobileread.ixtab.kindlelauncher.ui.UIAdapter;

public class LauncherKindlet extends SuicidalKindlet implements ActionListener {


	public static final String RESOURCE_PARSER_SCRIPT = "parse.sh";
	private static final String EXEC_PREFIX_PARSE = "klauncher_parse-";
	private static final String EXEC_PREFIX_BACKGROUND = "klauncher_background-";
	private static final String EXEC_EXTENSION_SH = ".sh";
	private static final long serialVersionUID = 1L;

	private final TreeMap executablesMap = new TreeMap();

	// temporary, for testing.
	private KindletContext context;
	private Container panel;
	private Component status;

	protected Jailbreak instantiateJailbreak() {
		return new LauncherKindletJailbreak();
	}
	
	public void onCreate(KindletContext context) {
		super.onCreate(context);
		this.context = context;
	}

	public void onStart() {
		super.onStart();

		String error = getJailbreakError();
		if (error != null) {
			displayErrorMessage(error);
			return;
		}
		
		try {
			initializeState();
			initializeUI();
		} catch (Throwable t) {
			throw new RuntimeException(t);
		}
		
	}

	private void setStatus(String text) {
		getUI().setText(status, text);
	}

	private static UIAdapter getUI() {
		return UIAdapter.INSTANCE;
	}

	private void initializeUI() {
		Container root = context.getRootContainer();
		root.removeAll();
		
		root.setLayout(new BorderLayout());

		// probably over-cautious
		if (panel == null) {
			panel = getUI().newPanel(new BorderLayout());
		}
		panel.removeAll();
		root.add(panel, BorderLayout.CENTER);

		/* everything below here is experimental. */

		root.add(getUI().newLabel("APPLICATIONS: "), BorderLayout.NORTH);

		GridLayout grid = new GridLayout(0, 1);
		Container buttonsPanel = getUI().newPanel(grid);

		//FIXME
		executablesMap.put("AAA", "touch /tmp/AAA.tmp");
		executablesMap.put("ZZZ", "touch /tmp/ZZZ.tmp");
		Iterator execIt = executablesMap.entrySet().iterator();
		while (execIt.hasNext()) {
			Map.Entry exec = (Entry) execIt.next();
			String name = (String) exec.getKey();
			buttonsPanel.add(getUI().newButton(name, this));
		}

		root.add(buttonsPanel, BorderLayout.CENTER);

		status = getUI().newLabel(String.valueOf(executablesMap.size()) + " options loaded");
		root.add(status, BorderLayout.SOUTH);
		
	}

	private void initializeState() throws IOException, FileNotFoundException,
			InterruptedException {
		cleanupTemporaryDirectory();
		killKnownOffenders(Runtime.getRuntime());
		
		File parseFile = extractParseFile();
		BufferedReader reader = Util.execute(parseFile.getAbsolutePath());

		for (String line = reader.readLine(); line != null; line = reader.readLine()) {
			String item[] = Util.splitLine(line, "¬");
			executablesMap.put(item[0], item[1]);
		}
		
		reader.close();
		parseFile.delete();
	}

	private File extractParseFile() throws IOException, FileNotFoundException {
		InputStream script = ResourceLoader.load(RESOURCE_PARSER_SCRIPT);
		File parseInput = File.createTempFile(EXEC_PREFIX_PARSE, EXEC_EXTENSION_SH);
		
		OutputStream cmd = new FileOutputStream(parseInput);
		Util.copy(script, cmd);
		return parseInput;
	}

	private void displayErrorMessage(String error) {
		Container root = context.getRootContainer();
		root.removeAll();
		
		Component message = getUI().newLabel(error);
		message.setFont(new Font(message.getFont().getName(), Font.BOLD, message.getFont().getSize() + 6));
		root.setLayout(new GridBagLayout());
		
		GridBagConstraints gbc = new GridBagConstraints();
		gbc.gridx = 0;
		gbc.fill = GridBagConstraints.HORIZONTAL;
		gbc.fill |= GridBagConstraints.VERTICAL;
		gbc.weightx  = 1.0;
		gbc.weighty  = 1.0;
		
		root.add(message, gbc);
	}

	private void killKnownOffenders(Runtime rtime) throws IOException {
		// Let's tidy up some known offenders...
		rtime.exec("/usr/bin/killall -9 matchbox-keyboard", null);
		rtime.exec("/usr/bin/killall -9 kterm", null);
		rtime.exec("/usr/bin/killall -9 skipstone", null);
	}

	

	private void cleanupTemporaryDirectory() {
		File tmpDir = new File("/tmp");

		File[] files = tmpDir.listFiles();

		for (int i = 0; i < files.length; i++) {
			if (files[i].isFile()) {
				String file = files[i].getName();
				if (file.startsWith(EXEC_PREFIX_BACKGROUND)) {
					files[i].delete();
				}
			}
		}
	}

	private String getJailbreakError() {
		if (!jailbreak.isAvailable()) {
			return "Kindlet Jailbreak not installed";
		}
		if (!jailbreak.isEnabled()) {
			return "Kindlet Jailbreak could not be enabled";
		}
		return null;
	}

	public void actionPerformed(ActionEvent e) {
		Component button = (Component) e.getSource();

		String cmd = (String) executablesMap.get(button.getName());

		try {
			// Make our own background process runner...
			// These get left lying around...
			Runtime rtime = Runtime.getRuntime();
			File tempFile = java.io.File.createTempFile(EXEC_PREFIX_BACKGROUND, EXEC_EXTENSION_SH);

			BufferedWriter bw = new BufferedWriter(new FileWriter(tempFile));

			bw.write("#!/bin/sh");
			bw.newLine();
			// Here we add our parsed runtime...
			bw.write(cmd + " &");
			bw.newLine();
			bw.close();

			String chmodder[] = { "/bin/sh", tempFile.getAbsolutePath() };
			Process slowtime = rtime.exec(chmodder, null);
			slowtime.waitFor();
			setStatus(cmd);
			
			getUI().suicide(context);
		} catch (Throwable ex) {
			String report = ex.getMessage();
			setStatus(report);
		}
		
	}
}
