SOURCES = $(shell find src -name "*.vala")
PREFIX ?= /usr/local

.PHONY: build
build: build/com.github.artemanufrij.webpin

build/com.github.artemanufrij.webpin: build/build.ninja $(SOURCES)
	cd build && ninja

build/build.ninja:
	meson build --prefix="$(PREFIX)" $(if $(WIPE),--wipe)

install: build/com.github.artemanufrij.webpin
	meson install -C build

uninstall: build/build.ninja
	cd build && sudo ninja uninstall

clean:
	# remove rejected patches
	-find . \( -name "*.orig" -o -name "*.rej" \) -delete
	-rm -rf build

update-desktop-db:
	# because the version of Meson I have doesn't support update_mime_database
	# and update_desktop_database keyword arguments
	sudo update-mime-database /usr/local/share/mime
	sudo update-desktop-database /usr/local/share/applications
