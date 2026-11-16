#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
app_name="Camera RAW Studio.app"

"$project_root/scripts/build-app.sh"
ditto "$project_root/dist/$app_name" "/Applications/$app_name"
open "/Applications/$app_name"

print -r -- "/Applications/$app_name"
