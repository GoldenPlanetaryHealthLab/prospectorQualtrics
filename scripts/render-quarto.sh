#!/usr/bin/env bash
set -u

project_dir="/n/holylabs/cgolden_lab/Lab/frontier/works/prospectors/prospectorQualtrics"
log_file="$project_dir/pipelines/logs/quarto-render.log"
run_log="$(mktemp)"

cd "$project_dir" || exit 1
source .spack-env/view/bin/activate

quarto render >"$run_log" 2>&1
render_status=$?

cat "$run_log" >>"$log_file"

expected_error=false

if [ "$render_status" -ne 0 ] &&
   grep -Fq "Directory not empty (os error 39)" "$run_log" &&
   grep -Fq "removeFreezeResults" "$run_log"; then
  expected_error=true
fi

rm -f "$run_log"

if [ "$render_status" -eq 0 ]; then
  :
elif [ "$expected_error" = true ]; then
  printf '%s\n' \
    "Accepted known Quarto NFS cleanup error at $(date --iso-8601=seconds)" \
    >>"$log_file"
else
  printf '%s\n' \
    "Quarto render failed unexpectedly with status $render_status" \
    >>"$log_file"

  exit "$render_status"
fi

exit 0
