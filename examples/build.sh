#!/usr/bin/env sh

# Set script to exit immediately on error
set -e

# Define directories
BAL_EXAMPLES_DIR="$(cd "$(dirname "$0")" && pwd)"
BAL_CENTRAL_DIR="$HOME/.ballerina/repositories/central.ballerina.io"
BAL_HOME_DIR="$BAL_EXAMPLES_DIR/../ballerina"

# Resolve Ballerina language version from gradle.properties
GRADLE_PROPERTIES="$BAL_EXAMPLES_DIR/../gradle.properties"
BALLERINA_LANG_VERSION=""
if [ -f "$GRADLE_PROPERTIES" ]; then
  BALLERINA_LANG_VERSION=$(awk -F '=' '/^ballerinaLangVersion/ {print $2}' "$GRADLE_PROPERTIES" | tr -d '[:space:]')
fi

# Validate input command
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <build|run>"
  exit 1
fi

case "$1" in
  build)
    BAL_CMD="build"
    ;;
  run)
    BAL_CMD="run"
    ;;
  *)
    echo "Invalid command provided: '$1'. Please provide 'build' or 'run' as the command."
    exit 1
    ;;
esac

# Read Ballerina package name from Ballerina.toml
if [ ! -f "$BAL_HOME_DIR/Ballerina.toml" ]; then
  echo "Error: Ballerina.toml not found in $BAL_HOME_DIR"
  exit 1
fi
BAL_PACKAGE_NAME=$(awk -F'"' '/^name/ {print $2}' "$BAL_HOME_DIR/Ballerina.toml")

# Push the package to the local repository
echo "Packing and pushing the Ballerina package..."
echo "$BAL_HOME_DIR"
cd "$BAL_HOME_DIR"
# Prefer local Ballerina distribution bundled in the repo; fallback to PATH
if [ -n "$BALLERINA_LANG_VERSION" ]; then
  BAL_LOCAL_BIN="$BAL_HOME_DIR/build/jballerina-tools-$BALLERINA_LANG_VERSION/bin/bal"
else
  BAL_LOCAL_BIN=""
fi
if [ -x "$BAL_LOCAL_BIN" ]; then
  BAL_BIN="$BAL_LOCAL_BIN"
else
  BAL_BIN="$(command -v bal 2>/dev/null || true)"
fi
if [ -z "$BAL_BIN" ]; then
  echo "Error: 'bal' CLI not found. Install Ballerina or ensure PATH, or include the local jballerina tools."
  exit 127
fi
"$BAL_BIN" pack
"$BAL_BIN" push --repository=local

# Remove cache directories in the central repository
echo "Cleaning cache directories in the central repository..."
cacheDirs=$(find "$BAL_CENTRAL_DIR" -type d -name "cache-*" 2>/dev/null) || true
for dir in $cacheDirs; do
  if [ -d "$dir" ]; then
    rm -rf "$dir"
    echo "Removed cache directory: $dir"
  fi
done
echo "Successfully cleaned the cache directories."

# Create the package directory in the central repository
echo "Updating the central repository..."
BAL_DESTINATION_DIR="$BAL_CENTRAL_DIR/bala/ballerina/$BAL_PACKAGE_NAME"
BAL_SOURCE_DIR="$HOME/.ballerina/repositories/local/bala/ballerina/$BAL_PACKAGE_NAME"
if [ -d "$BAL_DESTINATION_DIR" ]; then
  rm -rf "$BAL_DESTINATION_DIR"
fi
if [ -d "$BAL_SOURCE_DIR" ]; then
  mkdir -p "$(dirname "$BAL_DESTINATION_DIR")"
  cp -r "$BAL_SOURCE_DIR" "$BAL_DESTINATION_DIR"
  echo "Successfully updated the local central repository."
else
  echo "Warning: Source directory $BAL_SOURCE_DIR does not exist."
fi

echo "Source Directory: $BAL_SOURCE_DIR"
echo "Destination Directory: $BAL_DESTINATION_DIR"

# Loop through examples in the examples directory and execute the command
echo "Processing examples in the examples directory..."
cd "$BAL_EXAMPLES_DIR"
for dir in $(find "$BAL_EXAMPLES_DIR" -type d -maxdepth 1 -mindepth 1); do
  # Skip the build directory
  if [ "$(basename "$dir")" = "build" ]; then
    continue
  fi
  echo "Processing example: $dir"
  (cd "$dir" && "$BAL_BIN" "$BAL_CMD")
done

# Remove generated JAR files in the Ballerina home directory
echo "Cleaning up generated JAR files..."
find "$BAL_HOME_DIR" -maxdepth 1 -type f -name "*.jar" -exec rm {} \;
echo "Successfully removed generated JAR files."

echo "Script execution completed successfully."
