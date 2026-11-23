#!/usr/bin/env bash
set -euo pipefail

# Empty matrices may be skipped; every selected matrix must succeed.
jq -e '
  . as $jobs |
  .lint.result == "success" and
  .plan.result == "success" and
  .["test-level-4"].result == "success" and
  all(range(0; 5); . as $level |
    all(["build", "test"][]; . as $kind |
      ((if $kind == "build" then "level" else "test_level" end) + ($level | tostring)) as $output |
      ($kind + "-level-" + ($level | tostring) +
        (if $kind == "test" and $level == 4 then "-matrix" else "" end)) as $job |
      ($jobs.plan.outputs[$output] | fromjson) as $images |
      ($images | type == "array" and all(.[]; type == "string")) and
      $jobs[$job].result == (if ($images | length) == 0 then "skipped" else "success" end)))
' <<< "${RESULTS:?Missing job results}"
