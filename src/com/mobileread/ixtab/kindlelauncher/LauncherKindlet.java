package com.mobileread.ixtab.kindlelauncher;

import ixtab.jailbreak.Jailbreak;
import ixtab.jailbreak.SuicidalKindlet;

import java.awt.BorderLayout;
import java.awt.Component;
import java.awt.Container;
import java.awt.EventQueue;
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
//import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
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
	private Component status = null;
	private Component nextPageButton = getUI().newButton("  " + RARROW + "  ", this, null);
	private Component prevPageButton = getUI().newButton("  " + UARROW + "  ", this, null);
	private Component breadcrumb = getUI().newLabel(PATH_SEP);

	private final KualEntry toTopEntry = new KualEntry(1, PATH_SEP);
	private final Component toTopButton = getUI().newButton(PATH_SEP, this, toTopEntry);
	private final KualEntry quitEntry = new KualEntry(2, CROSS + " Quit");
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

		// Go as quickly as possible through here.
		// The kindlet is given 5000 ms maximum to start.

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

		// postpone longer initialization for quicker return
		Runnable runnable = new Runnable() {
		    public void run() { 
			LauncherKindlet.this.longStart();
		    }
		};
		EventQueue.invokeLater(runnable);
	}

	private void longStart() {
/*
 * High-level description of KUAL flow
 *
 * 1. kindlet: spawn the parser then block waiting for input from the parser.
 * 2. parser:  send the kindlet cached data so the kindlet can quickly move on to initialize the UI.
 * 3. kindlet: initialize UI and display the menu.
 * 4. kindlet: schedule a 10-time-repeat 1-second timer task which checks for messages from the parser.
 * 5. parser:  (while the kindlet is initializing the UI) parse menu files and refresh the cache.
 * 6: parser:  if the fresh cache differs from the cache sent in step 2 then post the kindlet a message
 * 7: parser:  exit
 * 8: kindlet: if the timer found a message in the mailbox update the menu from the fresh cache and re-display UI.
 * 9: kindlet: loop: wait for user interaction; handle interaction.
 *
*/
		try {
			initializeState(); // step 1
			initializeUI(); // step 3
			// Monitor messages from backgrounded script. Monitoring ends in 10 s.
			// Thereafter check the mailbox on each button event in actionPerformed().
			new MailboxProcessor(kualMenu, '1', new ReloadMenuFromCache(), 1000, 1000, 10); // steps 4,8
		} catch (Throwable t) {
			throw new RuntimeException(t);
		}
	}

	private void setStatus(String text) {
		if(null == status)
			setBreadcrumb(text,null);
		else
			getUI().setText(status, text);
	}

	private void setBreadcrumb(String left, String center) {
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
		getUI().setText(breadcrumb, text);
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
		main.add(breadcrumb, BorderLayout.NORTH);

		GridLayout grid = new GridLayout(getPageSize(), 1, gap, gap); 
		entriesPanel = getUI().newPanel(grid);

		main.add(entriesPanel, BorderLayout.CENTER);

		// FOR TESTING ONLY, if a specific number of entries is needed.
		// for (int i = 0; i < 25; ++i) {
		// leveleMap[depth].put("TEST-" + i, "touch /tmp/test-" + i + ".tmp");
		// }

		updateDisplayedLaunchers(depth = 0, true, null);
	}

	private void initializeState() throws IOException, InterruptedException, Exception {

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
		} catch (Throwable t) {
			new KualLog().append(t.toString());
			setStatus("Exception logged.");
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
			handleLevel(LEVEL_PREVIOUS);
			//changes offset[] and depth
		} else if (button == nextPageButton) {
			handlePaging(PAGING_NEXT, depth);
			//changes offset[]
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
//DEBUG del//setBreadcrumb("olv("+offset[level]+")new("+newOffset+")");
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
		updateDisplayedLaunchers(level, false,
			-1 == direction ? prevPageButton : nextPageButton);
	}

	private void handleLevel(int direction) {
		int goToLevel;
		int goToOffset;
		if (-1 == direction) { // return from submenu
			goToLevel = depth > 0 ? depth - 1 : 0;
			goToOffset = offset[goToLevel];
		} else { // drill into sub-menu
			KualEntry ke = keTrail[depth]; // origin
			goToLevel = ke.getGoToLevel();
			goToOffset = 0;
		}
		depth = goToLevel;
		offset[depth] = goToOffset;
		updateDisplayedLaunchers(depth, false,
			-1 == direction ? (0 >= depth? null : prevPageButton) : null);
	}

	private static int viewLevel = -1;
	private static int viewOffset = -1;

	private void updateDisplayedLaunchers(int level, boolean resetViewport,
			Component focusRequestor) {

		if (resetViewport) {
			viewLevel = viewOffset = -1;
			for (int i = 0; i < 10; i++)
				offset[i] = 0;
			viewList.clear();
		}

		// load entries of the current level into the viewport
		if (viewLevel != level || viewOffset != offset[level]) {
			viewLevel = level;
			viewOffset = offset[level];
			viewList.clear();
			if (0 == level) {
				viewList.addAll(kualMenu.getLevel(0).keySet());
			} else {
				KualEntry ke  = keTrail[level - 1];
				String  parentLink = ke.getParentLink();
				Iterator it = kualMenu.getLevel(level).entrySet().iterator();
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
			//FIXME button isn't appended when the number of entries is a multiple of the page size.

		for (int i = getPageSize(); i > 0; --i) {
			//Component button = getUI().newButton("", null, null); // fills whole column
			//Component button = nullButton; // shortens column after last entry
			Component button = 0 == level ? quitButton : toTopButton;
			if (it.hasNext()) {
				KualEntry ke = kualMenu.getEntry(level, it.next());
				button = getUI().newButton(ke.label, this, ke); //then getUI().getKualEntry(button) => ke
				if (null == focusRequestor) {
					focusRequestor = button;
				}
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
				+ " build " + kualMenu.getVersion() + " " + kualMenu.getConfig("model"));
		}
		setBreadcrumb(null == status && enableButtons
				? (viewOffset+1)+"-"+end+"/"+viewList.size()
				: null, null);
		prevPageButton.setEnabled(level>0);
		nextPageButton.setEnabled(enableButtons);

		// just to be on the safe side
		entriesPanel.invalidate();
		entriesPanel.repaint();
		context.getRootContainer().invalidate();
		context.getRootContainer().repaint();

		// This is for 5-way controller devices.
		// It is essential to request focus _after_ the button has been displayed!
		if (null != focusRequestor) {
			focusRequestor.requestFocus();
		}
	}

	private int getEntriesCount(int level) {
		return viewList.size() > 0 ? viewList.size() : kualMenu.getLevel(level).size();
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
		} catch (Throwable ignored) {};
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
		if (ke.isSubmenu) { // drill into sub-menu
			keTrail[level] = ke;
			try {
				handleLevel(LEVEL_NEXT);
			} catch (Throwable t) {
				new KualLog().append(t.toString());
				setStatus("Exception logged.");
			}
		} else {
		// run internal action, if any, then action, if any
			if (ke.isInternalAction) {
				switch (ke.internalAction) {
					// 0-32 reserved for KualEntry(int, String) constructor 
					// 'A', etc. defined in parser script
					case 0:
					case 'A': // extension displays message in breadcrumb line
						setBreadcrumb(ke.internalArgs + " | ", null);
						break;
					case 'B': // extension displays message in status line
						setStatus(ke.internalArgs);
						break;
					case 1: // go to top menu
						depth = 0;
						handleLevel(LEVEL_PREVIOUS);
						break;
					case 2: // quit
						// falls into ! option 'e'
						break;
				}
			}
			if (null != ke.action) {
			// run shell cmd. null may come from KualEntry(int, String) constructor only
				// now is the right time to get rid of known offenders
				killKnownOffenders(Runtime.getRuntime());
				if (! ke.hasOption('s')) {
					// JSON "status":false
					setStatus(ke.action);
				}
				try {
int beforeAction = 0; //TODO
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
int afterAction = 0; //TODO
						if (0 < afterAction)
							Thread.sleep(afterAction);
					}
				} catch (Throwable t) {
					new KualLog().append(t.toString());
					setStatus("Exception logged.");
				}
			}
		}

		//
		// placeholder for post-action internal actions
		//

		// process post-action options
		if (ke.hasOption('c')) {
			// JSON "checked":true - add checkmark to button label
			ke.setChecked(true);
			getUI().setText(button, ke.label);
			button.repaint();
			// FIXME K3 doesn't refresh button label immediately
		}
		if (ke.hasOption('r')) {
			// JSON "refresh":true - refresh and reload the menu
			refreshMenu(500L, 1500L, ke.label);
		}
		if (ke.hasOption('d')) {
			// JSON "date":true - show date/time in status line
			Date now = new Date();
			setStatus(now.toString());
			//SimpleDateFormatter fmt = new SimpleDateFormatter();
			//setStatus(fmt.format("HH:mm:ss", now));
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
			} catch (Exception ignored) {
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
			setBreadcrumb("Loading new menu " + ATTN +" Please wait...", "");
			setStatus("Loading...");
			try {
				readParser((BufferedReader) data);
				updateDisplayedLaunchers(depth = 0, true, null);
				setStatus("New menu loaded. Please go to top.");
			} catch (Throwable t) {
				new KualLog().append(t.toString());
				setStatus("Exception logged.");
			}
		}
	}

	public void refreshMenu(final long beforeParser, final long afterParser, String requestor)
		throws RuntimeException {
		setBreadcrumb("Refreshing the menu " + ATTN +" Please wait...", "");
		if (null != requestor)
			setStatus(requestor);

		final TimerAdapter tmi =  TimerAdapter.INSTANCE;
		final Object timer = tmi.newTimer();
		Runnable runnable = new Runnable() {
			public void run() {

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
					 *   initializeState(); initializeUI(): new MailboxProcessor(..., 1000, 1000, 10).
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
					// reaps a new cache one way or another - when it does the user sees another screen update
					new MailboxProcessor(kualMenu, '1', new ReloadMenuFromCache(), 0, 500, 10);
				} catch (Throwable t) {
					new KualLog().append(t.toString());
					setStatus("Exception logged.");
					throw new RuntimeException(t);
				}
				String text = "Menu refreshed.";
				setStatus(text);
				setBreadcrumb(text, null);
				tmi.cancel(timer);
			}
		};
		Object task = tmi.newTimerTask(runnable);
		tmi.schedule(timer, task, 0L, 500L);
	}
}
