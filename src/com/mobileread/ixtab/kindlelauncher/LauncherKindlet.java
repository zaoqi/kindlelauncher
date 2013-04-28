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
import com.mobileread.ixtab.kindlelauncher.resources.KualEntry;
import com.mobileread.ixtab.kindlelauncher.resources.KualLog;
import com.mobileread.ixtab.kindlelauncher.resources.KualMenu;
import com.mobileread.ixtab.kindlelauncher.resources.MailboxCommand;
import com.mobileread.ixtab.kindlelauncher.resources.MailboxProcessor;
import com.mobileread.ixtab.kindlelauncher.resources.ResourceLoader;
import com.mobileread.ixtab.kindlelauncher.timer.TimerAdapter;
import com.mobileread.ixtab.kindlelauncher.ui.GapComponent;
import com.mobileread.ixtab.kindlelauncher.ui.UIAdapter;

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
	private KualMenu kualMenu;
	// Viewport on kualMenu at current depth
	// . set in updateDisplayedLauncher()
	// . used in getEntriesCount()
	private final ArrayList viewList = new ArrayList();

	private KindletContext context;
	private boolean started = false;
	private String commandToRunOnExit = null;
	private String dirToChangeToOnExit = null;

	private final String CROSS = "\u00D7"; // X - match parser script
	private final String ATTN = "\u25CF"; // O - match parser script
	private final String RARROW = "\u25B6";
	private final String LARROW = "\u25C0";
	private final String UARROW = "\u25B2";
	private final String PATH_SEP = "/";

	private Container entriesPanel;
	private Component status;
	private Component nextPageButton = getUI().newButton("  " + RARROW + "  ", this, null);
// Fiddling with UI concepts.
// Abandoned GUI1 - it placed the up-button in the trail area, and the left-button on the left
// - on K3 clicking to select the up-button was tedious
// Current UI (unlabelled) - it places the up-button left, no left-button nor an active button in the trail area.
// I find that this solution works better - up-button is larger and easier to click on KT; K3 needs fewer clicks to select it
// TODO (nice to have) wrapping around up/down press on 5-way controller
//GUI1//	private Component prevPageButton = getUI().newButton("  " + LARROW + "  ", this, null);
private Component prevPageButton = getUI().newButton("  " + UARROW + "  ", this, null);
//GUI1//	private Component prevLevelButton = getUI().newButton(UARROW, this, null);
private Component prevLevelButton = getUI().newLabel(PATH_SEP);

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

			// monitor messages from backgrounded script (monitoring ends
			// after a fixed time, thereafter mailbox checking is repeated
			// after handling each button event in actionPerformed()
			new MailboxProcessor(kualMenu, '1', new ReloadMenuFromCache(), 1000, 1000, 10);
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

		String show = kualMenu.getConfig("no_show_status");
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

		updateDisplayedLaunchers(depth = 0, true);
	}

	private void initializeState() throws IOException, InterruptedException, Exception {
		// Go as quickly as possible through here.
		// The kindlet is given 5000 ms maximum to initializeUI()

		cleanupTemporaryDirectory();
		runParser();
	}

	private void runParser() throws IOException, InterruptedException, Exception {
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
			InterruptedException, Exception {

		// Read menu records to initialize menu entries.
		kualMenu = new KualMenu(reader);

		// Reset navigation helpers.
		// keTrail[] - stack of menu entries, one for each node of the current menu path
		// depth - keTrail top index
		for (int i = 0; i < 10; i++) {
			keTrail[i] = null;
		}
		depth = 0;
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
			//on submenu button it calls handleLevel()
		}

		// foreground, non-blocking check for background menu updates
		new MailboxProcessor(kualMenu, '1', new ReloadMenuFromCache(), 0, 0, 0);
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
		updateDisplayedLaunchers(level, false);
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
		updateDisplayedLaunchers(depth, false);
	}

	private static int viewLevel = -1;
	private static int viewOffset = -1;

	private void updateDisplayedLaunchers(int level, boolean resetViewport) {

		if (resetViewport) {
			viewLevel = viewOffset = -1;
			for (int i = 0; i < 10; i++)
				offset[i] = 0;
			viewList.clear();
		}

		// view entries at the end of the trail
		if (viewLevel != level || viewOffset != offset[level]) {
			viewLevel = level;
			viewOffset = offset[level];
			viewList.clear();
			if (0 == level) {
				viewList.addAll(kualMenu.getLevel(0).keySet()); //WAS viewList.addAll(levelMap[0].keySet());
			} else {
				KualEntry ke  = keTrail[level - 1];
				String  parentLink = ke.getParentLink();
				Iterator it = kualMenu.getLevel(level).entrySet().iterator(); //WAS Iterator it = levelMap[level].entrySet().iterator();
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
				KualEntry ke = kualMenu.getEntry(level, it.next()); //WAS (KualEntry) levelMap[level].get(it.next());
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
				+ " build " + kualMenu.getVersion());
		}
		setTrail(null == status && enableButtons
				? (viewOffset+1)+"-"+end+"/"+viewList.size()
				: null, null);
//GUI1//		prevPageButton.setEnabled(enableButtons);
prevPageButton.setEnabled(level>0);
		nextPageButton.setEnabled(enableButtons);
//GUI1//		prevLevelButton.setEnabled(level>0);

		// just to be on the safe side
		entriesPanel.invalidate();
		entriesPanel.repaint();
		context.getRootContainer().invalidate();
		context.getRootContainer().repaint();
	}

	private int getEntriesCount(int level) {
		return viewList.size() > 0 ? viewList.size() : kualMenu.getLevel(level).size(); //WAS levelMap[level].size();
	}

	private static int onStartPageSize = -1; // tracks onStart() size, so ReloadMenuFromCache can't interfere
	private int getPageSize() {
		if (0 < onStartPageSize) {
			return onStartPageSize;
		}
		onStartPageSize = 0;
		String size = kualMenu.getConfig("page_size");
		if (null != size) try {
			onStartPageSize = Integer.parseInt((String) size);
		} catch (Throwable ex) {};
		if (0 == onStartPageSize) {
			onStartPageSize = getUI().getDefaultPageSize();
		}
		return onStartPageSize;
	}

	private int getTrailMaxWidth() {
		// A fixed value will never work in all situations because kindle uses
		// a proportional font; this is a best guess
		return 60; //FIXME
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
			setStatus(ke.action);
			try {
int beforeAction = 0;
			if (0 < beforeAction)
				Thread.sleep(beforeAction);

				if (! ke.hasOption('e')) {
					// JSON  "exitmenu":true
					// suicide
					commandToRunOnExit = ke.action;
					dirToChangeToOnExit = ke.dir;
					getUI().suicide(context);
				} else {
					// survive
					execute(ke.action, ke.dir, true);
int afterAction = 0;
					if (0 < afterAction)
						Thread.sleep(afterAction);
				}
			} catch (Exception ex) {
				setStatus(ex.getMessage());
			}
		}
		if (ke.hasOption('c')) {
			// JSON "checked":true - add checkmark to button label
			ke.setChecked(true);
			getUI().setText(button, ke.label);
			button.repaint();
			// FIXME K3 doesn't refresh button label immediately
		}
		if (ke.hasOption('r')) {
			// JSON "refresh":true - refresh and reload the menu
			refreshMenu(500L, 1500L);
		}
		if (ke.hasOption('h')) {
			// "hidden" not implemented
		}
	}

	private Process execute(String cmd, String dir, boolean background) throws IOException,
			InterruptedException {

		File workingDir = new File(dir);
		if (! workingDir.isDirectory()) {
			new KualLog().append("directory '" + dir + "' not found");
			return null;
		}
		File launcher = createLauncherScript(cmd, background, "");
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

	public class ReloadMenuFromCache implements MailboxCommand {
		public void execute(Object data) {
			setTrail("About to reload new menu " + ATTN +" Please wait...", "");
			setStatus("Reloading...");
			try {
				readParser((BufferedReader) data);
				updateDisplayedLaunchers(depth = 0, true);
				setStatus("Reloading complete. Please go to the top menu");
			} catch (Throwable t) {
				setStatus(t.getMessage());
			}
		}
	}

	public void refreshMenu (long beforeParser, long afterParser) throws RuntimeException {
			// FIXME unsure as to why trail and status lines don't get updated immediately
			setTrail("Extension about to refresh the menu" + ATTN +" Please wait...", "");
			setStatus("Refreshing...");

			// Here we *refresh* the menu by instantiating the parser then reloading a
			// fresh cache. This enables extensions to dynamically change the menu.
			try {
				// An extension that needs some time to stage the new menu may set JSON
				//    TODO JSON sleep:"after_action,before_action,after_refresh,before_refresh"
				// in milliseconds, where
				// before_action/after_action refer to the time KUAL *backgrounds* the user's action
				// before_refresh/refresh (default 500 ms) it's the delay before tearing down the
				// current menu (a <500 value is allowed but not recommended)
				// after_refresh (default 1500 ms) is the time that the parser takes to
				// build a new cache (1500 ms is an average value)

				/*
				 * Goal: display a fresh menu with just one screen update.
				 * If we allowed more screen updates it would be enough to just say:
				 *   initializeState(); іnitializeUI(): new MailboxProcessor(..., 1000, 1000, 10).
				 * But since we aim at a single screen update more steps are involved.
				*/

				// Yield 500 ms to allow an extension to stage its menu change.
				// Extension developers may set beforeParser to achieve a longer pause.
				Thread.sleep(beforeParser > 0 ? beforeParser : 500);

				runParser(); // still sends the old cache while background-building a new one

				// Wait long enough for the parser to complete building the new cache then consume it.
				// Since we can't know how long that will take, we delay consuming data from the parser
				// by afterParser ms (default 1500).  That's long enough for a medium-sized extension folder.
				// Users with very large folders may need to increase afterParser.
				new MailboxProcessor(kualMenu, '1', new ReloadMenuFromCache(), afterParser, 0, 0);

				initializeState(); // now the parser is even more likely to send a fresh cache
					// initializeState() also cleans up temporary files

				initializeUI(); // enables "hard" configuration changes such as number of items per page
				// reaps a new cache one way or another - but when it does the user can see another screen update
				new MailboxProcessor(kualMenu, '1', new ReloadMenuFromCache(), 0, 500, 10);

			} catch (Throwable t) {
				throw new RuntimeException(t);
			}
		}
}
