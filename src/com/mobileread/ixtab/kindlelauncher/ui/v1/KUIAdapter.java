package com.mobileread.ixtab.kindlelauncher.ui.v1;

import java.awt.Component;
import java.awt.Container;
import java.awt.LayoutManager;
import java.awt.event.ActionListener;

import com.amazon.kindle.kindlet.ui.KButton;
import com.amazon.kindle.kindlet.ui.KLabel;
import com.amazon.kindle.kindlet.ui.KPanel;
import com.mobileread.ixtab.kindlelauncher.ui.UIAdapter;

public class KUIAdapter extends UIAdapter {

	public Container newPanel(LayoutManager layout) {
		return layout != null ? new KPanel(layout) : new KPanel();
	}

	public Component newLabel(String text) {
		return new KLabel(text);
	}

	public Component newButton(String text, ActionListener listener) {
		KButton button = new KButton(text);
		button.addActionListener(listener);
		return button;
	}

	public void setText(Component component, String text) {
		if (component instanceof KLabel) {
			((KLabel) component).setText(text);
			component.repaint();
		}
	}

}
