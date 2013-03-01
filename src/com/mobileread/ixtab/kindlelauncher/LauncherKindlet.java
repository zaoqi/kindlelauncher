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
import java.util.LinkedHashMap;
import java.util.HashMap;
import java.util.Map;
import java.util.Map.Entry;

import com.amazon.kindle.kindlet.KindletContext;
import com.mobileread.ixtab.kindlelauncher.resources.ResourceLoader;
import com.mobileread.ixtab.kindlelauncher.ui.UIAdapter;

public class LauncherKindlet extends SuicidalKindlet implements ActionListener {

	public static final String RESOURCE_PARSER_SCRIPT = "parse.sh";
	private static final String EXEC_PREFIX_PARSE = "klauncher_parse-";
	private static final String EXEC_PREFIX_BACKGROUND = "klauncher_background-";
	private static final String EXEC_EXTENSION_SH = ".sh";
	private static final long serialVersionUID = 1L;

	private static final int PAGING_PREVIOUS = -1;
	private static final int PAGING_NEXT = 1;
	private final LinkedHashMap executablesMap = new LinkedHashMap();
	private final HashMap trackerMap = new HashMap();
	private File parseFile;

	private KindletContext context;
	private boolean started = false;
	private String commandToRunOnExit = null;

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
		/*
		 * This method might be called multiple times, but we only need to
		 * initialize once. See Kindlet lifecycle diagram:
		 */
		// https://kdk-javadocs.s3.amazonaws.com/2.0/com/amazon/kindle/kindlet/Kindlet.html

		if (started) {
			return;
		}
		super.onStart();
		started = true;

		String error = getJailbreakError();
		if (error != null) {
			displayErrorMessage(error);
			return;
		}

		offset = 0;

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

		root.add(prevPageButton, BorderLayout.WEST);
		root.add(nextPageButton, BorderLayout.EAST);
		status = getUI().newLabel("Status");
		root.add(status, BorderLayout.SOUTH);

		GridLayout grid = new GridLayout(getPageSize(), 1);
		entriesPanel = getUI().newPanel(grid);

		root.add(entriesPanel, BorderLayout.CENTER);

		// FOR TESTING ONLY, if a specific number of entries is needed.
		// for (int i = 0; i < 25; ++i) {
		// executablesMap.put("TEST-" + i, "touch /tmp/test-" + i + ".tmp");
		// }

		updateDisplayedLaunchers();

	}

	private void initializeState() throws IOException, FileNotFoundException,
			InterruptedException, NumberFormatException {
		cleanupTemporaryDirectory();
		killKnownOffenders(Runtime.getRuntime());

		//File parseFile = extractParseFile();
		parseFile = extractParseFile();
		BufferedReader reader = Util.execute(parseFile.getAbsolutePath());

		String spaces = new String(new char[16]).replace('\0', ' ');
		TheReading:
		for (String line = reader.readLine(); line != null; line = reader
				.readLine()) {
			String label = ""; String action = "";
			switch (Integer.parseInt(line)) {
				case 4: reader.readLine(); // cindex <= parse.sh -c not used
				case 3: label = reader.readLine() + " · "; // group
				case 2: label = label + reader.readLine();
					if (trackerMap.containsKey(label)) { // make unique key for executablesMap
						int n = Integer.parseInt((String) trackerMap.get(label));
						trackerMap.put(label, Integer.toString(++n));
						label = label + spaces.substring(0,n);
					} else {
						trackerMap.put(label, "0");
					}
				        action = reader.readLine();
				        executablesMap.put(label, action);
					break;
				default: executablesMap.put("err bad meta", "true");
					break TheReading; // can't trust input format
			}
		}

		reader.close();
		//parseFile.delete(); //stepk: leave script in place to provide for backdoor option -e
		parseFile.deleteOnExit(); //stepk: kindlet deletes on clean exit & parse.sh deletes leftovers
	}

	private File extractParseFile() throws IOException, FileNotFoundException {
		InputStream script = ResourceLoader.load(RESOURCE_PARSER_SCRIPT);
		File parseInput = File.createTempFile(EXEC_PREFIX_PARSE,
				EXEC_EXTENSION_SH);

		OutputStream cmd = new FileOutputStream(parseInput);
		Util.copy(script, cmd);
		return parseInput;
	}

	private void displayErrorMessage(String error) {
		Container root = context.getRootContainer();
		root.removeAll();

		Component message = getUI().newLabel(error);
		message.setFont(new Font(message.getFont().getName(), Font.BOLD,
				message.getFont().getSize() + 6));
		root.setLayout(new GridBagLayout());

		GridBagConstraints gbc = new GridBagConstraints();
		gbc.gridx = 0;
		gbc.fill = GridBagConstraints.HORIZONTAL;
		gbc.fill |= GridBagConstraints.VERTICAL;
		gbc.weightx = 1.0;
		gbc.weighty = 1.0;

		root.add(message, gbc);
	}

	private void killKnownOffenders(Runtime rtime) throws IOException {
		// Let's tidy up some known offenders...
		// FIXME: this should be refactored to at least go into its own class.
		rtime.exec("/usr/bin/killall -9 matchbox-keyboard", null);
		rtime.exec("/usr/bin/killall -9 kterm", null);
		rtime.exec("/usr/bin/killall -9 skipstone", null);
		rtime.exec("/usr/bin/killall -9 cr3", null);
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
		if (newOffset < 0) {
			// the largest possible multiple of the page size.
			newOffset = getEntriesCount();
			newOffset -= newOffset % getPageSize();
			// boundary case
			if (newOffset == getEntriesCount()) {
				newOffset -= getPageSize();
			}
		} else if (newOffset >= getEntriesCount()) {
			newOffset = 0;
		}
		if (newOffset == offset) {
			return;
		}
		offset = newOffset;
		updateDisplayedLaunchers();
	}

	private void updateDisplayedLaunchers() {
		Iterator it = executablesMap.entrySet().iterator();
		// skip entries up to offset
		for (int i = 0; i < offset; ++i) {
			if (it.hasNext()) {
				it.next();
			}
		}
		entriesPanel.removeAll();
		int end = offset;
		for (int i = getPageSize(); i > 0; --i) {
			Component button = getUI().newButton("", null);
			button.setEnabled(false);
			if (it.hasNext()) {
				Map.Entry entry = (Entry) it.next();
				button = getUI().newButton((String) entry.getKey(), this);
				++end;
			}
			entriesPanel.add(button);
		}
		// weird shit: it's actually the setStatus() which prevents the Kindle
		// Touch from simply showing an empty list. WTF?!
		setStatus("Items " + (offset + 1) + " - " + end + " of "
				+ executablesMap.size());
		boolean enableButtons = getPageSize() < executablesMap.size();
		prevPageButton.setEnabled(enableButtons);
		nextPageButton.setEnabled(enableButtons);

		// just to be on the safe side
		entriesPanel.invalidate();
		entriesPanel.repaint();
		context.getRootContainer().invalidate();
		context.getRootContainer().repaint();
	}

	private int getEntriesCount() {
		return executablesMap.size();
	}

	private int getPageSize() {
		// this could be extended in the future to account for user-modifiable
		// settings.
		return getUI().getDefaultPageSize();
	}

	private void handleLauncherButton(Component button) {
		String cmd = (String) executablesMap.get(button.getName());

		try {
			setStatus(cmd);

			commandToRunOnExit = cmd;

			getUI().suicide(context);
		} catch (Throwable ex) {
			String report = ex.getMessage();
			setStatus(report);
		}
	}

	private Process execute(String cmd, boolean background) throws IOException,
			InterruptedException {

		File launcher = createLauncherScript(cmd, background,
				"export KUAL='/bin/ash " + parseFile.getAbsolutePath() + " -x '; ");
		return Runtime.getRuntime().exec(
				new String[] { "/bin/sh", launcher.getAbsolutePath() }, null);
	}

	protected void onStop() {
		/*
		 * This should really be run on the onDestroy() method, because onStop()
		 * might be invoked multiple times. But in the onDestroy() method, it
		 * just won't work. Might be related with what the life cycle
		 * documentation says about not holding files open etc. after stop() was
		 * called. Anyway: seems to work.
		 */
		if (commandToRunOnExit != null) {
			try {
				execute(commandToRunOnExit, true);
			} catch (Exception e) {
				// can't do much, really. Too late for that :-)
			}
			commandToRunOnExit = null;
		}
		super.onStop();
	}

	private File createLauncherScript(String cmd, boolean background, String init)
			throws IOException {
		File tempFile = java.io.File.createTempFile(EXEC_PREFIX_BACKGROUND,
				EXEC_EXTENSION_SH);

		BufferedWriter bw = new BufferedWriter(new FileWriter(tempFile));
		bw.write("#!/bin/ash");
		bw.newLine();

		if (background) {
			bw.write("{ " + init + cmd + " ; } &"); // wrap inside {} to support backgrounding multiple commands, e.g., x=1; use.sh $x ...
		} else {
			bw.write(cmd);
		}

		bw.newLine();
		bw.close();
		return tempFile;
	}
}
