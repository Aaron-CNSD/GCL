#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p desktop/build/tests
javac --release 17 -encoding UTF-8 -cp desktop/lib/gson-2.13.1.jar -d desktop/build/tests desktop/src/dev/aarongame/gcl/Core.java desktop/tests/dev/aarongame/gcl/CoreTests.java
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) separator=";";; *) separator=":";; esac
java -Djava.awt.headless=true -cp "desktop/build/tests${separator}desktop/lib/gson-2.13.1.jar" dev.aarongame.gcl.CoreTests "$@"
