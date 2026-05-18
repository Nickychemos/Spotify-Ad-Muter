VERSION ?= 1.0.0

.PHONY: help deb rpm appimage all clean

help:
	@echo "Targets:"
	@echo "  make deb VERSION=X.Y.Z       Build spotify-ad-muter_X.Y.Z_all.deb in ./build/"
	@echo "  make rpm VERSION=X.Y.Z       Build spotify-ad-muter-X.Y.Z-1.<dist>.noarch.rpm in ./build/"
	@echo "  make appimage VERSION=X.Y.Z  Build spotify-ad-muter-X.Y.Z-x86_64.AppImage in ./build/"
	@echo "  make all VERSION=X.Y.Z       Build all of the above"
	@echo "  make clean                   Remove ./build/"

deb:
	VERSION=$(VERSION) packaging/debian/build-deb.sh

rpm:
	VERSION=$(VERSION) packaging/rpm/build-rpm.sh

appimage:
	VERSION=$(VERSION) packaging/appimage/build-appimage.sh

all: deb rpm appimage

clean:
	rm -rf build/
