package com.mobileread.ixtab.kindlelauncher;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.StringTokenizer;

public class Util {
	public static String[] splitLine(String input, String delim) {
		StringTokenizer st = new StringTokenizer(input, delim);
		List result = new ArrayList();
		while (st.hasMoreElements()) {
			result.add(st.nextElement());
		}
		String[] split = new String[result.size()];
		for (int i = 0; i < split.length; ++i) {
			split[i] = (String) result.get(i);
		}
		return split;

	}

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
	//	String cmd[] = new String[] { "/bin/sh", scriptName };
		String cmd[] = new String[] { "/bin/sh", scriptName, " -f=twolevel -s" };
		Process process = Runtime.getRuntime().exec(cmd, null);
		process.waitFor();

		BufferedReader input = new BufferedReader(new InputStreamReader(
				process.getInputStream()));
		return input;
	}

}
