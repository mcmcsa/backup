#!/bin/bash
set -e

echo "Cloning Flutter SDK (shallow clone for speed/memory)..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1

export PATH="$PATH:`pwd`/flutter/bin"

echo "Flutter version:"
flutter --version

echo "Building Flutter Web..."
flutter build web --release

echo "Build completed successfully!"
