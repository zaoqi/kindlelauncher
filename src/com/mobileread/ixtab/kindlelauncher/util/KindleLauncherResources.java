
package com.mobileread.ixtab.kindlelauncher.util;

import java.util.ListResourceBundle;

/**
 * Localization for the Launcher menu.
 *
 * @author Yifan Lu - Ixtab - Twobob
 * @version 1.1
 */
public class KindleLauncherResources extends ListResourceBundle {
    /**
     * Labels and their associated text
     */
    static final Object[][] RESOURCES = {
            {"menu.launcher.label", "Launcher"},
            {"menu.launcher.next_page.label", "Next Page"},
            {"menu.launcher.previous_page.label", "Previous Page"}
    };

    /**
     * Gets the labels and their associated text
     *
     * @return localization strings
     */
    protected Object[][] getContents() {
        return RESOURCES;
    }
}
