{{- generatedHeader }}
# Kolide Integration for Elastic

## Overview

The Kolide integration for Elastic collects device-trust and endpoint-compliance logs from [Kolide](https://www.kolide.com/) (by 1Password). It ingests authentication sessions, posture issues, device inventory and trust-status changes, and administrative audit events, normalizes them to the Elastic Common Schema (ECS), and makes them available for search, visualization, and detection in Elastic.

### Compatibility

This integration works with the current Kolide Device Trust platform ("Kolide K2") and its public REST API (version `2026-04-07`) and webhooks. It does not cover the legacy open-source Kolide Fleet (osquery) product.

### How it works

Each data stream supports two collection methods that you can choose between when configuring the integration:

- Webhooks (HTTP endpoint): Kolide pushes events in near real time to an HTTP endpoint exposed by the Elastic Agent. This is the recommended method for low-latency device-compliance data. Each delivery is signed with an HMAC-SHA256 signature for verification.
- REST API (polling): the Elastic Agent periodically polls the Kolide REST API and collects new records using cursor-based pagination and a timestamp filter. This is useful for backfill and for fuller resource records.

## What data does this integration collect?

The Kolide integration collects the following data streams:

* `auth`: SSO authentication sessions (`auth_logs.success`, `auth_logs.failure`; API `GET /auth_logs`).
* `issues`: device posture-check failures and resolutions (`issues.new`, `issues.resolved`; API `GET /issues`).
* `device`: device inventory and trust-status changes (`devices.created`, `devices.registered`, `devices.destroyed`, `device_trust.status_changed`; API `GET /devices`).
* `audit`: administrative audit log of console actions (`audit_log.recorded`; API `GET /audit_logs`).

### Supported use cases

Monitoring device-trust posture, investigating SSO authentication outcomes alongside device compliance state, tracking device enrollment and blocking transitions, and auditing administrative changes in Kolide — all correlated with the rest of your security data in Elastic via ECS.

## What do I need to use this integration?

- Elastic Agent installed on a host that can either receive Kolide webhooks (a publicly reachable HTTPS endpoint) or reach `https://api.kolide.com`.
- A Kolide tenant with Full Access administrator privileges to create API keys and/or webhook endpoints.

## How do I deploy this integration?

### Agent-based deployment

Elastic Agent must be installed. For more details, check the Elastic Agent [installation instructions](https://www.elastic.co/guide/en/fleet/current/elastic-agent-installation.html). You can install only one Elastic Agent per host.

### Set up steps in Kolide

As a Full Access administrator, sign in to Kolide and choose one or both collection methods:

For webhooks:
1. Go to Settings > Developers > Webhooks and add a new endpoint.
2. Provide a publicly reachable HTTPS URL pointing at the Elastic Agent's listening address, port, and path for the data stream (for example, `https://<agent-host>:9551/kolide/auth` for the `auth` stream).
3. Subscribe the endpoint to the events for that data stream.
4. Copy the endpoint signing secret (shown once) — you will provide it to the integration as the HMAC key.

For the REST API:
1. Go to Settings > Developers > API Keys and create a new key (read access is sufficient).
2. Copy the API key (shown once); it has the form `k2sk_v1_...`.

Note: Kolide sends webhooks from dynamic AWS us-east-1 IP addresses, so IP allow-listing is not a reliable control — rely on the HMAC signature instead.

#### Vendor resources
- [Kolide Webhooks documentation](https://www.kolide.com/docs/developers/webhooks)
- [Kolide REST API reference](https://kolideapi.readme.io/reference)

### Set up steps in Kibana

1. In Kibana, go to Management > Integrations and search for Kolide.
2. Add the integration and choose, per data stream, whether to collect via webhooks (HTTP endpoint) or the REST API.
3. For webhooks: set the listen address, port, and URL path, and provide the HMAC signing secret (and optionally the `X-Kolide-Webhook-Identifier` value).
4. For the REST API: provide the API URL (`https://api.kolide.com`), the API key, and adjust the polling interval and initial lookback as needed.

### Validation

After setup, generate or wait for activity in Kolide (for example, sign in via SSO to produce an auth log). In Kibana, open Discover and confirm documents are arriving in the `logs-kolide.*` data streams.

## Troubleshooting

- No data via webhooks: Confirm the Kolide endpoint URL matches the Agent's listen address, port, and path, that the endpoint is publicly reachable over HTTPS, and that the HMAC signing secret matches.
- Webhook signature failures: Ensure the configured HMAC key equals the Kolide endpoint signing secret; Kolide signs the raw request body with HMAC-SHA256 and sends the lowercase hex digest in the `Authorization` header with no prefix.
- No data via the REST API: Verify the API key is valid (a 401 indicates a disabled feature or bad token; a 403 indicates the key lacks permission) and that the host can reach `https://api.kolide.com`.

## Performance and scaling

For more information on architectures that can be used for scaling this integration, check the [Ingest Architectures](https://www.elastic.co/docs/manage-data/ingest/ingest-reference-architectures) documentation.

## Reference

### Inputs used
{{ inputDocs }}

### API usage

These Kolide REST API endpoints are used by this integration:
* `GET /auth_logs`
* `GET /issues`
* `GET /devices`
* `GET /audit_logs`

### Vendor documentation links
- [Kolide documentation](https://www.kolide.com/docs)
- [Kolide Webhooks](https://www.kolide.com/docs/developers/webhooks)
- [Kolide REST API reference](https://kolideapi.readme.io/reference)

### Data streams

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

#### device

The `device` data stream provides Kolide device inventory records and device-trust status changes.

##### device fields

{{ fields "device" }}

##### device sample event

{{ event "device" }}

#### audit

The `audit` data stream provides the Kolide administrative audit log of console actions.

##### audit fields

{{ fields "audit" }}

##### audit sample event

{{ event "audit" }}

{{ ilm }}

{{ transform }}
