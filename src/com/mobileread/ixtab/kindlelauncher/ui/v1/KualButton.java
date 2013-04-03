package com.mobileread.ixtab.kindlelauncher.ui.v1;

import java.awt.Color;
import java.awt.Font;
import java.awt.FontMetrics;
import java.awt.Graphics;

import com.amazon.kindle.kindlet.ui.KButton;

public class KualButton extends KButton {

	private static final long serialVersionUID = 1L;

	private static final Color COLOR_FOREGROUND = Color.BLACK;
	private static final Color COLOR_BACKGROUND = Color.WHITE;
	private static final Color COLOR_DISABLED = Color.LIGHT_GRAY;
	private static final int BORDER_PX = 2;
	private static final int GAP_PX = 0;
	private static final int ARC_PX = 15;

	public KualButton(String text) {
		super(text);
	}

	public void paint(Graphics g) {
		Color foreground = isEnabled() ? COLOR_FOREGROUND : COLOR_DISABLED;
		Color background = COLOR_BACKGROUND;

		int width = getWidth();
		int height = getHeight();
		Font font = getFont();
		FontMetrics fm = this.getFontMetrics(font);

		g.setColor(foreground);
		g.fillRoundRect(GAP_PX, GAP_PX, width - GAP_PX * 2, height
				- GAP_PX * 2, ARC_PX, ARC_PX);

		if (hasFocus()) {
			background = foreground;
			foreground = getBackground();
		} else {
			g.setColor(background);
			g.fillRoundRect(GAP_PX + BORDER_PX, GAP_PX + BORDER_PX,
					width - (GAP_PX + BORDER_PX) * 2, height
							- (GAP_PX + BORDER_PX) * 2, ARC_PX, ARC_PX);
		}

		String text = getLabel();

		int tx = (width / 2) - (fm.stringWidth(text) / 2);
		int ty = (height / 2) + (fm.getHeight() / 2);

		g.setColor(foreground);
		g.setFont(font);
		g.drawString(text, tx, ty);
	}

}
