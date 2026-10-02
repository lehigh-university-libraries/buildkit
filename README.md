# buildkit

Docker base images maintained in
[lehigh-university-libraries/buildkit](https://github.com/lehigh-university-libraries/buildkit).
Images are published to `lehighlts/*` on Docker Hub and
`ghcr.io/lehigh-university-libraries/*` on GHCR.

## Repository transfer setup

After transferring the repository to `lehigh-university-libraries`:

- Install the Renovate GitHub App on the destination repository and make
  `GH_APP_ID` and `GH_APP_PRIV_KEY` available to its workflows.
- Configure Docker Hub OIDC connection `aad87001-a8d7-4dd6-96ba-46ae47c311d2`
  to trust this repository for the `lehighlts` organization. Publishing uses
  [Docker login-action OIDC](https://github.com/docker/login-action#docker-hub)
  with `id-token: write`, without a stored Docker Hub password.
- The Docker Hub cleanup script uses the Hub REST API and still requires
  `DOCKERHUB_USER` and `DOCKERHUB_PASSWORD` with cleanup access to `lehighlts`.
- Allow the repository to publish packages in `lehigh-university-libraries`.
  GHCR publishing and cleanup use the repository's `GITHUB_TOKEN`; cleanup
  requires admin access to the packages.

Run **Build and Push Docker Images** with `all` and `version-tags` enabled on
`main` to populate both new namespaces before updating downstream consumers.
Make the new GHCR packages public if they must support anonymous pulls.
Existing image versions remain in the old registries; rebuilding does not copy
historical tags or preserve their digests. See
[GitHub's package transfer documentation](https://docs.github.com/en/packages/learn-github-packages/about-permissions-for-github-packages#about-repository-transfers).

## Images imported from docker-builds

Imported from [docker-builds at 188d1b6](https://github.com/lehigh-university-libraries/docker-builds/tree/188d1b6ba59caf8c969c24c17181791bbe835efe):

- `actions-runner` and `python3.13` (Bake target `python3-13`).
- `scyllaridae-cleanpdf`, `scyllaridae-coverpage`, `scyllaridae-hls`,
  `scyllaridae-libreoffice`, `scyllaridae-ocrpdf`, `scyllaridae-openai-htr`,
  `scyllaridae-pandoc`, `scyllaridae-tn-warc`, `scyllaridae-tn-zip`, and
  `scyllaridae-whisper`.

These images use the same Bake targets, dependency planning, version tags,
registry publishing, and `rootfs` layout as the existing images. The source
repository's `base` and `go` images are excluded. Its Drupal packages and
Crosswalk are incorporated into both existing Islandora PHP variants.

Python now uses this repository's Alpine base; downstream applications that
install Debian packages must update their package installation commands.
Python 3.14 is also available as `python3.14` (Bake target `python3-14`).
Renovate keeps each Python image on its named minor version.
Whisper remains AMD64-only with its existing CUDA image digest to preserve
Tesla M60 support. Other images build for AMD64 and ARM64.

Renovate refreshes both architecture checksums for Actions Runner and Crosswalk,
Composer checksums in PHP and Actions Runner, and the checksum for the pinned
Islandora Workbench source commit.

## Existing GHCR package access

Run the [package access migration helper](ci/package-access-migration.sh)
with `gh` authenticated as a package administrator:

```sh
./ci/package-access-migration.sh > package-settings.tsv
# Optional: open each linked package's settings page.
./ci/package-access-migration.sh --open
```

GitHub's public [Packages API](https://docs.github.com/en/rest/packages/packages)
does not expose **Manage Actions access**. The helper inventories packages
linked to `docker-builds` and prints their settings links; it cannot change those
permissions. For each package, grant `buildkit` Admin access (needed by cleanup),
connect it to `buildkit`, verify publishing, then remove `docker-builds` Actions
access. See [GitHub's package access documentation](https://docs.github.com/en/packages/learn-github-packages/configuring-a-packages-access-control-and-visibility).
Packages linked elsewhere but granting `docker-builds` Actions access require
manual review. The inventory includes `base` and `go` packages as requested,
even though their source images are excluded from the import.

## Testing

Build an image into the local Docker engine, then run its retained compose tests:

```sh
make bake TARGET=base
make test TARGET=base
```

You can also run a single test:

```sh
make test TARGET=base TEST=ServiceStartsWithDefaults
```

The test runner prints compose status, exit codes, and service logs directly in
the run output when a test fails. The same Go implementation backs
`ci/image-metadata.sh`, so CI and local commands use one source for image tags,
contexts, and affected-image planning.

## Attribution

Forked from https://github.com/Islandora-Devops/isle-buildkit.

Changes in this fork:

- Dropped ActiveMQ 5/6, Alpaca, Blazegraph, Fedora 6/7, FITS, ImageMagick, Crayfish, Transkribus, Handle, Riprap, and Postgres images
- Added ArchivesSpace, OJS, Omeka, and Wordpress images.
  - Moved Islandora buildkit's `drupal` image to `islandora` and made a drupal-only image
  - ArchivesSpace, OJS, Omeka S, and Omeka Classic include checksum-verified upstream application releases.
  - Drupal and Wordpress remain infrastructure scaffolding for Composer-managed application code in downstream builds.
- Tags are based on software versions
- Multiple versions of the same software/image can coexist (e.g. java, solr, php, etc.)
- `base`  environment variables (e.g. `DB_NAME`) are overriden instead of `IMAGE_NAME_*` env vars
- Removed Islandora multisite support
- Added optional Vault-backed secret bootstrap

## OJS dataset initialization

Fresh OJS installations defer the install-time ROR registry and IP geolocation
downloads so that container initialization is bounded and does not require
outbound network access. OJS's built-in scheduler remains enabled and updates
the ROR registry monthly on the first day of the month and the IP database
monthly on the tenth.

To populate either dataset immediately after installation, run the corresponding
OJS scheduler task from `/var/www/ojs` as the application user:

```sh
php lib/pkp/tools/scheduler.php test --name='PKP\task\UpdateRorRegistryDataset'
php lib/pkp/tools/scheduler.php test --name='PKP\task\UpdateIPGeoDB'
```
