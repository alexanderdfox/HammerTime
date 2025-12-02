# Makefile Usage Guide

This Makefile provides a comprehensive build system for the HammerTime project.

## Quick Start

```bash
# Build the project
make

# Build and run
make run

# Build optimized release
make release
```

## Available Targets

### Building

- `make` or `make all` - Build the project (default)
- `make debug` - Build with debug symbols and no optimization
- `make release` - Build optimized release version
- `make run` - Build and run the application

### ML Model

- `make train-model` - Train the anomaly detection ML model
- `make install-deps` - Install Python dependencies for training

### Code Quality

- `make check` - Check code syntax without building
- `make format` - Format Swift code (requires `swift-format`)

### Cleanup

- `make clean` - Remove build artifacts
- `make distclean` - Remove all build artifacts and compiled models

### Information

- `make info` - Show build configuration information
- `make help` - Show help message

## Build Process

The Makefile:

1. **Compiles C code** (`PacketSniffer.c`) with libpcap support
2. **Compiles Swift code** (`hammer.swift`) with C interop via bridging header
3. **Links everything** together with required libraries
4. **Compiles ML model** from `.mlmodel` to `.mlmodelc` format

## Dependencies

### Required

- **Swift** 5.7+ (comes with Xcode)
- **Clang** (comes with Xcode)
- **libpcap** (usually pre-installed on macOS)

### Optional (for ML model training)

- **Python 3** with:
  - `numpy`
  - `pandas`
  - `scikit-learn`
  - `coremltools`

Install with: `make install-deps`

## Build Output

- **Binary**: `build/bin/Hammer4DDefender`
- **Compiled ML Model**: `CompiledModel/AnomalyDetector.mlmodelc`
- **Object Files**: `build/obj/` (if using separate compilation)

## Examples

### Full Build and Run

```bash
# Train model, build, and run
make train-model && make && make run
```

### Release Build

```bash
# Build optimized release
make release

# Run with sudo (required for packet capture)
sudo ./build/bin/Hammer4DDefender
```

### Development Workflow

```bash
# Check code before committing
make check

# Format code
make format

# Clean and rebuild
make clean && make
```

## Troubleshooting

### libpcap Not Found

If you get libpcap errors:

```bash
# On macOS with Homebrew
brew install libpcap

# Or specify library path manually
export LIBRARY_PATH=/usr/local/lib:$LIBRARY_PATH
make
```

### ML Model Compilation Fails

The Makefile will try multiple methods to compile the ML model:

1. `xcrun coremlcompiler` (preferred)
2. Python `coremltools` fallback

If both fail, you can manually compile:

```bash
xcrun coremlcompiler compile ml_model/AnomalyDetector.mlmodel CompiledModel/
```

### Swift Compilation Issues

If you get bridging header errors:

```bash
# Check that Bridging-Header.h exists and includes PacketSniffer.h
cat Bridging-Header.h

# Try cleaning and rebuilding
make clean && make
```

## Customization

You can customize the build by editing variables in the Makefile:

- `PROJECT_NAME` - Change the output binary name
- `SWIFT_FLAGS` - Add Swift compiler flags
- `C_FLAGS` - Add C compiler flags
- `LIBS` - Modify linked libraries

## Notes

- The Makefile automatically detects macOS SDK path
- libpcap is typically available system-wide on macOS
- Swift handles C interop compilation automatically
- ML model compilation requires Xcode command-line tools

