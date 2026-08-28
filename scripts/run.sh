#!/usr/bin/env bash
set -euo pipefail

project_dir="/n/holylabs/cgolden_lab/Lab/frontier/works/prospectors/prospectorQualtrics"

"$project_dir/scripts/render-quarto.sh"

"$project_dir/scripts/datalad-push.sh"

cd "$project_dir"

# Keep the application repository separate from the DataLad-managed ingress
# dataset.  Commit only after both stages have completed successfully, so one
# GitHub commit represents a complete daily run.
if ! git diff --quiet -- . ':(exclude)data/**' || \
   ! git diff --cached --quiet -- . ':(exclude)data/**'; then
  git add -A -- . ':(exclude)data/**'
  git commit -m "daily ingress run"
  git push origin main
fi
