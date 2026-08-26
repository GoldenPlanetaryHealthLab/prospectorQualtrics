#!/usr/bin/env bash
set -euo pipefail

project_dir="/n/holylabs/cgolden_lab/Lab/frontier/works/prospectors/prospectorQualtrics"

"$project_dir/scripts/render-quarto.sh"

"$project_dir/scripts/datalad-push.sh"