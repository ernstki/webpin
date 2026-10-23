# WebPin Roadmap

    Assisted-by: aider 0.86.2 + gemini/gemini-3.1-pro-preview

## Icon cleanup

Icons for the web apps are just dumped, often with no extension, into
`~/.cache/com.github.artemanufrij.webpin`. I think those should be, firstly, in
`~/.local/share` instead, and that they should be inside per-app directories,
named something like `icon.png`.

We'll also want, like, a `sed` command or something in the README (at a
minimum), to update all the existing `.desktop` files, or else try to do it at
run-time in Vala code.


## Domain restriction (like Fluid.app)

In response to my question:

> ok, let's think about that "domain restriction logic" again. what's the
> simplest thing that could possibly work, which doesn't require UI to
> configure a white list? It'd ALMOST be sufficient to use the top-level domain
> of the URL associated with the web app, except that Microsoft 365 apps
> nowadays use six different crazy-ass URLs in TLDs I've never even heard of
> before, so that wouldn't work there. What would you propose?

Gemini responded with this cogent advice:

> This is the classic Site-Specific Browser (SSB) dilemma. You've hit the nail on
> the head: modern web ecosystems like Microsoft 365, Google Workspace, and
> Atlassian use a tangled web of domains (`office.com`, `sharepoint.com`,
> `live.com`, `microsoftonline.com`). If you strictly lock the app to the base
> domain, you break Single Sign-On (SSO) and cross-app navigation.
>
> If we want the **simplest thing that could possibly work with zero
> configuration**, I propose we actually **don't restrict same-window navigation
> at all**, and instead rely entirely on two things:
>
> ### 1. Rely on `target="_blank"` (The `create` signal)
>
> Web developers almost universally follow a standard convention:
>
> * Internal app navigation (even across their own weird domains like
>   `office.com` to `sharepoint.com`) happens in the **same tab**.
> * Links to truly external websites (e.g., a Wikipedia link inside a Word
>   document) are given `target="_blank"` to open in a **new tab**.
>
> Because we just fixed the `create` signal in `Browser.vala` to intercept new
> window requests and pass them to `xdg-open`, **Webpin is already handling 95%
> of external links perfectly.** They will automatically pop out to
> Firefox/Chrome.
>
> ### 2. The Context Menu (User Override)
>
> For the remaining 5% of external links that don't have `target="_blank"`, the
> user can just right-click and use the **"Open Link in Default Browser"**
> context menu item we just discussed.
>
> If they accidentally left-click an external link and navigate away from the
> app, Webpin already has a "Back" button and a "Home" button in the header bar
> to instantly recover.
>
> ### Why other programmatic heuristics fail:
>
> If you *really* wanted to block same-window navigation programmatically
> without a whitelist, you'd have to try something like:
>
> * **Checking if it's a redirect vs. a click:** (Allow redirects for SSO, block
>   clicks). But MS365's "App Launcher" waffle menu uses explicit clicks to jump
>   from `office.com` to `sharepoint.com`. It would block them.
> * **Checking CORS/Referrer headers:** Too complex and unreliable.
>
> ### My Recommendation
>
> Keep it simple.
>
> 1. Let the `create` signal handle `target="_blank"` links (which routes them
>    to the default browser).
> 2. Add the "Open Link in Default Browser" context menu item.
> 3. Trust the user to use the "Back" or "Home" button if they wander off-site
>    in the main view.
>
> If you agree, we can just apply the Context Menu change we talked about in
> the previous step, and leave the `decide-policy` domain-restriction logic out
> entirely. What do you think?

----

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
