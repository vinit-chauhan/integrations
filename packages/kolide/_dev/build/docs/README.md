{{- generatedHeader }}
# Kolide Integration for Elastic

## Overview

The Kolide integration for Elastic collects device-trust and endpoint-compliance logs from [Kolide](https://www.kolide.com/) (by 1Password). It ingests authentication sessions, posture issues, approval-workflow requests, device inventory and trust-status changes, people identity records, and administrative audit events, normalizes them to the Elastic Common Schema (ECS), and makes them available for search, visualization, and detection in Elastic.

### Compatibility

This integration works with the current Kolide Device Trust platform ("Kolide K2") and its public REST API (version `2026-04-07`) and webhooks. It does not cover the legacy open-source Kolide Fleet (osquery) product.

### How it works

The integration supports four collection methods that you can choose between (and combine) when configuring it:

- Webhooks (HTTP endpoint): Kolide pushes events in near real time to an HTTP endpoint exposed by the Elastic Agent. This is the recommended method for low-latency device-compliance data. Each delivery is signed with an HMAC-SHA256 signature for verification.
- REST API (polling): the Elastic Agent periodically polls the Kolide REST API and collects records using cursor-based pagination and timestamp filters where supported. This is useful for backfill and for fuller resource records.
- AWS S3 (Kolide Log Pipeline): Kolide's Log Pipeline writes objects to a customer-owned S3 bucket under per-type key prefixes (defaults: `kolide/auth_logs/`, `kolide/audit_logs/`, `kolide/check_runs/`, `kolide/results/`, `kolide/status/`); the Elastic Agent reads each prefix with an `aws-s3` input (SQS notifications or direct bucket polling). The `auth` and `audit` data streams can read their respective prefixes, the dedicated `device_check` data stream reads `kolide/check_runs/`, and the dedicated `osquery_result`/`osquery_status` data streams read `kolide/results/` and `kolide/status/` — the raw osquery Result and Status logs. The Log Pipeline is the most complete source for check-run history — it includes passing, inapplicable, and unknown check results in addition to failures.
- Google Cloud Storage (Kolide Log Pipeline): the same Log Pipeline data, written to a customer-owned GCS bucket under the same per-type key prefixes and read with a `gcs` input (bucket polling). The object payloads are identical to the S3 delivery, so the same `auth`, `audit`, `device_check`, `osquery_result`, and `osquery_status` data streams apply — choose S3 or GCS based on which cloud your Kolide log destination targets.

## What data does this integration collect?

The Kolide integration collects the following data streams:

* `webhook`: single webhook ingress that receives all Kolide webhook event types on one endpoint and routes each event to the correct data stream automatically.
* `auth`: SSO authentication sessions (`auth_logs.success`, `auth_logs.failure`; API `GET /auth_logs`).
* `issues`: device posture-check failures and resolutions (`issues.new`, `issues.resolved`; API `GET /issues`).
* `request`: approval-workflow requests (`requests.issue_exemption`, `requests.registration`; API `GET /exemption_requests` and `GET /registration_requests`).
* `device`: device inventory and trust-status changes (`devices.created`, `devices.registered`, `devices.destroyed`, `device_trust.status_changed`; API `GET /devices`).
* `people`: identity records for people known to Kolide (API `GET /people`).
* `audit`: administrative audit log of console actions (`audit_log.recorded`; API `GET /audit_logs`; Log Pipeline S3/GCS `kolide/audit_logs/`).
* `device_check`: device check-run results from the Log Pipeline (S3/GCS `kolide/check_runs/`), covering every run — `passing`, `failing`, `inapplicable`, and `unknown`. This complements the failure-focused `issues` data stream.
* `osquery_result`: raw osquery Result Logs from the Log Pipeline (S3/GCS `kolide/results/`), covering both snapshot-query rows and differential (`added`/`removed`) rows. Per-query column data is stored as a flattened field rather than mapped per column, since it is arbitrary and depends on the target osquery table or custom SQL.
* `osquery_status`: raw osquery Status Logs from the Log Pipeline (S3/GCS `kolide/status/`) — GLOG-style telemetry about the osquery daemon itself (not host inventory state).

The `auth` and `audit` data streams additionally support the Log Pipeline via `aws-s3` and `gcs` inputs that read the `kolide/auth_logs/` and `kolide/audit_logs/` prefixes.

> **Note on `osquery_result` and `osquery_status`:** these two data streams ingest **raw** osquery agent logs, unlike every other Log Pipeline stream in this integration (`auth`, `audit`, `device_check`), which are Kolide's own structured logs. `host.id`/`host.name` are populated from Kolide's `kolide_decorations` block, which is only present when the device is enrolled with Kolide's own launcher — a bare open-source osquery deployment shipping logs through the Log Pipeline would only carry osquery's own `hostIdentifier` (kept at `kolide.osquery_result.host_identifier` / `kolide.osquery_status.host_identifier`), and `host.id`/`host.name` would not populate. Per-query row data (`kolide.osquery_result.columns`/`.snapshot`) is a `flattened` field rather than a per-column mapping, since the columns are arbitrary and depend on the target osquery table or custom SQL — this keeps the mapping bounded but means individual columns don't get native Kibana Lens numeric/date typing or exact-match aggregations out of the box.

> **Note on `event.outcome` for posture data:** For the `device_check` and `issues` data streams, `event.outcome` reflects the device posture result, not the success of event processing. A check run with status `passing` (or a resolved issue) maps to `event.outcome: success`, `failing` (or an open issue) maps to `event.outcome: failure`, and `inapplicable` or `unknown` check statuses map to `event.outcome: unknown`. The raw posture state is also preserved in `kolide.device_check.status` for `device_check`.

> **Note on host correlation for `device_check`:** Check-run results identify the device only by its numeric Kolide device ID, mapped to `host.id`. The payload carries no hostname, so `host.name` is not set on this data stream. Correlate check runs with the `device`, `auth`, and `issues` data streams using the shared `host.id`. If you need `host.name` directly on check-run documents, enrich them at ingest time with an Elasticsearch [enrich policy](https://www.elastic.co/docs/manage-data/ingest/transform-enrich/data-enrichment) that maps `host.id` to `host.name` from the `device` data stream. This requires the `device` data stream to be enabled and the enrich policy to be executed and periodically refreshed so new or renamed devices resolve.

> **Note on document identity for `request`:** The REST API (`GET /exemption_requests`, `GET /registration_requests`) has no modified-since filter, so the CEL input re-fetches every request on every poll. To avoid re-indexing an unchanged request as a duplicate on every poll, documents are deduplicated on the request's identity (`kolide.request.id` + `kolide.request.type`) plus its current status and decision notes, rather than a full-content hash. This means `request` reflects each request's *latest known status* — normally one document per request, continuously superseded as its status changes — not a full history of every transition. Kolide supports reopening a previously-approved or previously-denied request, so a request can cycle through the same status more than once; if it is re-decided with the exact same status and decision note text as a previous decision, that occurrence is indistinguishable from the earlier one and is deduplicated away. For the full timeline of who approved, denied, or reopened a request and when, use the `audit` data stream (`audit_log.recorded`), correlating on `user.target.email` and `rule.name` (the audit log entries for these actions do not carry the request's own id).

> **Note on document identity for `people`:** `GET /people` is a full-table snapshot with no modified-since filter, so the CEL input re-fetches every person on every poll. Documents are deduplicated on a fingerprint of the entire raw record, excluding `last_authenticated_at` (which changes on every login and would otherwise produce a new document every time an active person authenticates). This means a change to any other field — name, email, registered-device status, or SCIM usernames — produces a new document, while an unchanged record (aside from `last_authenticated_at`) is safely deduplicated across polls.

### Supported use cases

Monitoring device-trust posture, investigating SSO authentication outcomes alongside device compliance state, tracking approval workflows, tracking device enrollment and blocking transitions, correlating device activity with people identity records, and auditing administrative changes in Kolide — all correlated with the rest of your security data in Elastic via ECS.

## What do I need to use this integration?

- Elastic Agent installed on a host that can receive Kolide webhooks (a publicly reachable HTTPS endpoint), reach `https://api.kolide.com`, or read from your AWS S3 bucket or SQS queue, or your Google Cloud Storage bucket.
- A Kolide tenant with Full Access administrator privileges to create API keys, webhook endpoints, or Log Pipeline destinations.

## How do I deploy this integration?

### Agent-based deployment

Elastic Agent must be installed. For more details, check the Elastic Agent [installation instructions](https://www.elastic.co/guide/en/fleet/current/elastic-agent-installation.html). You can install only one Elastic Agent per host.

### Set up steps in Kolide

As a Full Access administrator, sign in to Kolide and choose one or more collection methods:

For webhooks:
1. Go to Settings → Developers → Webhooks and add **one** new endpoint.
2. Provide a publicly reachable HTTPS URL pointing at the Elastic Agent's listening address, port, and path (for example, `https://<agent-host>:9550/kolide/webhook`).
3. Subscribe the endpoint to **all** event types — the integration routes each event to the correct data stream automatically.
4. Copy the endpoint signing secret (shown once) — you will provide it to the integration as the HMAC key.

For the REST API:
1. Go to Settings → Developers → API Keys and create a new key (read access is sufficient).
2. Copy the API key (shown once); it has the form `k2sk_v1_...`.

For the AWS S3 Log Pipeline:
1. In Kolide, go to Log Destinations and add a new Amazon S3 Bucket destination.
2. Choose STS (recommended): create an IAM role in your own AWS account whose trust policy allows Kolide's AWS account (`516897320088`) to assume it, gated by the External ID that Kolide displays. Grant the role `s3:GetBucketLocation`, `s3:GetObject`, and `s3:PutObject` on the bucket so Kolide can write logs.
3. Select the log types to deliver (authentication logs, audit logs, check results, and osquery Result/Status logs) and, optionally, customize the object key template.
4. On the read side, the Elastic Agent uses your own AWS credentials (not Kolide's role). For SQS mode, configure an S3 event notification (`s3:ObjectCreated:*`) to an SQS queue and grant the reader `s3:GetObject` plus `sqs:ReceiveMessage`, `sqs:DeleteMessage`, and `sqs:GetQueueAttributes`. For direct polling, grant `s3:GetObject` and `s3:ListBucket`. Add `kms:Decrypt` if the bucket uses SSE-KMS.

For the Google Cloud Storage Log Pipeline:
1. In your GCP project, create a GCS bucket and a service account that can enumerate, read, and write objects in it (the `Storage Object Admin` role on the bucket), and generate a JSON key for that service account. Kolide requires all three capabilities on the write side.
2. In Kolide, go to Log Destinations and add a new GCP Storage Bucket destination. Provide a display name and the bucket name, and paste the JSON key file contents.
3. Toggle on the log types to deliver — Administrator Audit Logs, User Authentication Logs, Device Check Run Logs, and osquery Result/Status Logs are the types this integration ingests. Each type has an editable object path template; the defaults (`kolide/audit_logs/<timestamp>.json`, `kolide/auth_logs/<request_id>/<auth_event_type>-<timestamp>.json`, `kolide/check_runs/check-<check_id>/<timestamp>.json`, `kolide/results/...`, `kolide/status/...`) match the integration's default file selectors, so only change them if you also adjust the file selector regex on the Elastic side.
4. On the read side, create a **separate** service account with read-only access to the bucket (the `Storage Object Viewer` role) and generate a JSON key for it — the Elastic Agent uses this one, not the writer key. Alternatively, when the Agent runs on GCE/GKE with an attached service account, leave the credentials empty to use Application Default Credentials.

Note: Kolide sends webhooks from dynamic AWS us-east-1 IP addresses, so IP allow-listing is not a reliable control — rely on the HMAC signature instead.

#### Vendor resources
- [Kolide Webhooks documentation](https://www.kolide.com/docs/developers/webhooks)
- [Kolide REST API reference](https://kolideapi.readme.io/reference)
- [Kolide Log Pipeline documentation](https://www.kolide.com/docs/admins/log-pipeline/overview)
- [Configuring Google Cloud Storage for the Log Pipeline](https://www.kolide.com/docs/using-kolide/log-pipeline/configuring-google-cloud-storage)

### Set up steps in Kibana

1. In Kibana, go to Management → Integrations and search for Kolide.
2. Add the integration.
3. For webhooks: enable the `webhook` data stream (HTTP endpoint input). Set the listen address, port, and URL path, and provide the HMAC signing secret (and optionally the `X-Kolide-Webhook-Identifier` value). All Kolide event types are received on this single endpoint and routed automatically.
4. For the REST API: enable whichever data streams you want to poll (auth, issues, request, device, people, audit), select the CEL input, provide the API URL (`https://api.kolide.com`), the API key, and adjust the polling interval and initial lookback as needed.
5. For AWS S3 (Log Pipeline): provide your AWS credentials once on the integration, then enable the `aws-s3` input on the data streams you want — `auth`, `audit`, `device_check`, `osquery_result`, or `osquery_status`. Each defaults to its Kolide prefix (`kolide/auth_logs/`, `kolide/audit_logs/`, `kolide/check_runs/`, `kolide/results/`, `kolide/status/`). For each, set either an SQS queue URL (SQS mode) or a bucket ARN (polling mode). In SQS mode, use a separate queue per prefix (filter S3 notifications by prefix); in polling mode each stream lists only its own prefix. Adjust the bucket list prefix if your Kolide destination uses a custom key template.
6. For Google Cloud Storage (Log Pipeline): provide the GCP project ID and the reader service account JSON key once on the integration, then enable the `gcs` input on the data streams you want — `auth`, `audit`, `device_check`, `osquery_result`, or `osquery_status`. Set the bucket name in each stream's Buckets setting. Each stream's file selector defaults to its Kolide prefix (`kolide/auth_logs/`, `kolide/audit_logs/`, `kolide/check_runs/`, `kolide/results/`, `kolide/status/`); adjust the regex if your Kolide destination uses a custom key template.

### Validation

After setup, generate or wait for activity in Kolide (for example, sign in via SSO to produce an auth log). In Kibana, open Discover and confirm documents are arriving in the `logs-kolide.*` data streams.

## Troubleshooting

- No data via webhooks: Confirm the Kolide endpoint URL matches the Agent's listen address, port, and path, that the endpoint is publicly reachable over HTTPS, and that the HMAC signing secret matches.
- Webhook signature failures: Ensure the configured HMAC key equals the Kolide endpoint signing secret; Kolide signs the raw request body with HMAC-SHA256 and sends the lowercase hex digest in the `Authorization` header with no prefix.
- No data via the REST API: Verify the API key is valid (a 401 indicates a turned-off feature or bad token, and a 403 indicates the key lacks permission) and that the host can reach `https://api.kolide.com`.
- No data via AWS S3: Confirm the Elastic Agent credentials can `s3:ListBucket` and `s3:GetObject` on the bucket (and `sqs:ReceiveMessage` in SQS mode), that the bucket list prefix matches your Kolide object key template, and that SQS notifications are filtered to the correct prefix. Kolide writes to `kolide/auth_logs/`, `kolide/audit_logs/`, `kolide/check_runs/`, `kolide/results/`, and `kolide/status/` by default.
- No data via Google Cloud Storage: Confirm the project ID and bucket name are correct, that the reader service account has the `Storage Object Viewer` role on the bucket, and that each stream's file selector regex matches your Kolide object key template (the defaults expect the `kolide/auth_logs/`, `kolide/audit_logs/`, `kolide/check_runs/`, `kolide/results/`, and `kolide/status/` prefixes).
- No `host.id`/`host.name` on `osquery_result`/`osquery_status` documents: these fields are populated from Kolide's `kolide_decorations` block, which requires the device to be enrolled with Kolide's own launcher. A bare open-source osquery deployment shipping logs through the Log Pipeline only carries `kolide.osquery_result.host_identifier` / `kolide.osquery_status.host_identifier` (osquery's own `hostIdentifier`), not the Kolide-decorated host fields.

## Performance and scaling

For more information on architectures that can be used for scaling this integration, check the [Ingest Architectures](https://www.elastic.co/docs/manage-data/ingest/ingest-reference-architectures) documentation.

### Choosing a transport per data stream

Kolide's Log Pipeline writes one log per object rather than batching, so the AWS S3/SQS and GCS inputs make a separate fetch for every document. For high-volume streams this is fine, but for small, sparse streams it adds many network round-trips and can make large backlogs slow to drain. To keep latency low and avoid contention on a shared S3 queue, consider matching the transport to the stream:

- **`audit` and `auth`**: prefer the REST API (CEL) or webhook inputs. These streams are typically small and sparse, and the API/webhook paths deliver them quickly without per-object fetches.
- **`device_check` (check runs), `osquery_result`, and `osquery_status`**: use the AWS S3 or GCS input — these are the only collection methods available for them. These streams are typically large and/or high-volume (`osquery_result` especially, since every scheduled query execution can produce a log line), so object storage is the appropriate fit; keeping them there also keeps the small, important streams off the same queue.

This split keeps the small streams responsive while still using object storage for the bulk data.

If you do consume large streams over S3/SQS or GCS, you can increase throughput by running multiple Elastic Agents (or scaling out workers) so objects are processed concurrently. Note the one-object-per-log behavior is a Kolide-side limitation. The guidance above is a workaround until it is addressed upstream.

## Reference

### Inputs used
{{ inputDocs }}

### API usage

These Kolide REST API endpoints are used by this integration:
* `GET /auth_logs`
* `GET /issues`
* `GET /exemption_requests`
* `GET /registration_requests`
* `GET /devices`
* `GET /people`
* `GET /audit_logs`

### Vendor documentation links
- [Kolide documentation](https://www.kolide.com/docs)
- [Kolide Webhooks](https://www.kolide.com/docs/developers/webhooks)
- [Kolide REST API reference](https://kolideapi.readme.io/reference)
- [Kolide Log Pipeline](https://www.kolide.com/docs/admins/log-pipeline/overview)

### Data streams

#### webhook

The `webhook` data stream is the single ingress point for all Kolide webhook events. It listens on one HTTP endpoint and uses the ingest `reroute` processor to redirect each event to the appropriate target data stream (`auth`, `issues`, `device`, or `audit`) based on the Kolide event type. No documents are stored in the `webhook` data stream itself.

##### webhook fields

{{ fields "webhook" }}

#### auth

The `auth` data stream provides Kolide SSO authentication sessions, including the device-trust posture at sign-in, the client IP and geolocation, and the sub-events of the session.

##### auth fields

{{ fields "auth" }}

##### auth sample event

{{ event "auth" }}

#### issues

The `issues` data stream provides Kolide posture-check failures and resolutions for devices.

##### issues fields

{{ fields "issues" }}

##### issues sample event

{{ event "issues" }}

#### request

The `request` data stream provides Kolide approval-workflow records for issue exemptions and device registrations from the REST API and request webhooks.

##### request fields

{{ fields "request" }}

##### request sample event

{{ event "request" }}

#### device

The `device` data stream provides Kolide device inventory records and device-trust status changes.

##### device fields

{{ fields "device" }}

##### device sample event

{{ event "device" }}

#### people

The `people` data stream provides Kolide identity records for people (`GET /people`): ECS user fields plus the SCIM-imported usernames, last-authentication time, and device-registration flag Kolide exposes on this resource. Group, IdP, SCIM, and deprovisioning details live on separate Kolide API resources (`person_groups`, `deprovisioned_people`) that this data stream does not currently call.

##### people fields

{{ fields "people" }}

##### people sample event

{{ event "people" }}

#### audit

The `audit` data stream provides the Kolide administrative audit log of console actions.

##### audit fields

{{ fields "audit" }}

##### audit sample event

{{ event "audit" }}

#### device_check

The `device_check` data stream provides Kolide device check-run results delivered through the Log Pipeline (S3). Unlike the `issues` data stream, which tracks the failure lifecycle, this stream records every check run — `passing`, `failing`, `inapplicable`, and `unknown`.

##### device_check fields

{{ fields "device_check" }}

##### device_check sample event

{{ event "device_check" }}

#### osquery_result

The `osquery_result` data stream provides raw osquery Result Logs delivered through the Log Pipeline (S3/GCS `kolide/results/`) — both snapshot-query rows and differential (`added`/`removed`) rows. Per-query column data (`kolide.osquery_result.columns`/`.snapshot`) is arbitrary depending on the target osquery table or custom SQL, so it is stored as a flattened field rather than mapped per column.

##### osquery_result fields

{{ fields "osquery_result" }}

##### osquery_result sample event

{{ event "osquery_result" }}

#### osquery_status

The `osquery_status` data stream provides raw osquery Status Logs (GLOG-style telemetry about the osquery daemon itself) delivered through the Log Pipeline (S3/GCS `kolide/status/`).

##### osquery_status fields

{{ fields "osquery_status" }}

##### osquery_status sample event

{{ event "osquery_status" }}

{{ ilm }}

{{ transform }}
