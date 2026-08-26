#!/usr/bin/env bash
set -euo pipefail

project_dir="/n/holylabs/cgolden_lab/Lab/frontier/works/prospectors/prospectorQualtrics"

cd "$project_dir/data/staging"

datalad save \
    -m "Qualtrics staging snapshot $(date -Iseconds)" \
    .

goldmine="/n/holylabs/LABS/cgolden_lab/Lab/frontier/gold_mine"

cd "$goldmine/01_ore/qualtrics_sync/datalad"

datalad update --merge
datalad get -r .
