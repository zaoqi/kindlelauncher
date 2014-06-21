package com.mobileread.ixtab.kindlelauncher.ui.v2;

import java.awt.Component;
import java.awt.Container;
import java.awt.Font;
import java.awt.LayoutManager;
import java.awt.event.ActionListener;
import java.awt.event.KeyListener;

import javax.swing.JButton;
import javax.swing.JLabel;
import javax.swing.JPanel;

import com.amazon.kindle.kindlet.KindletContext;
import com.mobileread.ixtab.kindlelauncher.ui.UIAdapter;
import com.mobileread.ixtab.kindlelauncher.resources.KualEntry;

public class JUIAdapter extends UIAdapter {

	public Container newPanel(LayoutManager layout) {
		return layout != null ? new JPanel(layout) : new JPanel();
	}

	public Component newLabel(String text) {
		JLabel label = new JLabel(text);
		// Die in a fire, Helvetica!
		Font defaultFont = label.getFont();
		// NOTE: On K5 devices without Futura (< 5.3), this is mostly harmless, only the style (Regular instead of Bold) is applied...
		label.setFont(new Font("Futura", Font.PLAIN, defaultFont.getSize()));
		return label;
	}

	public Component newButton(String text, ActionListener listener, KeyListener keyListener, KualEntry kualEntry) {
		JButton button = new KualButton(text, kualEntry);
		// Die in a fire, Helvetica!
		Font defaultFont = button.getFont();
		// I wish we could use Futura DemiBold, but Amazon's fontconfig setup smushes it into the Futura family, with a custom demibold style...
		// Meaning we can't access it in Java, and apparently we can't do it ourselves either because createFont isn't supported... :/
		button.setFont(new Font("Futura", Font.PLAIN, defaultFont.getSize()));
		if (listener != null) {
			button.setName(text);
			button.addActionListener(listener);
		}
		// No physical keys on these devices, don't do anything with the KeyListener...
		return button;
	}

	public void setText(Component component, String text) {
		if (component instanceof JLabel) {
			((JLabel) component).setText(text);
		}
		if (component instanceof JButton) {
			((JButton) component).setText(text);
		}
	}

	public void suicide(KindletContext context) {
		try {
			// Until something better turns up...
			Runtime.getRuntime()
					.exec("lipc-set-prop com.lab126.appmgrd stop app://com.lab126.booklet.kindlet");
		} catch (Throwable ex) {
		}
	}

	public int getDefaultPageSize() {
		// these are Touch models, so having more information on one page seems reasonable.
		return 10;
	}

	public KualEntry getKualEntry(Component component) {
		if (component instanceof KualButton)
			return ((KualButton) component).getKualEntry();
		return null;
	}
}
