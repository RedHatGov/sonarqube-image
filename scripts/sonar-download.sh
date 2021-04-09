#!/bin/bash

# Default versions
SONARQUBE_VERSION=${SONARQUBE_VERSION:-8.7.0.41497}
SONAR_JAVA_PLUGIN_VERSION=${SONAR_JAVA_PLUGIN_VERSION:-6.13.0.25138}

# Dependencies to use this script
deps=(
    curl
    gpg
    sha1sum
    unzip
)
missing=()
for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        missing+=("$dep")
    fi
done
if [ ${#missing[@]} -ne 0 ]; then
    echo "Missing dependencies (${missing[@]}), unable to continue." >&2
    exit 1
fi

# Enable verbose output
if echo "$*" | grep -qF -- "-v" || echo "$*" | grep -qF -- "--verbose"; then
    set -ex
else
    set -e
fi

# A working directory for initial downloads
this_download="$(mktemp -d)"
dest="$(realpath "$(pwd)")/opt"
cd "$this_download"

# Always clean up the working directory
function cleanup {
    rm -rf "$this_download"
}
trap cleanup EXIT

# Trust the Sonarsource Deployer key
gpg --keyserver ha.pool.sks-keyservers.net --recv-keys F1182E81C792928921DBCAB4CFCA4A29D26468DE

# This is the main download url
base_url=https://binaries.sonarsource.com/Distribution

function download {
    # A function to download a component, its checksum, and its signature.
    # Validates downloads, returns 1 if a component fails validation.
    component="$1"
    version="$2"
    ext="${3:-zip}"
    filename="$component-$version.$ext"
    echo "Downloading $filename"
    download_url="$base_url/$component/$filename"
    for file in "" .asc .sha1; do
        curl -sLO "$download_url$file" || return 1
    done
    # Validate the checksum
    echo "Validating $filename checksum"
    echo $(cat $filename.sha1) $filename | sha1sum -c || return 1
    # Check the signature
    echo "Validating $filename signature"
    sigout=$(gpg --verify $filename.asc 2>&1)
    echo "$sigout" | grep -qF 'Good signature from "sonarsource_deployer' || { echo "$sigout" >&2 ; return 1 ; }
    # Clean up old files
    rm -f $filename.sha1 $filename.asc
}

download sonarqube $SONARQUBE_VERSION
download sonar-java-plugin $SONAR_JAVA_PLUGIN_VERSION jar

mkdir -p "$dest"
mv "$this_download"/* "$dest"/

cd "$dest"

echo "Unpacking SonarQube and plugins"
unzip sonarqube-$SONARQUBE_VERSION.zip
rm sonarqube-$SONARQUBE_VERSION.zip
mv sonarqube-$SONARQUBE_VERSION sonarqube

# Sonar-java-plugin update
rm sonarqube/lib/extensions/sonar-java-plugin-*.jar ||:
mv sonar-java-plugin-*.jar sonarqube/extensions/plugins/

echo "Sonarqube is unpacked to $(pwd)"
