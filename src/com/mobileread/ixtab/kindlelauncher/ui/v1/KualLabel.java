package com.mobileread.ixtab.kindlelauncher.ui.v1;

import java.awt.Color;
import java.awt.Font;
import java.awt.FontMetrics;
import java.awt.Graphics;

import com.amazon.kindle.kindlet.ui.KLabel;

public class KualLabel extends KLabel {

	private static final long serialVersionUID = 1L;

	private static final Color COLOR_FOREGROUND = Color.BLACK;
//	private static final Color COLOR_BACKGROUND = Color.WHITE;
//	private static final Color COLOR_DISABLED = Color.LIGHT_GRAY;
	private static Font defaultFont = null;
	private static FontMetrics defaultFontMetrics = null;
	private static Font unicodeFont = null;
	private static FontMetrics unicodeFontMetrics = null;

	public KualLabel(String text) {
		super(text);
	}

	public void paint(Graphics g) {
		setupFontsIfNeeded();

		Color foreground = COLOR_FOREGROUND;

		int width = getWidth();
		int height = getHeight();
		
		// paint the text:
		g.setColor(foreground);
		
		String text = getText();
		char[] chars = text.toCharArray();
		
		int ty;
		
		if (unicodeFontMetrics == null || isAsciiText(chars)) {
			// http://stackoverflow.com/questions/1055851/how-do-you-draw-a-string-centered-vertically-in-java
			ty = height+((0+1-height)/2) - 1
				- (defaultFontMetrics.getAscent() + defaultFontMetrics.getDescent())/2
				+ defaultFontMetrics.getAscent();

			// simple case: no Unicode, so we just do with the default font.
			int tx = 0; //(width / 2) - (defaultFontMetrics.stringWidth(text) / 2);

			g.setFont(defaultFont);
			g.drawString(text, tx, ty);
			return;
		}

		// http://stackoverflow.com/questions/1055851/how-do-you-draw-a-string-centered-vertically-in-java
		ty = height+((0+1-height)/2) - 1
			- (unicodeFontMetrics.getAscent() + unicodeFontMetrics.getDescent())/2
			+ unicodeFontMetrics.getAscent();
		
		int[] offsets = calculateOffsets(chars);
		int tx = 0; //(width / 2) - (offsets[chars.length] / 2);
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
