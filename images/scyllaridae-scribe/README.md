# Scyllaridae Scribe

Upload an image to Scribe, wait for its transcription job, and return the
canonical hOCR export.

## Configuration

Set `SCRIBE_API_URL` to the Scribe Connect API base URL,
`SCRIBE_API_TOKEN` to a workspace-scoped API key, and
`SCRIBE_WORKSPACE_ID` to that key's workspace ID. The API key needs
`items:create`, `items:write`, `transcription:read`, and `annotations:read`
scopes.

For Kubernetes, create the API-key secret before applying the deployment:

```sh
kubectl create secret generic scribe \
  --from-literal=api-token="$SCRIBE_API_TOKEN" \
  --from-literal=api-url="$SCRIBE_API_URL" \
  --from-literal=workspace-id="$SCRIBE_WORKSPACE_ID"
```

Kubernetes supplies `api-url` to the service as `SCRIBE_API_URL` from the
Secret; local Compose reads the same setting from `.env`.

For local Isle Preserve development, set the three values in its `.env`, then
build the image with `make bake TARGET=scyllaridae-scribe` from the BuildKit
checkout. The dev Compose override runs the local `:local` image and routes
Alpaca's Scribe queue to it.

The command accepts image bytes on standard input and the source extension as
its first argument. Images must be no larger than 100 MiB.

## Islandora Scribe correlation

The command now requires the source extension, a stable 32-character
hexadecimal operation ID, and the canonical source media UUID. The operation
ID is reused as the upload batch ID. It sets `externalReferenceId` and sends a
signed callback with the workspace/item/image tuple before returning hOCR.
Set `ISLANDORA_SCRIBE_CORRELATION_URL` to the public HTTPS Drupal
`/islandora-scribe/correlation` endpoint and
`ISLANDORA_SCRIBE_CORRELATION_SECRET` to its separate 32–1024 byte secret.
The module's Scribe action supplies these arguments; existing generic hOCR
actions must be migrated to `generate_scribe_hocr_derivative`.

For external JWT authentication, mount a refreshed machine JWT and set
`SCRIBE_API_JWT_FILE` to its path; this selects Bearer auth instead of the
legacy API-key option. Refresh it before expiry, including during long jobs.

Run `bash images/scyllaridae-scribe/tests/contract.sh` to check stable ingest,
correlation fields/signature, and failed-callback behavior without a live API.
See the `islandora_scribe` module README for Drupal and ISLE setup.

Run `go run ./cmd/buildkit test --image scyllaridae-scribe` to test the built
image. `CommandContract` checks the packaged command, and `IntegrationTests`
requests hOCR over HTTP from the running service using a local HTTPS mock
for Scribe and Drupal. The integration test checks argument forwarding,
image upload, signed correlation, repeated requests, and callback rejection.

## Processing context

The optional fourth command argument is a numeric Scribe context ID. Positive
IDs are passed as `StartUploadBatch.contextId`; `0` or omission uses automatic
selection. The Drupal action exposes this as **Scribe processing context ID**
and persists it with the ingest operation. Keep it unchanged on retries, and
use the shared node hOCR derivative for all context actions. A new completed
run supersedes the previous association; context cannot change during a pending run.
The signed callback also includes the context ID for Drupal to verify.
