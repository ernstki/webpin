.PHONY: build
build: build/com.github.artemanufrij.webpin

SOURCES = $(shell find src -name "*.vala")
build/com.github.artemanufrij.webpin: build/build.ninja $(SOURCES)
	cd build && ninja

build/build.ninja:
	meson build $(if $(WIPE),--wipe)

install: build/com.github.artemanufrij.webpin
	meson install -C build

clean:
	# remove rejected patches
	find . \( -name "*.orig" -o -name "*.rej" \) -delete

update-desktop-db:
	# because the version of Meson I have doesn't support update_mime_database
	# and update_desktop_database keyword arguments
	sudo update-mime-database /usr/local/share/mime
	sudo update-desktop-database /usr/local/share/applications
