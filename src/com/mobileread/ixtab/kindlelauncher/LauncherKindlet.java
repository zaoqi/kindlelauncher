package com.mobileread.ixtab.kindlelauncher;

import java.awt.BorderLayout;
import java.awt.Component;
import java.awt.Container;
import java.awt.GridLayout;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;

import com.amazon.kindle.kindlet.AbstractKindlet;
import com.amazon.kindle.kindlet.KindletContext;
import com.mobileread.ixtab.kindlelauncher.ui.UIAdapter;

public class LauncherKindlet extends AbstractKindlet implements ActionListener {

	private KindletContext context;
	private Container panel;
	
	// temporary, for testing.
	private Component button1, button2, status;
	
	public void create(KindletContext context) {
		this.context = context;
	}

	public void destroy() {
		// TODO Auto-generated method stub
		super.destroy();
	}

	public void start() {
		// just in case, it's probably not needed.
		if (panel == null) {
			panel = getUI().newPanel(new BorderLayout());
		} else {
			panel.removeAll();
		}
		
		Container root = context.getRootContainer();
		root.setLayout(new BorderLayout());
		// again, just in case
		root.removeAll();
		
		root.add(panel, BorderLayout.CENTER);
		
		/* everything below here is experimental. */
		root.add(getUI().newLabel("sample label: north"), BorderLayout.NORTH);
		
		// those "200" bits are also only for testing.
		GridLayout grid = new GridLayout(2, 1, 200, 200);
		Container buttonsPanel = getUI().newPanel(grid);
		
		
		button1 = getUI().newButton("BUTTON 1", this);
		button2 = getUI().newButton("BUTTON 2", this);
		buttonsPanel.add(button1);
		buttonsPanel.add(button2);
		
		root.add(buttonsPanel, BorderLayout.CENTER);
		
		status = getUI().newLabel("sample label: south");
		root.add(status, BorderLayout.SOUTH);
	}

	public void stop() {
		// TODO Auto-generated method stub
		super.stop();
	}

	public void actionPerformed(ActionEvent e) {
		Object src = e.getSource();
		if (src == button1) {
			setStatus("button 1 was pressed");
		} else if (src == button2) {
			setStatus("button 2 was pressed");
		};
	}
	
	private void setStatus(String text) {
		getUI().setText(status, text);
	}

	// pure convenience method.
	private static UIAdapter getUI() {
		return UIAdapter.INSTANCE;
	}
}
