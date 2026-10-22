# WebPin Roadmap

    Assisted-by: aider 0.86.2 + gemini/gemini-3.1-pro-preview

## [DONE] True Per-App Isolation

_Implemented in 9e3db6d_.

Currently, WebPin isolates cookies per web app by creating a new
`WebKit.WebContext` and setting a specific cookie database path. However, other
web data such as cache blobs (`WebKitCache`), LocalStorage, IndexedDB, and
service workers are still pooled together in the default application cache and
data directories.

To achieve complete isolation for each web app:

* Initialize the `WebKit.WebContext` with a custom `WebKit.WebsiteDataManager`.
* Specify a unique base data directory and cache directory for each app using
  the `WebsiteDataManager`.
* This will ensure that cache files and local storage are completely separated
  and identifiable per app.

### Pros and Cons of `new WebKit.WebContext()` vs `WebKit.WebContext.get_default()`

For a site-specific browser like WebPin—where every app already runs in its own
isolated OS process (via MD5 hash `application_id`)—the calculation for using a
custom context is specific:

**The Downsides (Cons) of `new WebKit.WebContext ()`**

1. **Process and Memory Overhead:** WebKitGTK uses a multi-process
   architecture. The `get_default()` context is highly optimized. When you
   create a *new* context, WebKit may spin up a completely separate Network
   Process just for that context, meaning slightly higher RAM usage and startup
   time per web app.
2. **Cache Locking / Race Conditions:** If you use `new WebKit.WebContext()`
   *without* also giving it a custom `WebsiteDataManager`, multiple independent
   contexts (across different OS processes) all try to read and write to the
   exact same default `~/.cache/.../WebKitCache/` folder. This can lead to
   SQLite database locks or cache corruption.

**The Upsides (Pros) of `new WebKit.WebContext ()`**

1. **It is the *only* path to True Isolation:** You cannot easily change the
   base data directories of the default context. To achieve true per-app
   isolation (LocalStorage, IndexedDB, Cache), you *must* instantiate a `new
   WebKit.WebContext` and pass it a custom `WebKit.WebsiteDataManager` pointing
   to a unique folder.
2. **Future-Proofing:** If WebPin ever changes to run as a single background
   process managing all open web apps, custom contexts will be mandatory to
   prevent apps from sharing the same cookie manager and cache in memory.
