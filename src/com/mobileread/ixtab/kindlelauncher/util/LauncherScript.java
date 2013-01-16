/**
 * Kindle Launcher
 * GUI menu launcher for Kindle Touch
 * Copyright (C) 2011  Yifan Lu
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
package com.mobileread.ixtab.kindlelauncher.util;

import java.io.File;

import com.mobileread.ixtab.kindlelauncher.util.JSONMenu;
//import com.mobileread.ixtab.kindlelauncher.LauncherKindlet;
import com.mobileread.ixtab.kindlelauncher.util.LauncherAction;

/**
 * A menu item that executes a shell command.
 *
 * @author Yifan Lu, Ixy, Tb
 * @version 1.1
 * @see JSONMenu
 */
public class LauncherScript extends LauncherAction {
	//private static final long serialVersionUID = 1L;
	
	private File mScript;
    private String mArgs;

    /**
     * Creates a new launch script menu item.
     *
     * @param name     The text to show
     * @param priority The order of this item in comparison to others
     * @param script   The shell script or command to run
     * @param args     The arguments of the script
     */
    public LauncherScript(String name, int priority, File script, String args) {
        super(name, priority);
        this.mScript = script;
        this.mArgs = args;
    }

    /**
     * Executes the shell command with parameters
     */
    public synchronized void doAction() {
      //  String out[];// = new StringBuffer();
      //  StringBuffer err = new StringBuffer();
      //  KindleLauncher.SERVICES.getDeviceService().exec(mScript.getAbsolutePath() + " " + mArgs, out, err);
  
    	try{
        Runtime.getRuntime().exec(mScript.getAbsolutePath() + " " + mArgs);
    
		
	} catch (Throwable ex) {	
	} 
    }
}
