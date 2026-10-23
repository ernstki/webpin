/*-
 * Copyright (c) 2015 Erasmo Marín <erasmo.marin@gmail.com>
 * Copyright (c) 2017-2018 Artem Anufrij <artem.anufrij@live.de>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * The Noise authors hereby grant permission for non-GPL compatible
 * GStreamer plugins to be used and distributed together with GStreamer
 * and Noise. This permission is above and beyond the permissions granted
 * by the GPL license by which Noise is covered. If you modify this code
 * you may extend this exception to your version of the code, but you are not
 * obligated to do so. If you do not wish to do so, delete this exception
 * statement from your version.
 *
 * Authored by: Artem Anufrij <artem.anufrij@live.de>
 */

namespace Webpin.Widgets {
    public class Browser : Gtk.Stack {
        public WebKit.WebView web_view { get; private set; }
        public DesktopFile desktop_file { get; private set; }

        WebKit.CookieManager cookie_manager;
        Gtk.Box container;
        Granite.Widgets.Toast app_notification;
        GLib.Icon icon_for_notification;

        public signal void external_request (WebKit.NavigationAction action);
        public signal void request_begin ();
        public signal void request_finished ();
        public signal void desktop_notification (string title, string body, GLib.Icon icon);
        public signal void found_website_color (Gdk.RGBA color);


        public Browser (DesktopFile desktop_file) {
            this.desktop_file = desktop_file;
            this.transition_duration = 350;
            this.transition_type = Gtk.StackTransitionType.SLIDE_UP;

            WebKit.WebsiteDataManager data_manager;

            if (desktop_file.save_cookies) {
                string safe_name = desktop_file.name.replace (" ", "_").down ();
                string app_data_dir = Environment.get_user_data_dir () + "/" + Webpin.APP_ID + "/" + safe_name;
                string app_cache_dir = Environment.get_user_cache_dir () + "/" + Webpin.APP_ID + "/" + safe_name;

                data_manager = (WebKit.WebsiteDataManager) GLib.Object.new (
                    typeof (WebKit.WebsiteDataManager),
                    "base-data-directory", app_data_dir,
                    "base-cache-directory", app_cache_dir
                );
            } else {
                data_manager = new WebKit.WebsiteDataManager.ephemeral ();
            }

            var context = new WebKit.WebContext.with_website_data_manager (data_manager);
            context.set_spell_checking_enabled(true);
            context.set_spell_checking_languages({"en_US", "de_DE"});

            web_view = new WebKit.WebView.with_context (context) {
                settings = new WebKit.Settings () {
                    enable_back_forward_navigation_gestures = true,
                    enable_mediasource = true,
                    enable_webgl = true,
                    // enable_tracking_prevention = false,
                    enable_developer_extras = true
                }
            };

            cookie_manager = context.get_cookie_manager ();
            cookie_manager.set_accept_policy (WebKit.CookieAcceptPolicy.ALWAYS);

            if (desktop_file.save_cookies) {
                string safe_name = desktop_file.name.replace (" ", "_").down ();
                string cookie_file = Environment.get_user_data_dir () + "/"
                                     + Webpin.APP_ID + "/" + safe_name + "/cookies.sqlite";
                cookie_manager.set_persistent_storage (cookie_file, WebKit.CookiePersistentStorage.SQLITE);
            }

            web_view.load_uri (desktop_file.url);

            container = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            if (desktop_file.color != null) {
                var css_provider = new Gtk.CssProvider();
                try {
                    css_provider.load_from_data (""" .box { background: """ + desktop_file.color.to_string () + """; } """);
                } catch (Error err) {
                    warning (err.message);
                }
                container.get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                container.get_style_context ().add_class ("box");
            }

            app_notification = new Granite.Widgets.Toast ("");

            var overlay = new Gtk.Overlay ();
            overlay.add (web_view);
            overlay.add_overlay (app_notification);

            this.add_named (container, "splash");
            this.add_named (overlay, "app");

            var icon_file = File.new_for_path (desktop_file.icon);

            Gtk.Image icon;
            if (icon_file.query_exists ()) {
                try {
                    icon = new Gtk.Image.from_pixbuf (new Gdk.Pixbuf.from_file_at_scale (desktop_file.icon, 48, 48, true));
                    icon_for_notification = GLib.Icon.new_for_string (desktop_file.icon);
                } catch (Error err) {
                    warning (err.message);
                    icon = new Gtk.Image.from_icon_name (Webpin.APP_ID, Gtk.IconSize.DIALOG);
                }
            } else {
                icon = new Gtk.Image.from_icon_name (desktop_file.icon, Gtk.IconSize.DIALOG);
                icon_for_notification = new GLib.ThemedIcon (desktop_file.icon);
            }
            container.pack_start (icon, true, true, 0);

            web_view.create.connect ((action) => {
                app_notification.title = _ ("Open request in an external application…");
                app_notification.send_notification ();

                external_request (action);

                // Returning a raw, unparented WebView here causes modern WebKitGTK to
                // crash with `Assertion 'this->_M_is_engaged()' failed`. Returning
                // null instead tells WebKit "to propagate the event further,"
                // (whatever that means) but in effect avoids the assertion error.
                // ref: https://valadoc.org/webkit2gtk-4.0/WebKit.WebView.create.html
                return null;
            });

            // replace "Open Link in New Window" with the more honest "Open Link in Default
            // Browser"; see Windows/WebApp.vala for the `browser.external_request.connect`
            // implementation which would've handled this otherwise
            web_view.context_menu.connect ((context_menu, event, hit_test_result) => {
                if (hit_test_result.context_is_link ()) {
                    int position = 0;
                    WebKit.ContextMenuItem? item_to_remove = null;
                    foreach (var item in context_menu.get_items ()) {
                        if (item.get_stock_action () == WebKit.ContextMenuAction.OPEN_LINK_IN_NEW_WINDOW) {
                            item_to_remove = item;
                            break;
                        }
                        position++;
                    }

                    if (item_to_remove != null) {
                        context_menu.remove (item_to_remove);
                        var action = new GLib.SimpleAction ("open-default-browser", null);
                        action.activate.connect (() => {
                            app_notification.title = _ ("Opening link in your default browser…");
                            app_notification.send_notification ();
                            try {
                                GLib.AppInfo.launch_default_for_uri (hit_test_result.get_link_uri (), null);
                            } catch (Error e) {
                                warning (e.message);
                            }
                        });
                        var custom_item = new WebKit.ContextMenuItem.from_gaction (action, _("Open Link in Default Browser"), null);
                        context_menu.insert (custom_item, position);
                    }
                }
                return false;
            });

            web_view.load_failed.connect ((load_event, failing_uri, error) => {
                warning ("Load failed for URI: %s. Error: %s (Code: %d)", failing_uri, error.message, error.code);
                return false;
            });

            web_view.load_failed_with_tls_errors.connect ((failing_uri, certificate, errors) => {
                warning ("TLS Load failed for URI: %s", failing_uri);
                return false;
            });

            web_view.load_changed.connect ((load_event) => {
                request_begin ();
                if (load_event == WebKit.LoadEvent.FINISHED) {
                    visible_child_name = "app";
                    if (app_notification.reveal_child) {
                        app_notification.reveal_child = false;
                    }
                    request_finished ();
                }
            });

            web_view.show_notification.connect ((notification) => {
                desktop_notification (notification.title, notification.body, icon_for_notification);
                return true;
            });

            web_view.permission_request.connect ((permission) => {
                var permission_type = permission as WebKit.NotificationPermissionRequest;
                if (permission_type != null) {
                    permission_type.allow ();
                }
                return false;
            });

            web_view.button_press_event.connect ((event) => {
                if (event.button == 8) {
                    web_view.go_back ();
                    return true;
                } else if (event.button == 9) {
                    web_view.go_forward ();
                    return true;
                }
                return base.button_press_event (event);
            });

            web_view.key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.Back) {
                    web_view.go_back ();
                    return true;
                } else if (event.keyval == Gdk.Key.Forward) {
                    web_view.go_forward ();
                    return true;
                }
                return base.key_press_event (event);
            });
        }

        public void go_home () {
            web_view.load_uri (desktop_file.url);
            request_finished ();
        }

        public void go_back () {
            web_view.go_back ();
            request_finished ();
        }

        public void go_forward () {
            web_view.go_forward ();
            request_finished ();
        }

        public bool can_go_back () {
            return web_view.can_go_back ();
        }

        public bool can_go_forward () {
            return web_view.can_go_forward ();
        }

        public void reload () {
            web_view.reload ();
        }

        public void reload_bypass_cache () {
            web_view.reload_bypass_cache ();
        }

        public void show_toast (string title) {
            app_notification.title = title;
            app_notification.send_notification ();
        }
    }
}
