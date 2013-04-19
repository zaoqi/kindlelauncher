package com.mobileread.ixtab.kindlelauncher;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;

public class Util {

	public static void copy(InputStream is, OutputStream os) throws IOException {
		byte[] buffer = new byte[4096];
		int bytesRead;
		while ((bytesRead = is.read(buffer)) != -1) {
			os.write(buffer, 0, bytesRead);
		}
		os.flush();
		os.close();
	}

	public static BufferedReader execute(String scriptName) throws IOException,
			InterruptedException {
		//String[] cmd = new String[] { "/bin/ash", scriptName };
		String[] cmd = new String[] { "/usr/bin/awk", "-f", scriptName };

		Process process = Runtime.getRuntime().exec(cmd, null);
		//process.waitFor(); //stepk

		BufferedReader input = new BufferedReader(new InputStreamReader(
				process.getInputStream()));
process.getOutputStream().close(); // start input
		return input;
	}
}
