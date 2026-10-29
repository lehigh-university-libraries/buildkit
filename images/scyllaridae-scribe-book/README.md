# Scyllaridae Scribe books

New imports retain the source node ID as `metadata.external_identifier` and
the original Islandora title as `metadata.title` for Scribe library search.
The numeric item name and UUID used for callback correlation are unchanged.

Processes Islandora node events like the mergepdf service. Drupal sends the
canonical node URL plus `transcribe OPERATION_ID CONTEXT_ID` or
`pdf OPERATION_ID 0`; it does not submit Scribe jobs itself.

`cmd.sh` validates the node origin and requests signed correlation metadata
from Drupal. `transcribe.sh` imports or reuses the book and reprocesses its
pages. `pdf.sh` prepares the revision-checked PDF and uploads it through the
same authenticated document/Original File endpoint used by mergepdf.

New imports use the numeric Islandora node ID as their Scribe item title so
books and individual image uploads can be cross-referenced by node ID. Reused
items retain their existing names; this does not rewrite previously imported
items or change external-reference/correlation identifiers.

Configure `SCRIBE_API_URL`, `SCRIBE_WORKSPACE_ID`, and `SCRIBE_API_TOKEN`
(or a refreshed `SCRIBE_API_JWT_FILE`). The microservice key requires
`items:create`, `items:write`, `items:read`, `transcription:read`, and
`annotations:read`. Drupal keeps a separate `annotations:read` key.
Set `ISLANDORA_SCRIBE_CORRELATION_URL` and
`ISLANDORA_SCRIBE_CORRELATION_SECRET` to the same values used by the image
Scribe microservice. `SCYLLARIDAE_AUTH` is supplied by Scyllaridae from the
verified request JWT, and is used only for the Islandora PDF upload.

Requests must use a node under the configured Islandora HTTPS origin.
Manifest and painting image access are anonymous. Models and context IDs are
server capabilities; the action must choose a positive existing context.

Unchanged painting/membership reuses the active item. Signed callbacks persist
fixed reprocess revisions before requesting work, fence superseded operations,
and remove obsolete page mappings. Retries cannot process a newer revision
again. Completion events update hOCR through Drupal's existing publication
queue, with reconciliation for completions that raced ahead of correlation.

Permanent HTTP errors acknowledge the request and log a fixed rejection
category. Transport errors, rate limits and conflicts return failure to
Alpaca's bounded redelivery policy. No PDF is attached until the user invokes
the PDF action; failed preparation or download never changes the live PDF.

The `CommandContract` image test exercises import, item reuse, replay,
revision-checked PDF upload, callback signatures, origin and credential
isolation, and permanent/transient failure dispositions. CI builds both
architectures and runs the command contract on its hosted test runner.
No live Scribe credentials are needed for these checks.
