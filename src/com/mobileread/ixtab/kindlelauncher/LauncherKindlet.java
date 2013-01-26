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

	private static final int PAGING_PREVIOUS = -1 ;
	private static final int PAGING_NEXT = 1 ;
	private final TreeMap executablesMap = new TreeMap();

	private KindletContext context;
	private Container entriesPanel;
	private Component status;
	private Component nextPageButton = getUI().newButton("  >  ", this);
	private Component prevPageButton = getUI().newButton("  <  ", this);
	
	private int offset = 0;

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
		
		offset = 0;
		
		try {
			initializeState();
			// FIXME
			populateExecutables();
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
		
		root.add(prevPageButton, BorderLayout.WEST);
		root.add(nextPageButton, BorderLayout.EAST);
		status = getUI().newLabel("Status");
//		root.add(status, BorderLayout.SOUTH);
		
		GridLayout grid = new GridLayout(getPageSize(), 1);
		entriesPanel = getUI().newPanel(grid);
		
		root.add(entriesPanel, BorderLayout.CENTER);
		

//		Iterator execIt = executablesMap.entrySet().iterator();
//		while (execIt.hasNext()) {
//			Map.Entry exec = (Entry) execIt.next();
//			String name = (String) exec.getKey();
//			entriesPanel.add(getUI().newButton(name, this));
//		}
		updateDisplayedLaunchers();


	}

	private void populateExecutables() {
		for (int i=1; i < 23; ++i) {
			executablesMap.put("TEST"+i, "touch /tmp/ex"+i+".tmp");
		}
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
		if (button == prevPageButton) {
			handlePaging(PAGING_PREVIOUS);
		} else if (button == nextPageButton) {
			handlePaging(PAGING_NEXT);
		} else {
			handleLauncherButton(button);
		}
	}

	private void handlePaging(int direction) {
		// direction is supposed to be -1 (backward) or +1 (forward),
		int newOffset = offset + getPageSize() * direction;
		newOffset = Math.max(newOffset, 0);
		newOffset = Math.min(newOffset, getEntriesCount());
		setStatus("offset now: "+newOffset);
		if (newOffset == offset) {
			return;
		}
		offset = newOffset;
		updateDisplayedLaunchers();
	}

	private void updateDisplayedLaunchers() {
		Iterator it = executablesMap.entrySet().iterator();
		// skip entries up to offset
		for (int i=0; i < offset; ++i) {
			if (it.hasNext()) {
				it.next();
			}
		}
		entriesPanel.removeAll();
		for (int i=getPageSize(); i > 0; --i) {
			Component button = getUI().newButton("", null);
			button.setEnabled(false);
			if (it.hasNext()) {
				Map.Entry entry = (Entry) it.next();
				button = getUI().newButton((String) entry.getKey(), this);
			}
			entriesPanel.add(button);
		}
		prevPageButton.setEnabled(offset > 0);
		nextPageButton.setEnabled(offset + getPageSize() < executablesMap.size());
		context.getRootContainer().invalidate();
		context.getRootContainer().repaint();
	}

	private int getEntriesCount() {
		return executablesMap.size();
	}

	private int getPageSize() {
		// this could be extended in the future to account for user-modifiable settings.
		return getUI().getDefaultPageSize();
	}

	private void handleLauncherButton(Component button) {
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
