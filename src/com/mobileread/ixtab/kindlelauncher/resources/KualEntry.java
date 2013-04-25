package com.mobileread.ixtab.kindlelauncher.resources;

public class KualEntry {

	public String id; // is unique
	public String label;
	public boolean isSubmenu = false;
	public boolean isInternalAction = false;
	public int internalAction;
	public String internalArgs;
	public int level;
	private String levelSnpath;
	public String action;
	public String dir = null;
	public String options = null;

	private String snpath; // parser generates this unique value

	//constructors
	public KualEntry(String options, String levelSnpath, String label, String action) throws Exception {
		if (null == levelSnpath || null == label || null == action)
			throw(new Exception("invalid entry"));
		int p;
		try {
			this.options = options; // "exitmenu", "reload", etc. as a string of single characters
			this.levelSnpath = this.id = levelSnpath; // level ':' snpath
			p = levelSnpath.indexOf(":");
			this.level = Integer.parseInt((String) levelSnpath.substring(0,p));
			this.snpath = levelSnpath.substring(p+1);
			this.action = action; // [ "/dir" ';' ] ('^'|'#') "xyz"
			this.isSubmenu = action.startsWith("^");
			this.isInternalAction = action.startsWith("#");
			if (this.isSubmenu) {
				this.label = label + " \u25BD"; // 25B6 > ; 25BC V  25BD v
				this.dir = null;
			} else {
				this.label = label;
				// split dir';'action
				p = this.action.indexOf(";");
				this.dir = this.action.substring(0, p);
				this.action = this.action.substring(p + 1);
			}
			if (this.isInternalAction) {
				// split '#' int_id ';' String_args
				p = this.action.indexOf(";");
				this.internalAction = Integer.parseInt(this.action.substring(1,p));
				this.internalArgs = this.action.substring(p + 1);
			}
		} catch (Throwable t) {
			throw new Exception("invalid entry");
		}
	}

	public KualEntry(int instanceId, String label) {
		switch (instanceId) {
		case 0: // error button displayed upon reading corrupted menu records
			this.options = "e";
			this.levelSnpath = this.id = "0:ff";
			this.level = 0;
			this.snpath = "ff";
			this.action = "#1;Try restarting \u266B"; // trail message
			this.dir = "";
			this.isSubmenu = false;
			this.isInternalAction = true;
			this.internalAction = 1;
			this.internalArgs = "Try restarting \u266B";
			this.label = label;
			break;
		case 3: // toTopButton
			this.options = "e";
			this.levelSnpath = this.id = ""; // doesn't matter since this one never gets stored in levelMap[]
			this.level = 0;
			this.dir = "";
			this.isSubmenu = false;
			this.isInternalAction = true;
			this.internalAction = 3;
			break;
		case 4: // quitButton
			this.levelSnpath = this.id = ""; // doesn't matter since this one never gets stored in levelMap[]
			this.level = 0;
			this.action = ":";
			this.dir = "/var/tmp";
			this.isSubmenu = false;
			this.isInternalAction = true;
			this.internalAction = 4;
			this.label = label;
			break;
		default:
			this.options = "e";
			this.levelSnpath = this.id = "0:ff";
			this.level = 0;
			this.snpath = "ff";
			this.action = "#1;Error \u266B"; // trail message
			this.dir = "/var/tmp";
			this.isSubmenu = false;
			this.isInternalAction = true;
			this.internalAction = 1; // trail message
			this.internalArgs = "Error \u266B";
			this.label = label;
			break;
		}
	}

	//methods
	public boolean hasOption(char option) {
		return null == this.options ? false : 0 <= this.options.indexOf(option);
	}

	public void setChecked(boolean enable) {
		boolean isChecked = this.label.startsWith("\u2717"); // X
		if (enable && ! isChecked)
			this.label = "\u2717 " + this.label;
		else if (isChecked)
			this.label = this.label.substring(2);
	}

	//submenu methods TODO move into its own class
	public String getBareLabel() {
		return this.label.substring(0, this.label.length() - 2);
	}

	public int getGoToLevel() {
		try {
			return Integer.parseInt(this.action.substring(1, this.action.indexOf(":")));
		} catch (Throwable t) {
			return 0;
		}
	}

	public String getParentLink() {
		return this.action;
	}

	public boolean isLinkedUnder(String linkerToThis) {
	//Since regex linkerToThis always looks like this:
	//  ^<pairs of hex digits>..<pair of hex digits>$
	//we can avoid regex engine overhead with simpler region matches

		int dot = linkerToThis.indexOf(".");
		int len = this.levelSnpath.length();
		return linkerToThis.regionMatches(1, this.levelSnpath, 0, dot-1) &&
			linkerToThis.regionMatches(dot+2, this.levelSnpath, len-2, 2) &&
			linkerToThis.length()-2 == len;
	}

}
