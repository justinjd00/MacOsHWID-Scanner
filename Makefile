# Makefile für HWID Scanner (Swift)

.PHONY: all swift gui clean run run-gui help

all: swift gui

swift:
	@echo "🔨 Kompiliere CLI-Version..."
	swiftc -o hwid_scanner_swift \
		HWIDScanner.swift \
		HWIDScannerCLI.swift \
		-framework IOKit \
		-framework SystemConfiguration \
		-framework CryptoKit
	@echo "✅ CLI-Version kompiliert: ./hwid_scanner_swift"

gui:
	@echo "🔨 Kompiliere GUI-Version..."
	swiftc -o hwid_scanner_gui \
		HWIDScannerGUI.swift \
		HWIDScanner.swift \
		-framework IOKit \
		-framework SystemConfiguration \
		-framework CryptoKit \
		-framework AppKit \
		-framework SwiftUI
	@echo "✅ GUI-Version kompiliert: ./hwid_scanner_gui"

run: swift
	@echo "🚀 Führe CLI-Version aus..."
	./hwid_scanner_swift

run-gui: gui
	@echo "🚀 Führe GUI-Version aus..."
	./hwid_scanner_gui

clean:
	@echo "🧹 Bereinige..."
	rm -f hwid_scanner_swift
	rm -f hwid_scanner_gui
	rm -f hwid_report.json
	@echo "✅ Bereinigt"

help:
	@echo "Verfügbare Ziele:"
	@echo "  make swift    - Kompiliere CLI-Version"
	@echo "  make gui      - Kompiliere GUI-Version"
	@echo "  make run      - Kompiliere und führe CLI-Version aus"
	@echo "  make run-gui  - Kompiliere und führe GUI-Version aus"
	@echo "  make clean    - Lösche kompilierte Dateien"
	@echo "  make all      - Kompiliere beide Versionen"

