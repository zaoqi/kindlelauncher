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
	private static Font defaultFont = null;
	private static FontMetrics defaultFontMetrics = null;
	private static Font unicodeFont = null;
	private static FontMetrics unicodeFontMetrics = null;

	public KualButton(String text) {
		super(text);
	}

	public void paint(Graphics g) {
		setupFontsIfNeeded();

		Color foreground = isEnabled() ? COLOR_FOREGROUND : COLOR_DISABLED;
		Color background = COLOR_BACKGROUND;

		int width = getWidth();
		int height = getHeight();
		
		// paint border and adjust colors if needed:

		g.setColor(foreground);
		g.fillRoundRect(GAP_PX, GAP_PX, width - GAP_PX * 2,
				height - GAP_PX * 2, ARC_PX, ARC_PX);

		if (hasFocus()) {
			background = foreground;
			foreground = COLOR_BACKGROUND;
		} else {
			g.setColor(background);
			g.fillRoundRect(GAP_PX + BORDER_PX, GAP_PX + BORDER_PX, width
					- (GAP_PX + BORDER_PX) * 2, height - (GAP_PX + BORDER_PX)
					* 2, ARC_PX, ARC_PX);
		}

		// now paint the text:
		g.setColor(foreground);
		
		String text = getLabel();
		char[] chars = text.toCharArray();
		
		int ty = (height / 2) + (defaultFontMetrics.getHeight() / 2);
		
		if (unicodeFontMetrics == null || isAsciiText(chars)) {
			// simple case: no Unicode, so we just do with the default font.
			int tx = (width / 2) - (defaultFontMetrics.stringWidth(text) / 2);

			g.setFont(defaultFont);
			g.drawString(text, tx, ty);
			return;
		}
		
		int[] offsets = calculateOffsets(chars);
		int tx = (width / 2) - (offsets[chars.length] / 2);
		for (int i=0; i < chars.length; ++i) {
			g.setFont(isUnicode(chars[i]) ? unicodeFont : defaultFont);
			g.drawChars(chars, i, 1, tx + offsets[i], ty);
		}
	}
	
	private boolean isAsciiText(char[] chars) {
		for (int i=0; i < chars.length; ++i) {
			if (isUnicode(chars[i])) {
				return false;
			}
		}
		return true;
	}
	
	private boolean isUnicode(char c) {
		return c > 256;
	}

	private int[] calculateOffsets(char[] chars) {
		int[] offsets = new int[chars.length+1];
		FontMetrics fm;
		for (int i=1; i <= chars.length; ++i) {
			char c = chars[i-1];
			fm = isUnicode(c) ? unicodeFontMetrics : defaultFontMetrics;
			offsets[i] = offsets[i-1] + fm.charWidth(c);
		}
		return offsets;
	}

	private synchronized void setupFontsIfNeeded() {
		if (defaultFont != null) {
			return;
		}

		defaultFont = getFont();
		defaultFontMetrics = getFontMetrics(defaultFont);

		try {
			unicodeFont = new Font("code2000", defaultFont.getStyle(),
					defaultFont.getSize());
			unicodeFontMetrics = getFontMetrics(unicodeFont);
		} catch (Throwable t) {
		}
	}

}
