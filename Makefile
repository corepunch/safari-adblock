.PHONY: project rules icon open

project:            ## generate Cardea.xcodeproj
	xcodegen

rules:              ## refresh Blocker/blockerList.json from upstream lists
	python3 scripts/build_rules.py

icon:
	python3 scripts/make_icon.py

open: project
	open Cardea.xcodeproj
