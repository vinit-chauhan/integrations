# Kolide Integration — Field Mapping Reference

Maps every `kolide.*` custom field to its ECS equivalent, with example values from
real (anonymized) event data. Status reflects what the ingest pipelines actually do today.

Legend:
- ✅ **Done** — ECS field is already set by an existing pipeline processor
- 🔄 **Proposed** — ECS field should be set; pipeline change needed
- ⚠️ **Bug** — current pipeline behaviour is incorrect or inconsistent
- ➖ **None** — no ECS equivalent; vendor field is the right choice

---

## `audit` data stream

**ECS fields set by `default.yml`:**
`@timestamp`, `event.id`, `event.action`, `event.kind` (`event`),
`event.category` (`iam`), `event.type` (`admin`),
`user.name` (actor name), `user.email` (actor email),
`source.ip`, `source.geo.*` (GeoIP), `source.as.*` (ASN),
`message` (= `description` text)

**ECS fields set by `extended-mappings.yml`:**
`user.target.email`, `host.name`, `host.hostname`, `rule.name`,
`related.hosts`, `related.user`

| Custom Field | Type | Example Values | ECS Field | Status | Notes |
|---|---|---|---|---|---|
| `kolide.audit.actor_type` | keyword | `User`, `ApiKey`, `System` | — | ➖ | No ECS equivalent |
| `kolide.audit.target.user_email` | keyword | `bob.smith@example.com` | `user.target.email` | ✅ | Dissected directly from `message` in extended-mappings |
| `kolide.audit.target.device_serial` | keyword | `J7NRCX08C007310`, `SN000000000001` | — | ➖ | No ECS serial-number field |
| `kolide.audit.target.issue_id` | keyword | `455148606`, `455173972` | — | ➖ | `event.id` is already the audit-log ID |
| `kolide.audit.target.org_id` | keyword | `6098` | — | ➖ | No ECS equivalent |
| `kolide.audit.target.idp_url` | keyword | `idp-example.okta.com` | `url.domain` / `url.full` | 🔄 | Use `url.domain` if hostname-only, `url.full` if a full URL |
| `kolide.audit.target.provider_name` | keyword | `Jamf`, `CrowdStrike`, `test` | — | ➖ | No ECS equivalent |
| `kolide.audit.target.org_name` | keyword | `Example Org` | — | ➖ | No ECS equivalent |
| `kolide.audit.target.config_type` | keyword | `Device Trust Level` | — | ➖ | No ECS equivalent |
| `kolide.audit.target.api_key_name` | keyword | `example-api-key-1` | — | ➖ | No ECS equivalent |
| `kolide.audit.change.field` | keyword | `Hide Names of Admins in Privacy Center` | — | ➖ | No ECS change-log model |
| `kolide.audit.change.from` | keyword | `false`, `only registered owner` | — | ➖ | No ECS equivalent |
| `kolide.audit.change.to` | keyword | `true`, `anyone`, `disable_auto_snooze` | — | ➖ | No ECS equivalent |
| `kolide.audit.reason` | keyword | `It's already up-to-date`, `TEST EXPLANATION` | — | ➖ | No ECS equivalent |
| `kolide.audit.expires_at` | keyword | `2026-06-22` | — | ➖ | Human-readable string; not parsed as date |

**Note on `host.name` / `host.hostname` in audit:**
Audit log descriptions reference device display names (e.g. `"host-example-01"` for a Linux
device or `"Pixel 10 Pro"` for an Android device). These are the same values Kolide uses as
`host.name` in the device data stream, so cross-stream correlation works. However,
`host.hostname` is always a copy of `host.name` — for mobile devices the value is a model/
display name, not a real OS hostname.

**Note on `rule.name` in audit:**
Audit log descriptions reference check names (e.g. `"Disk Is Not Encrypted"`). These are the
same values Kolide uses as `rule.name` in the issues data stream.

---

## `auth` data stream

**ECS fields set by `default.yml` (API path):**
`@timestamp`, `event.id`, `event.action`, `event.kind` (`event`),
`event.category` (`authentication`, `session`), `event.type` (`start`, `info`),
`event.outcome` (from `result`: `Success` → `success`, `Fail` → `failure`),
`user.name` (← `person_name`), `user.email` (← `person_email`),
`user.id` (← `person_info.identifier`),
`host.id` (← `device_info.identifier` — the Kolide numeric device ID),
`source.ip`, `source.geo.*` (GeoIP + vendor fallback from `city`/`country`),
`user_agent.name` (← `browser_name`), `user_agent.original` (← `browser_user_agent`),
`related.ip`, `related.user`, `related.hosts`

**ECS fields set by `default.yml` (webhook path):**
Same as above, plus `host.name` (← `data.device_name`) and `host.hostname`

| Custom Field | Type | Example Values | ECS Field | Status | Notes |
|---|---|---|---|---|---|
| `kolide.auth.result` | keyword | `Success`, `Fail` | `event.outcome` | ✅ | `event.outcome` is set DIRECTLY in `default.yml` from `json.result` before the rename; extended-mappings processor is redundant |
| `kolide.auth.initial_status` | keyword | `all_good`, `unknown`, `will_block`, `blocked` | — | ➖ | Device trust posture at session start; no ECS equivalent |
| `kolide.auth.agent_version` | keyword | `2.1.1`, `null` | — | ➖ | Version of Kolide launcher on the device; `observer.version` semantically refers to the pipeline observer, not an endpoint agent |
| `kolide.auth.url` | keyword | `https://api.kolide.com/auth_logs/…` | — | ➖ | Internal API reference URL (webhook only) |
| `kolide.auth.okta.app_name` | keyword | `null` (seen in samples) | — | ➖ | No ECS equivalent |
| `kolide.auth.okta.app_instance_id` | keyword | `null` (seen in samples) | — | ➖ | No ECS equivalent |
| `kolide.auth.issues_displayed.id` | keyword | _(issue numeric ID)_ | — | ➖ | No ECS equivalent |
| `kolide.auth.issues_displayed.title` | keyword | _(issue title string)_ | — | ➖ | No ECS equivalent |
| `kolide.auth.issues_displayed.blocking_status` | keyword | `blocked`, `will_block` | — | ➖ | No ECS equivalent |
| `kolide.auth.issues_displayed.link` | keyword | `https://api.kolide.com/issues/…` | — | ➖ | Internal API reference URL |
| `kolide.auth.events.timestamp` | date | _(ISO8601)_ | — | ➖ | Sub-event timestamp array |
| `kolide.auth.events.event_type` | keyword | `sign_in_attempt`, `agent_detection_success`, `sign_in_success`, `push_notification_sent` | — | ➖ | Kolide-specific sub-event taxonomy |
| `kolide.auth.events.event_description` | keyword | `SAML session started by …`, `Kolide agent found` | — | ➖ | Human-readable sub-event detail |
| `kolide.auth.downloaded_packages` | keyword | _(array of package name strings)_ | `package.name` | 🔄 | ECS `package.name` is scalar; array variant needs `foreach` or a different model |

**Note on `host.*` in auth API events:**
The API response contains `device_info.identifier` (e.g. `"1152637"`) — the Kolide numeric
device ID — which is correctly mapped to `host.id`. There is no device name in the API
response, so `host.name` and `host.hostname` are NOT set for API-sourced auth events.
For webhook events, `data.device_name` provides `host.name`. Use `host.id` for reliable
cross-stream correlation between auth and device records.

---

## `device` data stream

**ECS fields set by `default.yml`:**
`@timestamp`, `event.id`, `event.action`, `event.kind` (`state` for API, `event` for webhook),
`event.category` (`host`), `event.type` (`info` / `change`), `event.start` (← `registered_at`),
`host.name` (← `json.name` — display name; real hostname for Linux/Mac, model name for Android/iOS),
`host.hostname` (copy of `host.name`),
`host.id` (← `json.id` — Kolide numeric device ID),
`host.os.full` (← `operating_system`, e.g. `"Ubuntu 24.04.3 LTS"`),
`host.os.name` / `host.os.version` (split from `host.os.full`),
`host.os.platform` (← `device_type`: `Mac`, `Linux`, `Windows`, `iOS`, `Android`),
`host.type` (← `form_factor`: `phone` → `mobile`, `tablet` → `tablet`, `Computer` → `desktop`),
`user.id` (← `registered_owner_info.identifier`),
`user.email` / `user.name` (webhook only, ← `registered_owner.*`),
`related.hosts`, `related.user`

**ECS fields set by `extended-mappings.yml`:**
`host.os.type` (← `host.os.platform`: `mac` → `macos`, `android` → `android`, etc.)

| Custom Field | Type | Example Values | ECS Field | Status | Notes |
|---|---|---|---|---|---|
| `kolide.device.type` | keyword | `Android`, `Linux`, `Mac`, `Windows`, `iOS` | `host.os.platform` | ⚠️ | Redundant — `default.yml` already copies this value to `host.os.platform` before saving it here |
| `kolide.device.status` | keyword | `good`, `blocked`, `will_block` | — | ➖ | Normalized combined status; no ECS equivalent |
| `kolide.device.device_status` | keyword | `blocked` (webhook raw value) | — | ➖ | Raw webhook value before normalization |
| `kolide.device.device_url` | keyword | `https://api.kolide.com/devices/…` | — | ➖ | Internal API reference URL |
| `kolide.device.registered_at` | date | `2026-06-15T14:45:20.335Z` | `event.start` | ✅ | Already mapped to `event.start` in `default.yml` |
| `kolide.device.last_authenticated_at` | date | `2026-06-15T14:49:51.173Z` | — | ➖ | No ECS field for last-authenticated timestamp |
| `kolide.device.last_seen_at` | date | `2026-06-15T14:46:09.000Z` | — | ➖ | No ECS field for last-seen timestamp |
| `kolide.device.will_block_at` | date | _(ISO8601 or null)_ | — | ➖ | No ECS equivalent |
| `kolide.device.hardware_model` | keyword | `TUF GAMING FX504GD_FX80GD`, `Pixel 10 Pro` | — | ➖ | No ECS hardware-model field; distinct from `host.name` (display name) on Linux/Mac |
| `kolide.device.serial` | keyword | `J7NRCX08C007310`, `null` | — | ➖ | No ECS serial-number field |
| `kolide.device.hardware_uuid` | keyword | `07b8f36b-a821-a045-9c72-7dc103794cc2`, `null` | `host.id` | 🔄 | Can supplement `host.id` (already set from Kolide device ID) when present |
| `kolide.device.note` | text | _(free text or null)_ | — | ➖ | No ECS equivalent |
| `kolide.device.auth_state` | keyword | `Good`, `Blocked` (raw API values) | — | ➖ | Raw API value before normalization into `kolide.device.status` |
| `kolide.device.product_image_url` | keyword | `https://assets2.kolide.com/…` | — | ➖ | Vendor UI metadata |
| `kolide.device.form_factor` | keyword | `computer`, `phone` | `host.type` | ✅ | `default.yml` already maps `form_factor` to `host.type` before saving it here |
| `kolide.device.registered_owner_info.identifier` | keyword | `864140` | `user.id` | ✅ | `default.yml` already converts this to `user.id` before saving it here |
| `kolide.device.registered_owner_info.location` | keyword | `https://api.kolide.com/people/…` | — | ➖ | Internal API reference URL |
| `kolide.device.auth_configuration.device_id` | keyword | `1153524` | `host.id` | ✅ | Redundant — same value already in `host.id` |
| `kolide.device.auth_configuration.authentication_mode` | keyword | `anyone`, `only_registered_owner` | — | ➖ | No ECS equivalent |
| `kolide.device.auth_configuration.person_groups` | flattened | `[]` | — | ➖ | No ECS equivalent |

**Note on `host.name` vs `host.hostname` for mobile devices:**
Kolide uses the device display name as `name` for all device types. For Linux/Mac, this is
the actual OS hostname (e.g. `"cruncher"`). For Android/iOS, it is the model name
(e.g. `"Pixel 10 Pro"`). Both `host.name` and `host.hostname` receive the same value,
so `host.hostname` does not represent an OS hostname for mobile devices.

**Note on `kolide.device.type` redundancy:**
`json.device_type` (e.g. `"Linux"`) is copied to `host.os.platform` AND to `kolide.device.type`.
`kolide.device.type` is therefore a duplicate of `host.os.platform` and could be removed.

---

## `issues` data stream

**ECS fields set by `default.yml`:**
`@timestamp`, `event.id`, `event.action`, `event.kind` (`event`),
`event.category` (`configuration`), `event.type` (`creation` / `change`),
`event.start` (← `detected_at`), `event.end` (← `resolved_at`),
`host.name` (webhook: ← `data.device.name`; ⚠️ API: ← `device_information.identifier` — numeric ID!),
`host.hostname` (copy of `host.name`),
`host.id` (webhook only, ← `data.device.id`),
`rule.name` (webhook: ← `data.check.name`),
`rule.id` (webhook: ← `data.check.id`; API: ← `check_information.identifier`),
`message` (= issue title),
`user.name` (← `value.username` when present),
`file.path` (← `value.path`), `file.hash.md5`, `file.hash.sha256`,
`related.hosts`, `related.user`

**ECS fields set by `extended-mappings.yml`:**
`file.device` (← `value.device`, for disk encryption checks)

| Custom Field | Type | Example Values | ECS Field | Status | Notes |
|---|---|---|---|---|---|
| `kolide.issues.id` | keyword | `455173998`, `455148606` | — | ➖ | Kolide issue record ID; `event.id` holds the ULID/envelope ID |
| `kolide.issues.title` | keyword | `Unencrypted SSH Key Detected`, `Disk Is Not Encrypted` | `message` | ✅ | Already copied to `message` |
| `kolide.issues.issue_key` | keyword | `path`, `check_target`, `pk`, `null` | — | ➖ | Type of failing attribute; no ECS equivalent |
| `kolide.issues.issue_value` | keyword | `/home/vinit/.ssh/id_ed25519`, `/`, `null` | — | ➖ | Value of the failing attribute; context-dependent |
| `kolide.issues.value` | flattened | `{"KOLIDE_CHECK_STATUS":"FAIL","key_type":"ssh-ed25519","version":"148.0…"}` | — | ➖ | Full check result; sub-fields promoted individually to ECS |
| `kolide.issues.exempted` | boolean | `false`, `true` | — | ➖ | No ECS exemption concept |
| `kolide.issues.detected_at` | date | `2026-06-15T00:13:43.909Z` | `event.start` | ✅ | Already mapped |
| `kolide.issues.resolved_at` | date | _(ISO8601 or null)_ | `event.end` | ✅ | Already mapped |
| `kolide.issues.blocks_device_at` | date | _(ISO8601 or null)_ | — | ➖ | No ECS equivalent |
| `kolide.issues.last_rechecked_at` | date | `2026-06-15T00:13:43.000Z` | — | ➖ | No ECS equivalent |
| `kolide.issues.check.id` | keyword | _(check UUID)_ | `rule.id` | ✅ | Set from webhook `check_id`; `check_information.identifier` used for API |
| `kolide.issues.check.tags` | keyword | _(array of tag strings)_ | `rule.category` | 🔄 | `rule.category` is a reasonable match for check tags |
| `kolide.issues.device_information.location` | keyword | `https://api.kolide.com/devices/1152637` | — | ➖ | Internal API reference URL |
| `kolide.issues.check_information.location` | keyword | `https://api.kolide.com/checks/3` | — | ➖ | Internal API reference URL |
| `kolide.issues.detected_version` | keyword | `148.0.7778.167-64` | `package.version` | 🔄 | Applies only to software-version checks (Chrome, OS updates); wrong semantic for other check types |
| `kolide.issues.expected_version` | keyword | `149.0.7827.114` | — | ➖ | No ECS "required version" field |
| `kolide.issues.ssh_key_type` | keyword | `ssh-ed25519`, `ssh-rsa` | — | ➖ | No ECS key-algorithm field |

**⚠️ Bug — `host.name` for API-sourced issues:**
For API events, `default.yml` maps `device_information.identifier` (e.g. `"1152637"`, a numeric
Kolide device ID) to `host.name`. This is incorrect — a numeric ID is not a hostname. It should
go to `host.id`. The webhook path correctly sets `host.name` from `data.device.name` (the actual
device display name). Fix: change the API fallback to set `host.id` instead of `host.name`.

---

## Summary of actionable changes

| Priority | Stream | Change | Action |
|---|---|---|---|
| ⚠️ Bug | issues | `device_information.identifier` → `host.name` (API path) | Move to `host.id`; leave `host.name` unset for API issues |
| 🔄 High | audit | `kolide.audit.target.idp_url` | Set `url.domain` or `url.full` depending on value format |
| 🔄 Medium | issues | `kolide.issues.check.tags` | Set `rule.category` from tag array |
| 🔄 Medium | issues | `kolide.issues.detected_version` | Set `package.version` conditionally (software-version checks only) |
| 🔄 Low | auth | `kolide.auth.downloaded_packages` | Explore `package.name` array approach |
| ⚠️ Redundant | device | `kolide.device.type` | Same as `host.os.platform`; consider removing |
| ⚠️ Redundant | device | `kolide.device.registered_at` | Same as `event.start`; consider removing |
| ⚠️ Redundant | device | `kolide.device.form_factor` | Already drives `host.type`; could be removed |
| ⚠️ Redundant | device | `kolide.device.registered_owner_info.identifier` | Same as `user.id`; consider removing |
| ⚠️ Redundant | auth | Extended-mappings `event.outcome` | Already set in `default.yml`; extended-mappings processor is a no-op |
