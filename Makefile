# Define variables.
prefix ?= /usr/local
bindir = $(prefix)/bin

# Command building targets.
build:
	swift build -c release --disable-sandbox

install: build
	install -d "$(bindir)"
	install ".build/release/SwiftFindRefs" "$(bindir)"

uninstall:
	rm -rf "$(bindir)/SwiftFindRefs"

clean:
	rm -rf .build

.PHONY: build install uninstall clean