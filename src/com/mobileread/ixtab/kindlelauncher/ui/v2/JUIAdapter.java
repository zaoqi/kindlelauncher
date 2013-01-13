package com.mobileread.ixtab.kindlelauncher.ui.v2;

import java.awt.Component;
import java.awt.Container;
import java.awt.LayoutManager;
import java.awt.event.ActionListener;

import javax.swing.JButton;
import javax.swing.JLabel;
import javax.swing.JPanel;

import com.mobileread.ixtab.kindlelauncher.ui.UIAdapter;

public class JUIAdapter extends UIAdapter {

	public Container newPanel(LayoutManager layout) {
		return layout != null ? new JPanel(layout) : new JPanel();
	}

	public Component newLabel(String text) {
		return new JLabel(text);
	}

	public Component newButton(String text, ActionListener listener) {
		JButton button = new JButton(text);
		button.addActionListener(listener);
		return button;
	}

	public void setText(Component component, String text) {
		if (component instanceof JLabel) {
			((JLabel) component).setText(text);
		}
	}

}
