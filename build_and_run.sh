#!/bin/bash
cd "$(dirname "$0")/ClassBell"
swift build -c release && \
cp .build/arm64-apple-macosx/release/ClassBell 上下课铃声.app/Contents/MacOS/ClassBell && \
pkill -f ClassBell 2>/dev/null; sleep 0.5; \
open 上下课铃声.app
