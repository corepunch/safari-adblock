.PHONY: rules check test try zip xcode icon

rules:              ## refresh Extension/rules.json and cosmetic.css from the lists
	python3 scripts/build_rules.py

check:              ## run the rules through Safari's translator and compiler
	swift scripts/check_rules.swift

test:               ## unit-test the YouTube ad stripping script
	node --test tests/*.test.js

try:                ## load the extension into WebKit and probe a live page (needs network)
	mkdir -p Build && swiftc -O scripts/try_in_webkit.swift -o Build/try
	Build/try $(ARGS)

zip:                ## Build/Cardea.zip — the file to upload to App Store Connect
	mkdir -p Build && rm -f Build/Cardea.zip
	cd Extension && zip -qr -X ../Build/Cardea.zip . -x '.*'
	@du -h Build/Cardea.zip

xcode:              ## throwaway Xcode project to run the extension in Safari locally
	xcrun safari-web-extension-converter Extension --project-location Build/xcode \
		--app-name Cardea --bundle-identifier com.corepunch.cardea --no-prompt --force

icon:
	python3 scripts/make_icon.py
