#!/bin/sh
# Created by Jerel Walters on 6/20/26.
# Copyright © 2026 Jerel Walters. All rights reserved.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT="${SRCROOT:-$SCRIPT_DIR/..}"
FAILED=0

check_source_header() {
    file="$1"

    if ! /usr/bin/head -n 8 "$file" | /usr/bin/grep -Fq \
        'Created by Jerel Walters on '; then
        echo "error: $file is missing the Jerel Walters creator header."
        FAILED=1
    fi

    if ! /usr/bin/head -n 8 "$file" | /usr/bin/grep -Eq \
        'Copyright © [0-9]{4} Jerel Walters\. All rights reserved\.'; then
        echo "error: $file is missing the Jerel Walters copyright header."
        FAILED=1
    fi
}

check_imports() {
    file="$1"
    allowed_modules="$2"

    if ! /usr/bin/awk -v allowed_modules="$allowed_modules" '
        BEGIN {
            split(allowed_modules, modules, ",")
            for (module_index in modules) {
                allowed[modules[module_index]] = 1
            }
        }
        /^import / {
            module = $2
            if (!(module in allowed)) {
                printf "error: %s:%d imports %s outside its architecture boundary\n", FILENAME, NR, module
                found_violation = 1
            }
        }
        END { exit found_violation }
    ' "$file"; then
        FAILED=1
    fi
}

if /usr/bin/grep -R -n -E '(^|[^[:alnum:]_])(AppService|AppRootManager)([^[:alnum:]_]|$)' \
    "$ROOT/HaulMate/Features" \
    "$ROOT/HaulMate/App/AppRootView.swift"; then
    echo "error: Feature UI must depend on repositories, not service protocols or implementations."
    FAILED=1
fi

for file in $(/usr/bin/find "$ROOT/HaulMate/Features" -type f -name '*.swift'); do
    check_imports "$file" "SwiftUI,Foundation,Observation"
done

check_imports "$ROOT/HaulMate/App/AppRootView.swift" "SwiftUI,Foundation,Observation"

for file in $(/usr/bin/find "$ROOT/HaulMate" -type f -name '*Repository.swift'); do
    case "$file" in
        "$ROOT"/HaulMate/Infrastructure/Persistence/*)
            check_imports "$file" "Foundation,Observation,StorageModule"
            ;;
        *)
            check_imports "$file" "Foundation,Observation"
            ;;
    esac
done

for file in $(/usr/bin/find "$ROOT/HaulMate" "$ROOT/HaulMateTests" -type f -name '*.swift'); do
    check_source_header "$file"
done

check_source_header "$ROOT/Scripts/check_architecture.sh"

exit "$FAILED"
