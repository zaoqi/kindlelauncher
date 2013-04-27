package com.mobileread.ixtab.kindlelauncher.resources;

import java.io.BufferedReader;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.Map.Entry;

public class KualConfig {

	private final HashMap configMap = new HashMap();
	private String mailboxPath;
	private String version;

	// constructor
	public KualConfig(BufferedReader reader) throws IOException, InterruptedException,
		NumberFormatException, Exception {

		configMap.clear();

		try {
			// read meta info: version, mailboxpath
			int size = Integer.parseInt(reader.readLine());
			for (int i = 1; i <= size; i++) {
				configMap.put("meta" + Integer.toString(i), reader.readLine());
			}
			version = get("meta1");
			mailboxPath = get("meta2");

			// read user configuration - pre-formatted from KUAL.cfg
			size = Integer.parseInt(reader.readLine());
			for(int i = 1; i <= size; i++) {
				String line = reader.readLine();
				int p = line.indexOf('=');
				if (p > 0) {
					configMap.put(line.substring(0, p), line.substring(p+1));
				}
			}
		} catch (Throwable t) {
			throw new Exception(t.getMessage());
		}
	}

	// methods
	public String get(String name) {
		return (String) configMap.get(name);
		/* script unquotes for me
		String value = (String) configMap.get(name);
		if (value == null)
			return null;
		if (value.startsWith("\"") && value.endsWith("\""))
			value = value.substring(1,value.lastIndexOf("\""));
		return value;
		*/
	}

	public String getVersion() {
		return version;
	}

	public String getMailboxPath() {
		return mailboxPath;
	}
}
