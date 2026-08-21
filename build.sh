#!/bin/bash
set -e

echo "Cloning Flutter SDK (shallow clone)..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1

export PATH="$PATH:`pwd`/flutter/bin"

echo "Disabling analytics and setting memory limits..."
flutter config --no-analytics
export DART_VM_OPTIONS="--old_gen_heap_size=800"

echo "Flutter version:"
flutter --version

echo "Creating dummy .env file for Vercel asset bundler..."
touch .env

echo "Building Flutter Web (verbose mode)..."
flutter build web --release --base-href "/" -v

echo "Build completed successfully!"
