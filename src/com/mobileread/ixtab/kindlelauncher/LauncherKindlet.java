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
import java.awt.Label;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Map.Entry;

import com.amazon.kindle.kindlet.KindletContext;
import com.mobileread.ixtab.kindlelauncher.resources.ResourceLoader;
import com.mobileread.ixtab.kindlelauncher.ui.GapComponent;
import com.mobileread.ixtab.kindlelauncher.ui.UIAdapter;
import com.mobileread.ixtab.kindlelauncher.resources.KualEntry;
import com.mobileread.ixtab.kindlelauncher.timer.TimerAdapter;

public class LauncherKindlet extends SuicidalKindlet implements ActionListener {

	public static final String RESOURCE_PARSER_SCRIPT = "parse.awk"; //"parse.sh";
	private static final String EXEC_PREFIX_PARSE = "klauncher_parse-";
	private static final String EXEC_PREFIX_BACKGROUND = "klauncher_background-";
	private static final String EXEC_EXTENSION_SH = ".sh";
	private static final String EXEC_EXTENSION_AWK = ".awk";
	private static final long serialVersionUID = 1L;

	private static final int PAGING_PREVIOUS = -1;
	private static final int PAGING_NEXT = 1;
	private static final int LEVEL_PREVIOUS = -1;
	private static final int LEVEL_NEXT = 1;
	private final LinkedHashMap[] levelMap = new LinkedHashMap[10]; // all menu entries
	private final HashMap configMap = new HashMap();
	private final ArrayList viewList = new ArrayList(); // a viewport on levelMap
	private static int viewLevel = -1;
	private static int viewOffset = -1;
	private static int monitorMbxRepeat = 10;
//	private File parseFile;

	private KindletContext context;
	private boolean started = false;
	private String commandToRunOnExit = null;
	private String dirToChangeToOnExit = null;

	private Container entriesPanel;
	private Component status;
	private Component nextPageButton = getUI().newButton("  \u25B6  ", this, null); //>
// Fiddling with UI concepts. GUI1 puts up button on top, but getting there is very tedious on K3.
// Se let's experiment other placements... Here up button is placed left.
//GUI1//	private Component prevPageButton = getUI().newButton("  \u25C0  ", this, null); //<
private Component prevPageButton = getUI().newButton("  \u25B2  ", this, null); //^
//GUI1//	private Component prevLevelButton = getUI().newButton("\u25B2", this, null); //^
private Component prevLevelButton = getUI().newLabel("\u266A \u266B \u266A"); //j JJ j  FIXME is this needed?

	private final String CROSS = "\u00D7"; // X - match parser's
	private final String ATTN = "\u25CF"; // O - match parser's
	private final String PATH_SEP = "/";
	private final KualEntry toTopEntry = new KualEntry(3, PATH_SEP);
	private final Component toTopButton = getUI().newButton(PATH_SEP, this, toTopEntry);
	private final KualEntry quitEntry = new KualEntry(4, CROSS + " Quit");
	private final Component quitButton = getUI().newButton(CROSS + " Quit", this, quitEntry);

	private int[] offset = {0,0,0,0,0,0,0,0,0,0}; //10
	private KualEntry[] keTrail = {null,null,null,null,null,null,null,null,null,null}; //10
	private int depth = 0;

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

		for (int i=0; i<10; ++i) {
			offset[i] = 0;
		}
		viewLevel = viewOffset = -1; // used in updateDisplayedLaunchers() only

/*
 * High-level description of KUAL flow
 *
 * 1. kindlet: spawn the parser and block waiting for input from the parser
 * 2. parser: send cached data so the kindlet can quickly move on to initialize the UI
 * 3. kindlet: set a 10-time 1-second repeat timer - each time through will check a mailbox from the parser
 * 4. kindlet: initialize UI
 * 5. parser: (while kindlet is initializing UI) parse menu files and refresh the cache
 * 6: parser: if cache changed post a message to mailbox
 * 7: parser: exit
 * 8: kindlet: if the timer found a message in the mailbox then tell user, "Hey, new menu, restart to refresh!"
 * 9: kindlet: wait for user interaction; handle interaction
 *
*/
		try {
			initializeState();
			// initializeState() has set menu structure and getPageSize() for UI()
			initializeUI();
		} catch (Throwable t) {
			throw new RuntimeException(t);
		}

	}

	private void setStatus(String text) {
		if(null == status)
			setTrail(text,null);
		else
			getUI().setText(status, text);
	}

	private void setTrail(String left, String center) {
		String text = null == left ? "" : left + " ";
		if (null != center) {
			text += center;
		} else if (0 == depth) {
			text += PATH_SEP;
		} else {
			String label = keTrail[depth - 1].getBareLabel();
			int width = getTrailMaxWidth() - text.length() ;
			for (int i = depth - 2; i >= 0 && label.length() <= width; i--) {
				label = keTrail[i].getBareLabel() + PATH_SEP + label;
			}
			label = PATH_SEP + label;
			int len = label.length();
			if (len > width)
				label = "..." + label.substring(len - width + 3);
			text += label;
		}
		getUI().setText(prevLevelButton, text);
	}

	private static UIAdapter getUI() {
		return UIAdapter.INSTANCE;
	}

	private void initializeUI() {
		Container root = context.getRootContainer();
		int gap = getUI().getGap();
		root.removeAll();

		root.setLayout(new BorderLayout(gap,gap));
		Container main = getUI().newPanel(new BorderLayout(gap,gap));
		
		// this is a horrible workaround to simulate adding a border around
		// the main container. It has to be done this way because we have
		// to support different framework versions.

		root.add(main, BorderLayout.CENTER);
		root.add(new GapComponent(0), BorderLayout.NORTH);
		root.add(new GapComponent(0), BorderLayout.EAST);
		root.add(new GapComponent(0), BorderLayout.SOUTH);
		root.add(new GapComponent(0), BorderLayout.WEST);

		main.add(prevPageButton, BorderLayout.WEST);
		main.add(nextPageButton, BorderLayout.EAST);

		String show = getConfigValue("no_show_status");
		if (null != show && show.equals("true")) {
			status = null;
		} else {
			status = getUI().newLabel("Status");
			main.add(status, BorderLayout.SOUTH);
		}
		main.add(prevLevelButton, BorderLayout.NORTH);

		GridLayout grid = new GridLayout(getPageSize(), 1, gap, gap); 
		entriesPanel = getUI().newPanel(grid);

		main.add(entriesPanel, BorderLayout.CENTER);

		// FOR TESTING ONLY, if a specific number of entries is needed.
		// for (int i = 0; i < 25; ++i) {
		// leveleMap[depth].put("TEST-" + i, "touch /tmp/test-" + i + ".tmp");
		// }

		updateDisplayedLaunchers(depth);

		// monitor messages from backgrounded script (monitor ends
		// after a fixed time then mailbox checking continues
		// synchronously in updateDisplayedLaunchers())
		monitorMbx();
	}

	private void initializeState() throws IOException, FileNotFoundException,
			InterruptedException, NumberFormatException {
		// Be as quick as possible through here.
		// The kindlet is given 5000 ms maximum to initializeUI()

		cleanupTemporaryDirectory();
		//postponed to when it's really needed:	killKnownOffenders(Runtime.getRuntime());

		// run the parser script and read its output (we may get cached data)
		File parseFile = extractParseFile();
		BufferedReader reader = Util.execute(parseFile.getAbsolutePath());
		readParser(reader);
		reader.close();

		// Do not delete the script file because it is updating the cache
		// in the background.
		// Let cleanupTemporaryDirectory() take care of it next time.
	}

	private void readParser(BufferedReader reader) throws IOException,
			InterruptedException, NumberFormatException {
		KualEntry kualEntry;
		try {
			// meta info: version, mailboxpath
			int size = Integer.parseInt(reader.readLine());
			for (int i = 1; i <= size; i++) {
				configMap.put("meta" + Integer.toString(i), reader.readLine());
			}
			// meta data: N\nKUAL.cfg lines
			String line = null;
			size = Integer.parseInt(reader.readLine());
			for(int i = 1; i <= size; i++) {
				line = reader.readLine().trim();
				if (! line.startsWith("#")) {
					int p = line.indexOf('=');
					if (p > 0) {
						configMap.put(line.substring(0,p), line.substring(p+1));
					}
				}
			}

			// data: read list of menu entries
			// levelMap[i] <= ordered map of all entries at menu level i
			// levelMap[i][id] <= entry of class KualEntry, entry.id is unique and isn't a label
			for (int i=0; i<10; i++) {
				levelMap[i] = new LinkedHashMap();
			}
			for (line = reader.readLine(); line != null; line = reader
					.readLine()) {
				String options = "";
				int level = -1;
				kualEntry = null;
				switch (line.charAt(0)) {
					case '4':
						options = reader.readLine();
					case '3':
						try {
							kualEntry = new KualEntry(options, reader.readLine(),
							reader.readLine(), reader.readLine());
							break;
						} catch(Throwable t) {
							// fall into default case
						}
					default:
						throw new Exception("invalid entry"); // can't trust input format
				}
				levelMap[kualEntry.level].put(kualEntry.id, kualEntry);
			}
		} catch (Throwable ex) {
			String report = ex.getMessage();
			kualEntry = new KualEntry(0, "meta error: " + report);
			levelMap[0].put(kualEntry.id, kualEntry);
		}
	}

	private File extractParseFile() throws IOException, FileNotFoundException {
		InputStream script = ResourceLoader.load(RESOURCE_PARSER_SCRIPT);
		File parseInput = File.createTempFile(EXEC_PREFIX_PARSE,
				EXEC_EXTENSION_AWK);//EXEC_EXTENSION_SH);

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

	private void killKnownOffenders(Runtime rtime) {
		// Let's tidy up some known offenders...
		// Call this right before executing a menu action
		String offenders="matchbox-keyboard kterm skipstone cr3";
		try {
			rtime.exec("/usr/bin/killall " + offenders, null); // gently
			rtime.exec("/usr/bin/killall -9 " + offenders, null); // forcefully
		} catch (Throwable ex) {
			String report = ex.getMessage();
			setStatus(report);
		}
	}

	private void cleanupTemporaryDirectory() {
		File tmpDir = new File("/tmp");

		File[] files = tmpDir.listFiles();

		for (int i = 0; i < files.length; i++) {
			if (files[i].isFile()) {
				String file = files[i].getName();
				if (file.startsWith(EXEC_PREFIX_BACKGROUND)
					|| file.startsWith(EXEC_PREFIX_PARSE)) {
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
//GUI1//			handlePaging(PAGING_PREVIOUS, depth);
handleLevel(LEVEL_PREVIOUS);
			//changes offset[]
		} else if (button == nextPageButton) {
			handlePaging(PAGING_NEXT, depth);
			//changes offset[]
//GUI1//		} else if (button == prevLevelButton) {
//GUI1//			handleLevel(LEVEL_PREVIOUS);
			//changes offset[] and depth
		} else {
			handleLauncherButton(button, depth);
			//changes trail[] & calls handleLevel() on submenu button 
		}
	}

	private void handlePaging(int direction, int level) {
		// direction is supposed to be -1 (backward) or +1 (forward),
		int newOffset = offset[level] + getPageSize() * direction;
//DEBUG del//setTrail("olv("+offset[level]+")new("+newOffset+")");
		if (newOffset < 0) {
			// the largest possible multiple of the page size.
			newOffset = getEntriesCount(level);
			newOffset -= newOffset % getPageSize();
			// boundary case
			if (newOffset == getEntriesCount(level)) {
				newOffset -= getPageSize();
			}
		} else if (newOffset >= getEntriesCount(level)) {
			newOffset = 0;
		}
		if (newOffset == offset[level]) {
			return;
		}
		offset[level] = newOffset;
		updateDisplayedLaunchers(level);
	}

	private void handleLevel(int direction) {
		int goToLevel;
		int goToOffset;
		if (-1 == direction) { // return from submenu
			goToLevel = depth > 0 ? depth - 1 : 0;
			goToOffset = offset[goToLevel];
		} else { // dive into submenu
			KualEntry ke = keTrail[depth]; // origin
			goToLevel = ke.getGoToLevel();
			goToOffset = 0;
		}
		depth = goToLevel;
		offset[depth] = goToOffset;
		updateDisplayedLaunchers(depth);
	}

	private void updateDisplayedLaunchers(int level) {
	//changes viewList (and viewLevel and viewOffset)

		// view entries at the end of the trail
		if (viewLevel != level || viewOffset != offset[level]) {
			viewLevel = level;
			viewOffset = offset[level];
			viewList.clear();
			if (0 == level) {
				viewList.addAll(levelMap[0].keySet());
			} else {
				KualEntry ke  = keTrail[level - 1];
				String  parentLink = ke.getParentLink();
				Iterator it = levelMap[level].entrySet().iterator();
				while (it.hasNext()) {
					Map.Entry entry = (Entry) it.next();
					ke = (KualEntry) entry.getValue();
					if (ke.isLinkedUnder(parentLink))
						viewList.add(entry.getKey());
				}
			}
		}

		Iterator it = viewList.iterator();

		// skip entries up to offset
		for (int i = 0; i < viewOffset; ++i) {
			if (it.hasNext()) {
				it.next();
			}
		}
		entriesPanel.removeAll();
		int end = viewOffset;

		// This button is appended at the end of the list.
		//Component nullButton = getUI().newButton("", null, null);
		//nullButton.setEnabled(false);
		toTopButton.setEnabled(true);
		quitButton.setEnabled(true);

		for (int i = getPageSize(); i > 0; --i) {
			//Component button = getUI().newButton("", null, null); // fills whole column
			//Component button = nullButton; // shortens column after last entry
			Component button = 0 == level ? quitButton : toTopButton;
			if (it.hasNext()) {
				KualEntry ke = (KualEntry) levelMap[level].get(it.next());
				button = getUI().newButton(ke.label, this, ke); //then getUI().getKualEntry(button) => ke
				++end;
			}
			entriesPanel.add(button);
		}

		// weird shit: it's actually the setStatus() which prevents the Kindle
		// Touch from simply showing an empty list. WTF?!
		boolean enableButtons = getPageSize() < viewList.size();
		if (null != status) {
			setStatus("Entries " + (viewOffset + 1) + " - " + end + " of "
				+ viewList.size()
				+ " build " + configMap.get("meta1")); // script version
		}
		setTrail(null == status && enableButtons
				? (viewOffset+1)+"-"+end+"/"+viewList.size()
				: null, null);
//GUI1//		prevPageButton.setEnabled(enableButtons);
prevPageButton.setEnabled(level>0);
		nextPageButton.setEnabled(enableButtons);
//GUI1//		prevLevelButton.setEnabled(level>0);

		checkAndProcessMbx();

		// just to be on the safe side
		entriesPanel.invalidate();
		entriesPanel.repaint();
		context.getRootContainer().invalidate();
		context.getRootContainer().repaint();
	}

	private int getEntriesCount(int level) {
		return viewList.size() > 0 ? viewList.size() : levelMap[level].size();
	}

	private int getPageSize() {
		int isize = 0;
		String size = getConfigValue("page_size");
		if (null != size) try {
			isize = Integer.parseInt((String) size);
		} catch (Throwable ex) {};
		return isize > 0 ? isize : getUI().getDefaultPageSize();
	}

	private int getTrailMaxWidth() {
		// A fixed value will never work in all situations because kindle uses
		// a proportional font; this is a best guess
		return 60; //FIXME
	}

	private String getConfigValue(String name) {
		String value = (String) configMap.get("KUAL_" + name);
		if (value == null)
			return null;
		if (value.startsWith("\"") && value.endsWith("\""))
			value = value.substring(1,value.lastIndexOf("\""));
		return value;
	}

	private void handleLauncherButton(Component button, int level) {
		KualEntry ke = getUI().getKualEntry(button);
		setTrail(null, null); // TODO refresh trail area to make cmd(#1) message more visible
		if (ke.isSubmenu) { // dive into sub-menu
			keTrail[level] = ke;
			try {
				handleLevel(LEVEL_NEXT);
			} catch (Throwable ex) {
				String report = ex.getMessage();
				setStatus(report);
			}
		} else if (ke.isInternalAction) {
			switch (ke.internalAction) {
				case 1: // extension displays message in trail area
					setTrail(ke.internalArgs + " | ", null);
					break;
				case 2: // extension displays message in status area
					setStatus(ke.internalArgs);
					break;
				case 3: // go to top menu
					depth = 0;
					handleLevel(LEVEL_PREVIOUS);
					break;
				case 4: // quit
					// falls into ! option 'e'
					break;
			}
			if (! ke.hasOption('e')) {
				// suicide
				commandToRunOnExit = ":";
				dirToChangeToOnExit = ke.dir;
				getUI().suicide(context);
			}
		} else { // run cmd
			// now is the right time to get rid of known offenders
			killKnownOffenders(Runtime.getRuntime());

			if (! ke.hasOption('e')) {
				// suicide
				try {
					setStatus(ke.action);
					commandToRunOnExit = ke.action;
					dirToChangeToOnExit = ke.dir;
					getUI().suicide(context);
				} catch (Throwable ex) {
					String report = ex.getMessage();
					setStatus(report);
				}
			} else {
				// live
				try {
					execute(ke.action, ke.dir, true);
				} catch (Exception ex) {
					String report = ex.getMessage();
					setStatus(report);
				}
			}
		}
		if (ke.hasOption('c')) {
			// "checked" - add checkmark to button label
			// checkmark will show on next updateDisplayedLaunchers()
			ke.setChecked(true);
			getUI().setText(button, ke.label);
			// FIXME K3 doesn't refresh button label immediately
		}
		if (ke.hasOption('r')) {
			// "reload" not implemented
		}
		if (ke.hasOption('h')) {
			// "hidden" not implemented
		}
	}

	private Process execute(String cmd, String dir, boolean background) throws IOException,
			InterruptedException {

		File launcher = createLauncherScript(cmd, background,
				"");
//discontinued				"export KUAL='/bin/ash " + parseFile.getAbsolutePath() + " -x '; ");
		File workingDir = new File(dir);
		return Runtime.getRuntime().exec(
				new String[] { "/bin/sh", launcher.getAbsolutePath() },
					null, workingDir);
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
				execute(commandToRunOnExit, dirToChangeToOnExit, true);
			} catch (Exception e) {
				// can't do much, really. Too late for that :-)
			}
			commandToRunOnExit = dirToChangeToOnExit = null;
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

		// wrap cmd inside {} to support backgrounding multiple commands and redirecting stderr
		bw.write("{ " + init + cmd + " ; } 2>>/var/tmp/KUAL.log"
				+ (background ? " &" : ""));

		bw.newLine();
		bw.close();
		return tempFile;
	}

	private static TimerAdapter getTimer() {
		return TimerAdapter.INSTANCE;
	}

	private void monitorMbx() {
		// monitor ends on first message in mailbox or after a fixed number of repetitions
		final TimerAdapter instance = getTimer();
		final Object timer = instance.newTimer();
		Runnable runnable = new Runnable() {
			public void run() {
				if (checkAndProcessMbx() || --monitorMbxRepeat <= 0)
					instance.cancel(timer);
			}
		};
		Object task = instance.newTimerTask(runnable);
		instance.schedule(timer, task, 1*1000, 1*1000);
	}

	private boolean checkAndProcessMbx() {
		// did the backgrounded parser script send me a message?
		try {
			BufferedReader mbx = Util.mbxReader((String) configMap.get("meta2")); // mailbox path
			if (null != mbx) {
				String message = mbx.readLine();
				if (message.startsWith("1 ")) {
					setTrail("New menu " + ATTN + " Restart to refresh | ", null);
					message = message.substring(2); // cache path TODO refresh inside
				}
				mbx.close();
				return true;
			}
		} catch (Throwable ex) {
			String report = ex.getMessage();
			setStatus(report);
		}
		return false;
	}
}
