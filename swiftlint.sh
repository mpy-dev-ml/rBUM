#!/bin/bash
cd "${SRCROOT}"
if [[ "$(uname -m)" == arm64 ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

if [ -x "/opt/homebrew/bin/swiftlint" ]; then
    /opt/homebrew/bin/swiftlint --config "${SRCROOT}/.swiftlint.yml" --no-cache
else
    echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
