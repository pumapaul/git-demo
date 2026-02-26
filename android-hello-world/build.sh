#!/bin/bash
set -e

# Android Hello World - Manual APK Build Script
# Builds an APK without Gradle, using only Android SDK command-line tools

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANDROID_HOME="/usr/lib/android-sdk"
PLATFORM="$ANDROID_HOME/platforms/android-23"
BUILD_TOOLS="$ANDROID_HOME/build-tools/debian"
ANDROID_JAR="$PLATFORM/android.jar"

# Output directories
BUILD_DIR="$PROJECT_DIR/build"
GEN_DIR="$BUILD_DIR/gen"
OBJ_DIR="$BUILD_DIR/obj"
APK_DIR="$BUILD_DIR/apk"

echo "=== Android Hello World Build ==="
echo "Platform: android-23"
echo "Build tools: $BUILD_TOOLS"
echo ""

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$GEN_DIR" "$OBJ_DIR" "$APK_DIR"

# Step 1: Generate R.java from resources
echo "[1/6] Generating R.java..."
aapt package \
    -f \
    -m \
    -J "$GEN_DIR" \
    -M "$PROJECT_DIR/AndroidManifest.xml" \
    -S "$PROJECT_DIR/res" \
    -I "$ANDROID_JAR"
echo "      Generated $(find "$GEN_DIR" -name 'R.java')"

# Step 2: Compile Java source files
echo "[2/6] Compiling Java sources..."
javac \
    -source 8 -target 8 \
    -bootclasspath "$ANDROID_JAR" \
    -classpath "$ANDROID_JAR" \
    -d "$OBJ_DIR" \
    "$GEN_DIR/com/example/helloworld/R.java" \
    "$PROJECT_DIR/src/com/example/helloworld/MainActivity.java"
echo "      Compiled $(find "$OBJ_DIR" -name '*.class' | wc -l) class files"

# Step 3: Convert to Dalvik bytecode (DEX)
echo "[3/6] Converting to DEX format..."
"$BUILD_TOOLS/dx" \
    --dex \
    --output="$BUILD_DIR/classes.dex" \
    "$OBJ_DIR"
echo "      Created classes.dex ($(du -h "$BUILD_DIR/classes.dex" | cut -f1))"

# Step 4: Package resources into APK
echo "[4/6] Packaging resources..."
aapt package \
    -f \
    -M "$PROJECT_DIR/AndroidManifest.xml" \
    -S "$PROJECT_DIR/res" \
    -I "$ANDROID_JAR" \
    -F "$BUILD_DIR/hello-world.unsigned.apk"

# Add DEX to APK
cd "$BUILD_DIR"
aapt add "$BUILD_DIR/hello-world.unsigned.apk" classes.dex
cd "$PROJECT_DIR"

# Step 5: Sign the APK
echo "[5/6] Signing APK..."
KEYSTORE="$BUILD_DIR/debug.keystore"
keytool -genkeypair \
    -dname "CN=Android Debug,O=Android,C=US" \
    -keystore "$KEYSTORE" \
    -storepass android \
    -keypass android \
    -alias androiddebugkey \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    2>/dev/null

apksigner sign \
    --ks "$KEYSTORE" \
    --ks-pass pass:android \
    --key-pass pass:android \
    --ks-key-alias androiddebugkey \
    --out "$BUILD_DIR/hello-world.apk" \
    "$BUILD_DIR/hello-world.unsigned.apk"

# Step 6: Verify
echo "[6/6] Verifying APK..."
apksigner verify "$BUILD_DIR/hello-world.apk"

APK_SIZE=$(du -h "$BUILD_DIR/hello-world.apk" | cut -f1)
echo ""
echo "=== Build Successful! ==="
echo "APK: $BUILD_DIR/hello-world.apk ($APK_SIZE)"
echo ""

# Show APK contents
echo "APK contents:"
aapt list "$BUILD_DIR/hello-world.apk"
echo ""

# Show APK info
echo "APK info:"
aapt dump badging "$BUILD_DIR/hello-world.apk" 2>/dev/null | grep -E "^(package|application|launchable)"
