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

public class LauncherKindlet extends SuicidalKindlet implements ActionListener {

	public static final String RESOURCE_PARSER_SCRIPT = "parse.sh";
	private static final String EXEC_PREFIX_PARSE = "klauncher_parse-";
	private static final String EXEC_PREFIX_BACKGROUND = "klauncher_background-";
	private static final String EXEC_EXTENSION_SH = ".sh";
	private static final long serialVersionUID = 1L;

	private static final int PAGING_PREVIOUS = -1;
	private static final int PAGING_NEXT = 1;
	private static final int LEVEL_PREVIOUS = -1;
	private static final int LEVEL_NEXT = 1;
	private final LinkedHashMap[] levelMap = new LinkedHashMap[10];
	private final HashMap[] trackerMap = new HashMap[10];
	private final HashMap configMap = new HashMap();
	private final ArrayList viewList = new ArrayList();
	private static int viewLevel = -1;
	private static int viewOffset = -1;
	private File parseFile;

	private KindletContext context;
	private boolean started = false;
	private String commandToRunOnExit = null;
	private String dirToChangeToOnExit = null;

	private Container entriesPanel;
	private Component status;
	private Component nextPageButton = getUI().newButton("  \u25B6  ", this); //>
	private Component prevPageButton = getUI().newButton("  \u25C0  ", this); //<
	private Component prevLevelButton = getUI().newButton("\u25B2", this); //^

	private String scriptVersion = ""; //from script
	private int[] offset = {0,0,0,0,0,0,0,0,0,0}; //10
	private String[][] trail = {{null,null,null}, // {origin_name, origin_level:snpath, way}
		{null,null,null},{null,null,null},{null,null,null},
		{null,null,null},{null,null,null},{null,null,null},
		{null,null,null},{null,null,null},{null,null,null}}; //10
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
		viewLevel = viewOffset = -1; //only used in updateDisplayedLauncher()

		try {
			initializeState();
			initializeUI(); //depends on initializeState()
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
		String upArr = "\u25B2"; //^
		String text = null == left ? "" : left + " ";
		if (null != center) {
			text += center;
//TODO			getUI().setHorizontalAlignment(prevLevelButton, Label.CENTER);
		} else if (0 == depth) {
			text += upArr;
//TODO			getUI().setHorizontalAlignment(prevLevelButton, Label.CENTER);
		} else {
			String label = "";
			int width=getTrailMaxWidth() - text.length() ;
			for (int i = depth-1; i >= 0 && label.length() <= width; i--) {
				label = trail[i][0] + label;
			}
			int len = label.length();
			if (len > width)
				label = "..."+label.substring(len-width-3);
			text += label.substring(0,label.length()-1) + upArr;
//TODO			getUI().setHorizontalAlignment(prevLevelButton, Label.LEFT);
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
//XX		root.setLayout(new BorderLayout());

//XX		root.add(prevPageButton, BorderLayout.WEST);
//XX		root.add(nextPageButton, BorderLayout.EAST);


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
	main.add(status, BorderLayout.SOUTH); //CHG
		}
	main.add(prevLevelButton, BorderLayout.NORTH); //CHG

	GridLayout grid = new GridLayout(getPageSize(), 1, gap, gap); //CHG
		entriesPanel = getUI().newPanel(grid);

	main.add(entriesPanel, BorderLayout.CENTER);

		// FOR TESTING ONLY, if a specific number of entries is needed.
		// for (int i = 0; i < 25; ++i) {
		// leveleMap[depth].put("TEST-" + i, "touch /tmp/test-" + i + ".tmp");
		// }

		updateDisplayedLaunchers(depth);

	}

	private void initializeState() throws IOException, FileNotFoundException,
			InterruptedException, NumberFormatException {
		cleanupTemporaryDirectory();
		killKnownOffenders(Runtime.getRuntime());

		// run the parser script
		parseFile = extractParseFile();
		BufferedReader reader = Util.execute(parseFile.getAbsolutePath());

		try {
			// meta: size of record and version info
			int size = Integer.parseInt(reader.readLine());
			if (size>0)
				scriptVersion = reader.readLine();
			// meta: slurp N\nKUAL.cfg:lines => configMap
			int p;
			String line = null;
			for(int i = size; i>1; i--) {
				line = reader.readLine().trim();
				if (! line.startsWith("#")) {
					if ((p = line.indexOf('=')) > 0) {
						configMap.put(line.substring(0,p), line.substring(p+1));
					}
				}
			}

			// data: slurp list of buttons => levelMap[]
			for (int i=0; i<10; i++) {
				levelMap[i] = new LinkedHashMap();
				trackerMap[i] = new HashMap();
			}
			String spaces = new String(new char[16]).replace('\0', ' ');
			//TheReading:
			for (line = reader.readLine(); line != null; line = reader
					.readLine()) {
				String label = ""; String action = ""; String options = ""; String levelSnpath = ""; int level = -1;
				switch (Integer.parseInt(line)) {
					case 4: options = reader.readLine(); // e | h | eh
					case 3: levelSnpath = reader.readLine(); // level:snpath
						level = Integer.parseInt((String) levelSnpath.substring(0,levelSnpath.indexOf(":")));
					case 2: label = reader.readLine();
						if (trackerMap[level].containsKey(label)) { // seldom happens
							// make unique key for levelMap
							int n = Integer.parseInt((String) trackerMap[level].get(label));
							trackerMap[level].put(label, Integer.toString(++n));
							label = label + spaces.substring(0,n);
						} else {
							trackerMap[level].put(label, "0");
						}
						action = reader.readLine();
						levelMap[level].put(label, action + ";" + options + "/" + levelSnpath);
						break;
					default: throw new Exception("invalid size"); // can't trust input format
						 //break TheReading;
				}
			}
		} catch (Throwable ex) {
			String report = ex.getMessage();
			levelMap[0].put("meta error: " + report, "[ \"$KUAL\" ] && $KUAL 2" + "/0:ff");
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
			handlePaging(PAGING_PREVIOUS, depth);
			//changes offset[]
		} else if (button == nextPageButton) {
			handlePaging(PAGING_NEXT, depth);
			//changes offset[]
		} else if (button == prevLevelButton) {
			handleLevel(LEVEL_PREVIOUS);
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
	// trail[level] ::= {origin_name, origin_level:snpath, way}
	// way ::= '^' goto_level ':' pattern   ; way and pattern are regular expressions
		int goToLevel;
		int goToOffset;
		if (-1 == direction) { // go up (return from submenu)
			goToLevel = depth > 0 ? depth - 1 : 0;
			goToOffset = offset[goToLevel];
		} else { // go way (dive into submenu)
			String way = trail[depth][2];
//DEBUG//setTrail("trail["+depth+"]={"+trail[depth][0]+","+trail[depth][1]+","+trail[depth][2]+"}");
			try {
				goToLevel = Integer.parseInt(way.substring(1, way.indexOf(":")));
			} catch (Exception ex) {
				goToLevel = 0;
			}
			goToOffset = 0;
		}
		depth = goToLevel;
		offset[depth] = goToOffset;
		updateDisplayedLaunchers(depth);
	}

	private void updateDisplayedLaunchers(int level) {
	//changes viewList (and viewLevel and viewOffset)
		// view just the keys that belong to the current trail
		if (viewLevel != level || viewOffset != offset[level]) {
			viewLevel = level;
			viewOffset = offset[level];
			viewList.clear();
			if (0 == level) {
				viewList.addAll(levelMap[0].keySet());
			} else {
				// trail[i] ::= [origin_name, origin_snpath, '^' goto_level ':' way_regex '$']
				String way = trail[level-1][2];
				way = way.substring(way.indexOf("^")); //i.e., "^2:ff00...$"
				Iterator it = levelMap[level].entrySet().iterator();
//DEBUG del//setStatus("vOf("+viewOffset+")vLv("+viewLevel+")lvl("+level+")trl-1("+trail[level-1][2]+")way("+way+")"); if (true) return;
				while (it.hasNext()) {
					Map.Entry entry = (Entry) it.next();
					String target = ((String) entry.getValue()); //i.e., ".../3:ff00..."
					target = target.substring(1+target.lastIndexOf("/")); //i.e., "3:ff00..."
//DEBUG del//setStatus("way("+way+")tgt("+target+")"); if (true) return;
					if (simplyMatches(way, target))
						viewList.add(entry.getKey());
				}
			}
		}
//DEBUG del//setStatus(String.valueOf(viewList)+"off("+viewOffset+")"); if(level>0) return;
//DEBUG del//setStatus("off="+viewOffset+String.valueOf(viewList));

//DEBUG del//	Iterator it = viewMap.entrySet().iterator();
		Iterator it = viewList.iterator();

		// skip entries up to offset
		for (int i = 0; i < viewOffset; ++i) {
			if (it.hasNext()) {
				it.next();
			}
		}
		entriesPanel.removeAll();
		int end = viewOffset;
		for (int i = getPageSize(); i > 0; --i) {
			Component button = getUI().newButton("", null);
			button.setEnabled(false);
			if (it.hasNext()) {
//DEBUG del//			Map.Entry entry = (Entry) it.next();
//DEBUG del//			button = getUI().newButton((String) entry.getKey(), this);
				button = getUI().newButton((String) it.next(), this);
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
				+ " build " + scriptVersion);
		}
		setTrail(null == status && enableButtons
				? (viewOffset+1)+"-"+end+"/"+viewList.size()
				: null, null);
		prevPageButton.setEnabled(enableButtons);
		nextPageButton.setEnabled(enableButtons);
		prevLevelButton.setEnabled(level>0);

		// just to be on the safe side
		entriesPanel.invalidate();
		entriesPanel.repaint();
		context.getRootContainer().invalidate();
		context.getRootContainer().repaint();
	}

	private boolean simplyMatches(String way, String target) {
	//Since the input regex 'way' always looks like this:
	//  ^<pairs of hex digits>..<pair of hex digits>$
	//we can avoid regex engine overhead with simpler region matches

		int dot = way.indexOf(".");
		int len = target.length();
		return way.regionMatches(1, target, 0, dot-1) &&
			way.regionMatches(dot+2, target, len-2, 2) &&
			way.length()-2 == len;
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
		return 54; //FIXME
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
		String name = button.getName();
		String cmd = (String) levelMap[level].get(name);
		// user_cmd ::= dir ';' cmd ';' [kindlet_options] '/' button_levelSnpath
		int p = cmd.lastIndexOf("/");
		String levelSnpath = cmd.substring(p+1);
		cmd = cmd.substring(0, p);
		p = cmd.lastIndexOf(";");
		String options = cmd.substring(p+1);
		cmd = cmd.substring(0, p);
		String dir = null;
		if(-1 != (p = cmd.indexOf(";"))) {
			dir = cmd.substring(0, p);
			cmd = cmd.substring(1+p);
		}
//DEBUG del//setStatus("dir("+dir+") cmd("+cmd+")"); if(true) return;

		if (cmd.startsWith("^")) { // dive into sub-menu
					//name,       origin,     way (how to get there)
			trail[level][0] = name;
		        trail[level][1] = levelSnpath;
		        trail[level][2] = cmd;
			try {
				handleLevel(LEVEL_NEXT);
			} catch (Throwable ex) {
				String report = ex.getMessage();
				setStatus(report);
			}
		} else if (cmd.startsWith("#")) { // run kindlet function
			// '#' int_id ';' String_args
			cmd = cmd.substring(1);
			int id = -1;
			p = cmd.indexOf(";");
			try {
				id = Integer.parseInt((String) cmd.substring(0,p));
			} catch (Throwable ex) {
				setStatus(ex.getMessage());
			}
			cmd = cmd.substring(p+1);
			switch (id) {
				case 1: setTrail(cmd, null);
				case 2: setStatus(cmd);
			}
			if (-1 == options.indexOf("e")) {
				// suicide
				commandToRunOnExit = "true";
				dirToChangeToOnExit = dir;
				getUI().suicide(context);
			}
		} else { // run cmd
			if (-1 == options.indexOf("e")) {
				// suicide
				try {
					setStatus(cmd);
					commandToRunOnExit = cmd;
					dirToChangeToOnExit = dir;
					getUI().suicide(context);
				} catch (Throwable ex) {
					String report = ex.getMessage();
					setStatus(report);
				}
			} else {
				// live
				try {
					execute(cmd, dir, true);
				} catch (Exception ex) {
					String report = ex.getMessage();
					setStatus(report);
				}
			}
		}
	}

	private Process execute(String cmd, String dir, boolean background) throws IOException,
			InterruptedException {

		File launcher = createLauncherScript(cmd, background,
				"export KUAL='/bin/ash " + parseFile.getAbsolutePath() + " -x '; ");
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
		bw.write("{ " + init + cmd + " ; } 2>/var/tmp/KUAL.log"
				+ (background ? " &" : ""));

		bw.newLine();
		bw.close();
		return tempFile;
	}
}
