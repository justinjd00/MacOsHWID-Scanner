# Makefile for HWID Scanner (Swift)

.PHONY: all swift gui clean run run-gui help

all: swift gui

swift:
	@echo "Compiling CLI version..."
	swiftc -o hwid_scanner_swift \
		HWIDScanner.swift \
		HWIDScannerCLI.swift \
		-framework IOKit \
		-framework SystemConfiguration \
		-framework CryptoKit
	@echo "CLI version compiled: ./hwid_scanner_swift"

gui:
	@echo "Compiling GUI version..."
	swiftc -o hwid_scanner_gui \
		HWIDScannerGUI.swift \
		HWIDScanner.swift \
		-framework IOKit \
		-framework SystemConfiguration \
		-framework CryptoKit \
		-framework AppKit \
		-framework SwiftUI
	@echo "GUI version compiled: ./hwid_scanner_gui"

run: swift
	@echo "Running CLI version..."
	./hwid_scanner_swift

run-gui: gui
	@echo "Running GUI version..."
	./hwid_scanner_gui

clean:
	@echo "Cleaning..."
	rm -f hwid_scanner_swift
	rm -f hwid_scanner_gui
	rm -f hwid_report.json
	@echo "Cleaned"

help:
	@echo "Available targets:"
	@echo "  make swift    - Compile CLI version"
	@echo "  make gui      - Compile GUI version"
	@echo "  make run      - Compile and run CLI version"
	@echo "  make run-gui  - Compile and run GUI version"
	@echo "  make clean    - Remove compiled files"
	@echo "  make all      - Compile both versions"
