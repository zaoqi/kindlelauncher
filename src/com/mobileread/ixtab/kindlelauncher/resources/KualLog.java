package com.mobileread.ixtab.kindlelauncher.resources;

import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.IOException;

public class KualLog {

	private final String logfilePath = "/var/tmp/KUAL.log";

	// constructor

	// methods
	public void append(String line) {
		try {
			BufferedWriter bw = new BufferedWriter(new FileWriter(logfilePath, true));
			bw.write("KUAL: " + line);
			bw.newLine();
			bw.close();
		} catch (IOException t) {
			//
		}
	}
}
