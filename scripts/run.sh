#!/usr/bin/env bash
set -Eeuo pipefail

project_dir="/n/holylabs/cgolden_lab/Lab/frontier/works/prospectors/prospectorQualtrics"
log_file="$project_dir/pipelines/logs/run.log"
lock_file="$project_dir/pipelines/logs/run.lock"

log() {
  local message=$1
  local timestamp

  timestamp=$(date --iso-8601=seconds)
  printf '%s %s\n' "$timestamp" "$message" >>"$log_file"
  printf '%s %s\n' "$timestamp" "$message"
}

run_stage() {
  local stage=$1
  shift

  log "stage=$stage event=start"
  if "$@"; then
    log "stage=$stage event=complete status=0"
  else
    local stage_status=$?
    log "stage=$stage event=failed status=$stage_status"
    return "$stage_status"
  fi
}

on_exit() {
  local run_status=$?
  log "event=run-end status=$run_status"
}

trap on_exit EXIT

# An NFS cleanup failure is more likely when two renders share the same
# Quarto cache.  Serialise both scheduled and manual full-pipeline runs.
exec 9>>"$lock_file"
if ! flock -n 9; then
  log "event=run-skipped reason=already-running"
  exit 0
fi

log "event=run-start pid=$$"

run_stage quarto "$project_dir/scripts/render-quarto.sh"
run_stage datalad "$project_dir/scripts/datalad-push.sh"

cd "$project_dir"

# Keep the application repository separate from the DataLad-managed ingress
# dataset.  Commit only after both stages have completed successfully, so one
# GitHub commit represents a complete daily run.
commit_application_changes() {
  if ! git diff --quiet -- . ':(exclude)data/**' || \
     ! git diff --cached --quiet -- . ':(exclude)data/**'; then
    # Use exclusion-only pathspecs so Git does not try to add the ignored
    # DataLad dataset while staging application changes.
    git add -A -- ':(exclude)data' ':(exclude)data/**'
    git commit -m "daily ingress run"
    git push origin main
  fi
}

run_stage git-publish commit_application_changes
