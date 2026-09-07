.PHONY: build app run stop clean

build:
	swift build

app:
	Scripts/make-app.sh release

run: app
	pkill -x UsageBar || true
	open build/UsageBar.app

stop:
	pkill -x UsageBar || true

clean:
	rm -rf .build build
