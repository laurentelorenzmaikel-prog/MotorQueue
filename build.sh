#!/bin/bash
set -e

# Clone Flutter
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# Add Flutter to PATH
export PATH="$PATH:`pwd`/flutter/bin"

# Setup Flutter
flutter doctor -v
flutter pub get

# Build for web
flutter build web --release --web-renderer canvaskit    