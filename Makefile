.PHONY: build
build:
	if [ -d build ]; then meson build --wipe; else meson build; fi

install:
	meson install -C build

clean:
	# remove rejected patches
	find . \( -name "*.orig" -o -name "*.rej" \) -delete

update-desktop-db:
	# because the version of Meson I have doesn't support update_mime_database
	# and update_desktop_database keyword arguments
	sudo update-mime-database /usr/local/share/mime
	sudo update-desktop-database /usr/local/share/applications
