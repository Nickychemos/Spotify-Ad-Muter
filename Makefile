VERSION ?= 1.0.0

.PHONY: help deb clean

help:
	@echo "Targets:"
	@echo "  make deb VERSION=X.Y.Z   Build spotify-ad-muter_X.Y.Z_all.deb in ./build/"
	@echo "  make clean               Remove ./build/"

deb:
	VERSION=$(VERSION) packaging/debian/build-deb.sh

clean:
	rm -rf build/
