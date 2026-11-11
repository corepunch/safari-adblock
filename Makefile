.PHONY: project rules icon open test

project:            ## generate Cardea.xcodeproj
	xcodegen

rules:              ## refresh Blocker/blockerList.json from upstream lists
	python3 scripts/build_rules.py

icon:
	python3 scripts/make_icon.py

open:
	open Cardea.xcodeproj

test:               ## unit-test the YouTube ad stripping script
	node --test tests/*.test.js
