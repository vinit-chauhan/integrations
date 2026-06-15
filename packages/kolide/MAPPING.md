# Kolide Integration — Field Mapping Reference

This file maps every `kolide.*` custom field to its ECS equivalent (where one exists),
lists example values from real (anonymized) sample events, and notes which mappings are
already applied in the ingest pipelines.

Legend:
- **ECS mapping** — the standard ECS field that carries the same semantic meaning
- **Status**: ✅ done (pipeline already sets ECS field), 🔄 proposed (not yet in pipeline), ➖ none (no ECS equivalent)

---

## `audit` data stream

ECS fields already set by `default.yml`: `@timestamp`, `event.id`, `event.action`,
`event.kind` (`event`), `event.category` (`iam`), `event.type` (`admin`),
`user.name`, `user.email`, `source.ip`, `source.geo.*`, `source.as.*`, `message`
(= description text).

ECS fields set by `extended-mappings.yml`: `user.target.email`, `host.name`,
`host.hostname`, `rule.name`, `related.hosts`, `related.user`.

| Custom Field | Type | Example Values | ECS Field | Status | Notes |
|---|---|---|---|---|---|
| `kolide.audit.actor_type` | keyword | `User`, `ApiKey`, `System` | — | ➖ | No ECS equivalent; describes who initiated the action |
| `kolide.audit.target.user_email` | keyword | `bob.smith@example.com`, `alice.johnson@example.com` | `user.target.email` | ✅ | Populated by dissect patterns in extended-mappings |
| `kolide.audit.target.device_name` | keyword | `Example Phone`, `host-example-01`, `example-macbook` | `host.name` | 🔄 | Replace with direct ECS in extended-mappings dissects |
| `kolide.audit.target.device_serial` | keyword | `SN000000000001`, `SN000000000002` | — | ➖ | No ECS serial-number field |
| `kolide.audit.target.check_name` | keyword | `Disk Is Not Encrypted`, `Android Software Updates - Ensure Android OS Is Up to Date` | `rule.name` | 🔄 | Replace with direct ECS in extended-mappings dissects |
| `kolide.audit.target.issue_id` | keyword | `455148606`, `455173972` | — | ➖ | `event.id` is already the audit-log ID; no ECS field for issue reference |
| `kolide.audit.target.org_id` | keyword | `6098` | — | ➖ | No ECS equivalent |
| `kolide.audit.target.idp_url` | keyword | `idp-example.okta.com` | `url.domain` / `url.full` | 🔄 | Use `url.domain` for hostnames, `url.full` for full URLs |
| `kolide.audit.target.provider_name` | keyword | `test` | — | ➖ | No ECS equivalent |
| `kolide.audit.target.org_name` | keyword | `Example Org` | — | ➖ | No ECS equivalent |
| `kolide.audit.target.config_type` | keyword | `Device Trust Level` | — | ➖ | No ECS equivalent |
| `kolide.audit.target.api_key_name` | keyword | `example-api-key-1` | — | ➖ | No ECS equivalent |
| `kolide.audit.change.field` | keyword | `Hide Names of Admins in Privacy Center` | — | ➖ | No ECS before/after change model |
| `kolide.audit.change.from` | keyword | `false`, `only registered owner`, `curl, process_envs, ps` | — | ➖ | No ECS equivalent |
| `kolide.audit.change.to` | keyword | `true`, `anyone`, `disable_auto_snooze` | — | ➖ | No ECS equivalent |
| `kolide.audit.reason` | keyword | `hehe`, `It's already up-to-date`, `TEST EXPLANATION` | — | ➖ | No ECS equivalent |
| `kolide.audit.expires_at` | keyword | `2026-06-22` | — | ➖ | Human-readable date string; could become `event.end` if parsed |

---

## `auth` data stream

ECS fields already set by `default.yml`: `@timestamp`, `event.id`, `event.action`,
`event.kind` (`event`), `event.category` (`authentication`, `session`),
`event.type` (`start`), `user.name`, `user.email`, `source.ip`.

ECS fields set by `extended-mappings.yml`: `event.outcome`.

| Custom Field | Type | Example Values | ECS Field | Status | Notes |
|---|---|---|---|---|---|
| `kolide.auth.result` | keyword | `Success`, `Fail` | `event.outcome` | ✅ | `Success` → `success`; `Fail` → `failure` |
| `kolide.auth.initial_status` | keyword | `all_good`, `unknown`, `will_block`, `blocked` | — | ➖ | Device trust posture at session start; no ECS equivalent |
| `kolide.auth.agent_version` | keyword | `2.1.1`, `null` | `observer.version` | 🔄 | Version of the Kolide launcher on the device |
| `kolide.auth.url` | keyword | _(API record URL)_ | — | ➖ | Internal API reference URL |
| `kolide.auth.okta.app_name` | keyword | _(Okta app display name)_ | — | ➖ | No ECS equivalent |
| `kolide.auth.okta.app_instance_id` | keyword | _(Okta instance ID)_ | — | ➖ | No ECS equivalent |
| `kolide.auth.issues_displayed.id` | keyword | _(issue numeric ID)_ | — | ➖ | No ECS equivalent |
| `kolide.auth.issues_displayed.title` | keyword | _(issue title)_ | — | ➖ | No ECS equivalent |
| `kolide.auth.issues_displayed.blocking_status` | keyword | `blocked`, `will_block` | — | ➖ | No ECS equivalent |
| `kolide.auth.issues_displayed.link` | keyword | _(API URL)_ | — | ➖ | Internal API reference URL |
| `kolide.auth.events.timestamp` | date | _(ISO8601)_ | — | ➖ | Sub-event timestamp; no parent ECS context for array elements |
| `kolide.auth.events.event_type` | keyword | `sign_in_attempt`, `agent_enrolled`, `device_registration_request`, … | — | ➖ | Kolide-specific event taxonomy |
| `kolide.auth.events.event_description` | keyword | `Downloaded package: launcher-1.2.3.pkg` | — | ➖ | Human-readable sub-event detail |
| `kolide.auth.downloaded_packages` | keyword | _(array of package name strings)_ | `package.name` | 🔄 | ECS `package.name` is a scalar; array here requires separate docs or `foreach` |

---

## `device` data stream

ECS fields already set by `default.yml`: `@timestamp`, `event.id`, `event.action`,
`event.kind` (`state`), `event.category` (`host`), `event.type` (`info`),
`host.name`, `host.hostname`, `host.id`, `host.os.name`, `host.os.platform`,
`host.os.version`, `user.name`, `user.email`, `related.hosts`, `related.user`.

ECS fields set by `extended-mappings.yml`: `host.os.type`.

| Custom Field | Type | Example Values | ECS Field | Status | Notes |
|---|---|---|---|---|---|
| `kolide.device.type` | keyword | `Android`, `Linux`, `Mac`, `Windows`, `iOS` | `host.type` | 🔄 | ECS `host.type` is free-form; direct mapping is reasonable |
| `kolide.device.status` | keyword | _(normalized lowercase)_ | — | ➖ | No ECS equivalent |
| `kolide.device.device_status` | keyword | `blocked` | — | ➖ | Raw webhook value; no ECS equivalent |
| `kolide.device.device_url` | keyword | _(API URL)_ | — | ➖ | Internal API reference URL |
| `kolide.device.registered_at` | date | _(ISO8601)_ | — | ➖ | No ECS timestamp for device registration |
| `kolide.device.last_authenticated_at` | date | _(ISO8601)_ | — | ➖ | No ECS equivalent |
| `kolide.device.last_seen_at` | date | _(ISO8601)_ | — | ➖ | No ECS equivalent |
| `kolide.device.will_block_at` | date | _(ISO8601)_ | — | ➖ | No ECS equivalent |
| `kolide.device.hardware_model` | keyword | `Example Laptop Model`, `Example Phone` | — | ➖ | No ECS hardware-model field |
| `kolide.device.serial` | keyword | `SN000000000001`, `null` | — | ➖ | No ECS serial-number field |
| `kolide.device.hardware_uuid` | keyword | _(UUID)_ | `host.id` | 🔄 | `host.id` already set from Kolide device ID; `hardware_uuid` can supplement |
| `kolide.device.note` | text | _(free text)_ | — | ➖ | No ECS equivalent |
| `kolide.device.auth_state` | keyword | `Good`, `Blocked` | — | ➖ | Raw API auth-state; no ECS equivalent |
| `kolide.device.product_image_url` | keyword | _(URL)_ | — | ➖ | Vendor UI metadata |
| `kolide.device.form_factor` | keyword | `computer`, `phone` | — | ➖ | No ECS equivalent |
| `kolide.device.registered_owner_info.identifier` | keyword | _(person identifier)_ | `user.id` | 🔄 | Owner of the device |
| `kolide.device.registered_owner_info.location` | keyword | _(API URL)_ | — | ➖ | Internal API reference URL |
| `kolide.device.auth_configuration.device_id` | keyword | _(device ID)_ | `host.id` | ✅ | Already set from the Kolide device record |
| `kolide.device.auth_configuration.authentication_mode` | keyword | `only_registered_owner`, `any_registered_person` | — | ➖ | No ECS equivalent |
| `kolide.device.auth_configuration.person_groups` | flattened | _(object)_ | — | ➖ | No ECS equivalent |

---

## `issues` data stream

ECS fields already set by `default.yml`: `@timestamp`, `event.id`, `event.action`,
`event.kind` (`event`), `event.category` (`configuration`), `event.type`
(`creation` / `change`), `event.start`, `event.end`, `host.name`, `host.hostname`,
`host.id`, `rule.name`, `rule.id`, `message` (= issue title), `user.name`,
`file.path`, `file.hash.md5`, `file.hash.sha256`, `related.hosts`, `related.user`.

ECS fields set by `extended-mappings.yml`: `file.device`.

| Custom Field | Type | Example Values | ECS Field | Status | Notes |
|---|---|---|---|---|---|
| `kolide.issues.id` | keyword | `455148606` | — | ➖ | `event.id` is the ULID of the event; `kolide.issues.id` is the issue record ID |
| `kolide.issues.title` | keyword | `Disk Is Not Encrypted`, `Chrome Browser Is Not Up to Date` | `message` | ✅ | Copied to `message` |
| `kolide.issues.issue_key` | keyword | `path`, `check_target`, `pk` | — | ➖ | Identifies the failing attribute type |
| `kolide.issues.issue_value` | keyword | `/home/example-user/.ssh/id_ed25519`, `/` | — | ➖ | Value of the failing attribute; context-dependent |
| `kolide.issues.value` | flattened | `{"KOLIDE_CHECK_STATUS":"FAIL","version":"148.0..."}` | — | ➖ | Full check-specific result object |
| `kolide.issues.exempted` | boolean | `true`, `false` | — | ➖ | No ECS exemption concept |
| `kolide.issues.detected_at` | date | _(ISO8601)_ | `event.start` | ✅ | When the issue was first detected |
| `kolide.issues.resolved_at` | date | _(ISO8601)_ | `event.end` | ✅ | When the issue was resolved |
| `kolide.issues.blocks_device_at` | date | _(ISO8601)_ | — | ➖ | No ECS equivalent |
| `kolide.issues.last_rechecked_at` | date | _(ISO8601)_ | — | ➖ | No ECS equivalent |
| `kolide.issues.check.id` | keyword | _(check UUID)_ | `rule.id` | ✅ | Set from webhook `check_id` |
| `kolide.issues.check.tags` | keyword | _(array of tag strings)_ | `rule.category` | 🔄 | ECS `rule.category` is a reasonable match |
| `kolide.issues.device_information.location` | keyword | _(API URL)_ | — | ➖ | Internal API reference URL |
| `kolide.issues.check_information.location` | keyword | _(API URL)_ | — | ➖ | Internal API reference URL |
| `kolide.issues.detected_version` | keyword | `148.0.7778.167-64` | `package.version` | 🔄 | Applies only to software-version checks (Chrome, OS updates) |
| `kolide.issues.expected_version` | keyword | `149.0.7827.114` | — | ➖ | No ECS "required version" field |
| `kolide.issues.ssh_key_type` | keyword | `ssh-ed25519`, `ssh-rsa` | — | ➖ | No ECS key-algorithm field |

---

## Summary of actionable mappings

| Priority | Stream | Custom Field | → ECS Field | Action |
|---|---|---|---|---|
| High | audit | `kolide.audit.target.device_name` | `host.name` | Rewrite dissect patterns; drop vendor field |
| High | audit | `kolide.audit.target.check_name` | `rule.name` | Rewrite dissect patterns; drop vendor field |
| High | audit | `kolide.audit.target.user_email` | `user.target.email` | ✅ Done |
| Medium | auth | `kolide.auth.result` | `event.outcome` | ✅ Done |
| Medium | auth | `kolide.auth.agent_version` | `observer.version` | Add `set` processor |
| Medium | device | `kolide.device.type` | `host.type` | Add `set` processor alongside existing `kolide.device.type` |
| Medium | device | `kolide.device.hardware_uuid` | supplement `host.id` | Set `host.id` from `hardware_uuid` when not already set |
| Medium | device | `kolide.device.registered_owner_info.identifier` | `user.id` | Set `user.id` from owner identifier |
| Low | issues | `kolide.issues.detected_version` | `package.version` | Set for software-version check types only |
| Low | issues | `kolide.issues.check.tags` | `rule.category` | Copy tags array |
| Low | audit | `kolide.audit.target.idp_url` | `url.domain` / `url.full` | Parse value to determine which ECS field fits |
