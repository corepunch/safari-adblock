.PHONY: rules check test zip xcode icon

rules:              ## refresh Extension/rules.json and cosmetic.css from the lists
	python3 scripts/build_rules.py

check:              ## run the rules through Safari's translator and compiler
	swift scripts/check_rules.swift

test:               ## unit-test the YouTube ad stripping script
	node --test tests/*.test.js

zip:                ## .build/Cardea.zip — the file to upload to App Store Connect
	mkdir -p .build && rm -f .build/Cardea.zip
	cd Extension && zip -qr -X ../.build/Cardea.zip . -x '.*'
	@du -h .build/Cardea.zip

xcode:              ## throwaway Xcode project to run the extension in Safari locally
	xcrun safari-web-extension-converter Extension --project-location .build/xcode \
		--app-name Cardea --bundle-identifier com.corepunch.cardea --no-prompt --force

icon:
	python3 scripts/make_icon.py
