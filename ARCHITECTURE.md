## Data storage

    Assisted-by: aider 0.86.2 + gemini/gemini-3.1-pro-preview

Based on the code provided and the standard behavior of the libraries WebPin
uses (GLib, GTK, WebKitGTK), here is a summary of where the application writes
data:

1. Web App `.desktop` Files
  * **Location:** `~/.local/share/applications/` (via
    `GLib.Environment.get_user_data_dir () + "/applications/"`)
  * **What:** The launcher files for each created web app (e.g.,
    `MyApp-webpin.desktop`). This stores the URL, icon path, and
    WebPin-specific settings (like `X-Webpin-CookieDB`).

2. Cookie Databases
  * **Location:** `~/.cache/com.github.artemanufrij.webpin/` (via
    `Environment.get_user_cache_dir () + "/" + Webpin.APP_ID + "/"`)
  * **What:** SQLite databases containing persistent cookies for apps that have
    the "Save cookies" option enabled.

3. Downloaded Icons
  * **Location:** `~/.cache/com.github.artemanufrij.webpin/` (Assuming this is
    what `WebpinApp.instance.CACHE_FOLDER` resolves to) and temporarily in
    `/tmp/` (via `Environment.get_tmp_dir ()`).
  * **What:** When you create an app and WebPin automatically fetches the
    website's icon, it downloads it to `/tmp/` and then moves it to the app's
    cache folder.

4. Application Settings (State Data)
  * **Location:** `~/.config/dconf/user` (Managed by the system's `dconf` service).
  * **What:** General app preferences. WebPin uses `GSettings` (indicated by
    `schemas/com.github.artemanufrij.webpin.gschema.xml` and
    `src/Settings.vala`), which writes to the standard dconf database under the
    `com.github.artemanufrij.webpin` path.

5. WebKit Cache and Local Storage
  * **Location:** Typically `~/.cache/com.github.artemanufrij.webpin/` and
    `~/.local/share/com.github.artemanufrij.webpin/` (or
    `~/.local/share/webkitgtk/`).
  * **What:** Because WebPin creates a `WebKit.WebContext` without explicitly
    overriding the base data directory, WebKitGTK automatically uses the
    standard XDG directories based on the application's ID to store web cache,
    LocalStorage, IndexedDB, and service workers.
