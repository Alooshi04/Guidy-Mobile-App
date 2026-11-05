#!/bin/bash
# Double-click in Finder. Starts the backend (the guidy-backend folder next to this one) on port 8000.
cd "$(dirname "$0")" || exit 1
exec bash tool/mac/start_backend.sh
