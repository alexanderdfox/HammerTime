# Makefile for HammerTime - Hammer4D Defender
# A Swift-based DDoS defense system with C packet capture support

# Project configuration
PROJECT_NAME = Hammer4DDefender
SRC_DIR = src
INCLUDE_DIR = include
DOCS_DIR = docs
ML_MODEL_DIR = ml_model
BUILD_DIR = build
COMPILED_MODEL_DIR = CompiledModel

SWIFT_SOURCES = $(SRC_DIR)/hammer.swift
C_SOURCES = $(SRC_DIR)/PacketSniffer.c
C_HEADERS = $(INCLUDE_DIR)/PacketSniffer.h
BRIDGING_HEADER = $(INCLUDE_DIR)/Bridging-Header.h
ML_MODEL = $(ML_MODEL_DIR)/AnomalyDetector.mlmodel
ML_MODEL_COMPILED = $(COMPILED_MODEL_DIR)/AnomalyDetector.mlmodelc

# Build directories
OBJ_DIR = $(BUILD_DIR)/obj
BIN_DIR = $(BUILD_DIR)/bin

# Compiler and tools
SWIFT = swift
SWIFTC = swiftc
CC = clang
AR = ar

# Compiler flags
SWIFT_FLAGS = -c -parse-as-library
SWIFT_LINK_FLAGS = -L/usr/lib -L/usr/local/lib
C_FLAGS = -c -Wall -Wextra -Wpedantic -O2 -fPIC
C_INCLUDES = -I$(INCLUDE_DIR) -I$(SRC_DIR)

# Libraries
LIBS = -lpcap -lpthread

# Detect macOS SDK
SDK_PATH := $(shell xcrun --show-sdk-path 2>/dev/null || echo "")
ifneq ($(SDK_PATH),)
	SWIFT_FLAGS += -sdk $(SDK_PATH)
	C_FLAGS += -isysroot $(SDK_PATH)
endif

# Detect libpcap location (macOS typically has it in system)
PCAP_LIB := $(shell find /usr/local/lib /opt/homebrew/lib -name "libpcap.*" 2>/dev/null | head -1)
ifneq ($(PCAP_LIB),)
	PCAP_LIB_DIR := $(dir $(PCAP_LIB))
	SWIFT_LINK_FLAGS += -L$(PCAP_LIB_DIR)
	C_FLAGS += -L$(PCAP_LIB_DIR)
endif

# Final binary
TARGET = $(BIN_DIR)/$(PROJECT_NAME)

# Default target
.PHONY: all
all: $(TARGET) $(ML_MODEL_COMPILED)
	@echo "✅ Build complete: $(TARGET)"
	@echo "📦 Compiled ML model: $(ML_MODEL_COMPILED)"

# Create build directories
$(OBJ_DIR) $(BIN_DIR) $(COMPILED_MODEL_DIR):
	@mkdir -p $@

# C compilation is handled by Swift compiler

# Build Swift with C interop (Swift handles C compilation automatically)
$(TARGET): $(SWIFT_SOURCES) $(C_SOURCES) $(C_HEADERS) $(BRIDGING_HEADER) | $(BIN_DIR)
	@echo "🔨 Compiling Swift with C interop..."
	@$(SWIFTC) $(SWIFT_LINK_FLAGS) \
		-import-objc-header $(BRIDGING_HEADER) \
		-Xcc -I$(INCLUDE_DIR) -Xcc -I$(SRC_DIR) \
		-Xlinker $(LIBS) \
		-o $@ $(SWIFT_SOURCES) $(C_SOURCES)

# Compile ML model (CoreML models need to be compiled to .mlmodelc)
$(ML_MODEL_COMPILED): $(ML_MODEL) | $(COMPILED_MODEL_DIR)
	@echo "🧠 Compiling ML model: $(ML_MODEL)"
	@if [ -f "$(ML_MODEL)" ]; then \
		xcrun coremlcompiler compile "$(ML_MODEL)" $(COMPILED_MODEL_DIR)/ || \
		(echo "⚠️  Warning: Could not compile ML model. Using Python fallback..." && \
		 python3 -c "import coremltools as ct; model = ct.models.MLModel('$(ML_MODEL)'); print('Model loaded')" 2>/dev/null || \
		 echo "❌ Error: Could not compile ML model. Install coremltools: pip3 install coremltools"); \
	else \
		echo "⚠️  Warning: ML model not found at $(ML_MODEL)"; \
		echo "   Run 'make train-model' to generate it"; \
	fi

# Train ML model
.PHONY: train-model
train-model:
	@echo "🧠 Training anomaly detection model..."
	@cd $(ML_MODEL_DIR) && python3 train_anomaly_model.py
	@if [ -f "$(ML_MODEL)" ]; then \
		echo "✅ Model trained: $(ML_MODEL)"; \
		echo "   Run 'make' to compile it"; \
	else \
		echo "❌ Model training failed"; \
		exit 1; \
	fi

# Install dependencies for Python training
.PHONY: install-deps
install-deps:
	@echo "📦 Installing Python dependencies..."
	@pip3 install numpy pandas scikit-learn coremltools || \
	 python3 -m pip install numpy pandas scikit-learn coremltools

# Run the application
.PHONY: run
run: $(TARGET) $(ML_MODEL_COMPILED)
	@echo "🚀 Running $(PROJECT_NAME)..."
	@cd $(BIN_DIR) && ./$(PROJECT_NAME)

# Debug build
.PHONY: debug
debug: SWIFT_FLAGS += -g -Onone
debug: C_FLAGS += -g -O0
debug: $(TARGET) $(ML_MODEL_COMPILED)

# Release build (optimized)
.PHONY: release
release: SWIFT_FLAGS += -O -whole-module-optimization
release: C_FLAGS += -O3 -DNDEBUG
release: $(TARGET) $(ML_MODEL_COMPILED)
	@echo "✅ Release build complete"

# Clean build artifacts
.PHONY: clean
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "✅ Clean complete"

# Clean everything including compiled model
.PHONY: distclean
distclean: clean
	@echo "🧹 Cleaning compiled ML model..."
	@rm -rf $(COMPILED_MODEL_DIR)
	@echo "✅ Deep clean complete"

# Check code quality
.PHONY: check
check:
	@echo "🔍 Checking code quality..."
	@echo "  Checking C code..."
	@$(CC) $(C_FLAGS) -fsyntax-only $(C_SOURCES) $(C_INCLUDES)
	@echo "  ✅ C code check complete"
	@echo "  Checking Swift code..."
	@$(SWIFTC) -typecheck $(SWIFT_SOURCES) \
		-import-objc-header $(BRIDGING_HEADER) \
		-Xcc -I$(INCLUDE_DIR) -Xcc -I$(SRC_DIR) 2>&1 | grep -v "warning:" || true
	@echo "  ✅ Swift code check complete"

# Format code (requires swift-format)
.PHONY: format
format:
	@if command -v swift-format >/dev/null 2>&1; then \
		echo "📝 Formatting Swift code..."; \
		swift-format format -i $(SWIFT_SOURCES); \
		echo "✅ Formatting complete"; \
	else \
		echo "⚠️  swift-format not found. Install with: brew install swift-format"; \
	fi

# Show project structure
.PHONY: tree
tree:
	@echo "📁 Project Structure:"
	@echo ""
	@echo "HammerTime/"
	@echo "├── src/              # Source code (Swift, C)"
	@echo "├── include/          # Header files"
	@echo "├── docs/             # Documentation"
	@echo "├── ml_model/         # ML model training"
	@echo "├── build/            # Build output (generated)"
	@echo "├── CompiledModel/    # Compiled ML models (generated)"
	@echo "├── Makefile          # Build configuration"
	@echo "├── README.md         # Main documentation"
	@echo "└── LICENSE           # License file"
	@echo ""

# Show build information
.PHONY: info
info:
	@echo "📋 Build Information:"
	@echo "  Project: $(PROJECT_NAME)"
	@echo "  Swift: $(shell $(SWIFT) --version | head -1)"
	@echo "  C Compiler: $(shell $(CC) --version | head -1)"
	@echo "  SDK Path: $(SDK_PATH)"
	@echo "  Build Dir: $(BUILD_DIR)"
	@echo "  Target: $(TARGET)"
	@echo "  ML Model: $(ML_MODEL)"
	@echo "  Compiled Model: $(ML_MODEL_COMPILED)"
	@if [ -n "$(PCAP_LIB)" ]; then \
		echo "  libpcap: $(PCAP_LIB)"; \
	else \
		echo "  libpcap: system default"; \
	fi

# Help target
.PHONY: help
help:
	@echo "🛡️  HammerTime - Hammer4D Defender Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make              - Build the project (default)"
	@echo "  make run          - Build and run the application"
	@echo "  make debug        - Build with debug symbols"
	@echo "  make release      - Build optimized release version"
	@echo "  make train-model  - Train the ML anomaly detection model"
	@echo "  make install-deps - Install Python dependencies for training"
	@echo "  make check        - Check code syntax without building"
	@echo "  make format       - Format Swift code (requires swift-format)"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make distclean    - Remove all build artifacts and compiled models"
	@echo "  make info         - Show build configuration information"
	@echo "  make help         - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make train-model && make && make run"
	@echo "  make release && sudo ./build/bin/Hammer4DDefender"

# Phony targets
.PHONY: all run debug release clean distclean check format info help train-model install-deps

