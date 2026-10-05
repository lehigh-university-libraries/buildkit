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
kubectl create secret generic scribe --from-literal=api-token="$SCRIBE_API_TOKEN"
```

For local Isle Preserve development, set the three values in its `.env`, then
build the image with `make bake TARGET=scyllaridae-scribe` from the BuildKit
checkout. The dev Compose override runs the local `:local` image and routes
Alpaca's Scribe queue to it.

The command accepts image bytes on standard input and the source extension as
its first argument. Images must be no larger than 100 MiB.
