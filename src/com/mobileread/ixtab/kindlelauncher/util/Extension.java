
package com.mobileread.ixtab.kindlelauncher.util;

//import com.mobileread.ixtab.kindlelauncher.util.Menuable;

/**
 * This class represents the extension and is parsed by the config.xml file.
 * Currently, the only thing of use is the {@link Menuable}, which
 * holds the menu items.
 *
 * @author Yifan Lu - Ixtab - Twobob
 * @version 1.1
 */
public class Extension {
    private String mName;
    private String mVersion;
    private String mAuthor;
    private String mId;
    private JSONMenu mMenu;
   // private Menuable mMenu;

    /**
     * We want all the fields to be set by the parser, but we place default values in just in case.
     */
    public Extension() {
        this.mName = "Plugin";
        this.mVersion = "0.0";
        this.mAuthor = "Author";
        this.mId = super.toString();
    }

    /**
     * Sets the name of the extension.
     *
     * @param name The name of the extension.
     */
    public void setName(String name) {
        this.mName = name;
    }

    /**
     * Gets the name of the extension.
     * This is currently unused.
     *
     * @return The name of the extension.
     */
    public String getName() {
        return this.mName;
    }

    /**
     * Sets the version of the extension.
     *
     * @param version The version of the extension.
     */
    public void setVersion(String version) {
        this.mVersion = version;
    }

    /**
     * Gets the version of the extension.
     * This is currently unused.
     *
     * @return The version of the extension.
     */
    public String getVersion() {
        return this.mVersion;
    }

    /**
     * Sets the author of the extension.
     *
     * @param author The author of the extension.
     */
    public void setAuthor(String author) {
        this.mAuthor = author;
    }

    /**
     * Gets the author of the extension.
     * This is currently unused.
     *
     * @return The author of the extension.
     */
    public String getAuthor() {
        return this.mAuthor;
    }

    /**
     * Sets the id of the extension. Must be unique.
     *
     * @param id The id of the extension.
     */
    public void setId(String id) {
        this.mId = id;
    }

    /**
     * Gets the id of the extension.
     * This is currently unused.
     *
     * @return The id of the extension.
     */
    public String getId() {
        return this.mId;
    }

    /**
     * Gets the menu options for this extension.
     *
     * @return The menu options for this extension.
     * @see com.yifanlu.Kindle.Menuable
    
    public Menuable getMenu() {
        return this.mMenu;
    }
 */
    
    public JSONMenu getMenu() {
        return this.mMenu;
    }
    
    /**
     * Sets the menu options for this extension.
     *
     * @param menu The menu option for this extension.
     * @see com.yifanlu.Kindle.Menuable
     
    public void setMenu(Menuable menu) {
        this.mMenu = menu;
    }
    */
    
    public void setMenu(JSONMenu menu) {
        this.mMenu = menu;
    }
    
}
