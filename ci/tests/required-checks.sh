#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)

RESULTS=$(jq -n '
  {lint: {result: "success"}, plan: {result: "success", outputs: {}},
   "test-level-4": {result: "success"}} |
  reduce range(0; 5) as $level (.;
    .plan.outputs["level" + ($level | tostring)] = "[]" |
    .plan.outputs["test_level" + ($level | tostring)] = "[]" |
    .["build-level-" + ($level | tostring)] = {result: "skipped"} |
    .["test-level-" + ($level | tostring) + (if $level == 4 then "-matrix" else "" end)] = {result: "skipped"})')
export RESULTS
check() { bash "$root/ci/check-required-jobs.sh" >/dev/null 2>&1; }
reject() { if check; then echo "Unexpected gate success: $RESULTS" >&2; exit 1; fi; }
check # No affected images.
empty=$RESULTS
for kind in build test; do
  for level in {0..4}; do
    output=level$level
    job=$kind-level-$level
    if [[ "$kind" == test ]]; then
      output=test_level$level
      if [[ "$level" == 4 ]]; then job+=-matrix; fi
    fi
    RESULTS=$(jq --arg output "$output" --arg job "$job" '
      .plan.outputs[$output] = "[\"base\"]" | .[$job].result = "success"' <<< "$empty")
    check
    selected=$RESULTS
    for result in failure cancelled skipped; do
      RESULTS=$(jq --arg job "$job" --arg result "$result" '.[$job].result = $result' <<< "$selected")
      reject
    done
    for invalid in '' null '{}' '[1]' broken; do
      RESULTS=$(jq --arg output "$output" --arg invalid "$invalid" '.plan.outputs[$output] = $invalid' <<< "$empty")
      reject
    done
  done
done
for job in lint plan test-level-4; do
  for result in failure cancelled skipped; do
    RESULTS=$(jq --arg job "$job" --arg result "$result" '.[$job].result = $result' <<< "$empty")
    reject
  done
done
echo 'Required-check gate checks passed'
