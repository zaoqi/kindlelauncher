package com.mobileread.ixtab.kindlelauncher.ui.v1;

import java.awt.Component;
import java.awt.Container;
import java.awt.LayoutManager;
import java.awt.event.ActionListener;
import java.awt.event.KeyEvent;

import com.amazon.kindle.kindlet.KindletContext;
import com.amazon.kindle.kindlet.event.KindleKeyCodes;
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
		if (listener != null) {
			button.setName(text);
			button.addActionListener(listener);
		}
		return button;
	}

	public void setText(Component component, String text) {
		if (component instanceof KLabel) {
			((KLabel) component).setText(text);
			component.repaint();
		}
	}

	public void suicide(KindletContext context) {
		int code = KindleKeyCodes.VK_BACK;
		//code = 61442;
		KeyEvent k = new KeyEvent(context.getRootContainer(), KeyEvent.KEY_PRESSED, System.currentTimeMillis(), 0, code, (char)0);
		context.getRootContainer().dispatchEvent(k);
	}

	public int getDefaultPageSize() {
		// these are non-touch models, so it's tedious to scroll.
		return 5;
	}
	
}
