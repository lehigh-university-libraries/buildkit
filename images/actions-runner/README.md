# GitHub Actions Runner

GitHub Actions runner version 2.338.0.

Includes Docker, kubectl, GitHub CLI, PHP, Composer, and Lehigh Islandora Workbench dependencies.
Supports AMD64 and ARM64 using independently verified runner release archives.

Configure `GITHUB_REPO`, `GITHUB_RUNNER_TOKEN`, and optionally `LABELS` at runtime.
Mount the Docker socket when jobs need the host Docker daemon.

Renovate refreshes runner, Composer, and Workbench checksums through
`ci/update-sha.sh`. Workbench follows `simple-field-json` using a pinned commit.
