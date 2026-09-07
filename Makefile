.PHONY: build app run stop clean

build:
	swift build

app:
	Scripts/make-app.sh release

run: app
	pkill -x Pace || true
	open build/Pace.app

stop:
	pkill -x Pace || true

clean:
	rm -rf .build build
