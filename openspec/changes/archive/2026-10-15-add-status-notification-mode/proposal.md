# Proposal

## Why

The plugin currently copies recent terminal output into every agent notification. Users who want only a completion or attention alert need a configurable alternative that keeps terminal content out of ntfy and remains useful on an iPhone or Apple Watch.

## What Changes

- Add `NTFY_BODY_MODE=output|status`; unset or empty values retain the current `output` behavior.
- In `status` mode, send only the semantic status and pane identifier in the body, keeping workspace and tab in the existing title. Never read pane output or use free-form event/context messages in this mode.
- Reject unsupported modes without reading terminal output or publishing a notification.
- Make dry-run report and preview the selected mode, and validate it in both dry-run and test actions. `NTFY_LINES` applies only to `output` mode.
- Add isolated regression tests and document the option in `.env.example` and both README variants.

## Goals

- Offer a minimal notification body without changing existing defaults or runtime dependencies.
- Preserve the existing event-selection rules, authentication, and optional Collie click-through behavior.

## Non-goals

- Install or activate the plugin, configure a real topic/token, or send real notifications.
- Deploy ntfy, build a Watch app, add localization, change priorities, or redesign event tracking, retries, and deduplication.

## Capabilities

### New Capabilities

- `notification-content`: Select output or status-only notification bodies, enforce content boundaries, and expose mode-aware configuration diagnostics.

### Modified Capabilities

None. The project has no existing durable capability specifications.

## Impact

- Implementation: `notify.sh` configuration validation, body construction, dry-run, and test diagnostics.
- Documentation: `.env.example`, `README.md`, and `README-ja.md`.
- Verification: shell tests and local Herdr/curl substitutes; no live Herdr session or network delivery is required.
- Compatibility: existing titles, hooks, actions, token support, and Collie links remain unchanged. No new dependencies.
- Risks: a status-only implementation could accidentally retain an output/message fallback; tests must assert both the lack of pane reads and the absence of free-form content. Workspace/tab labels and pane identifiers remain visible notification metadata.

## Traceability

- Jira: None
- Source: User request in this conversation to extend the personal `artmen1516/herdr-ntfy` fork with the previously agreed `NTFY_BODY_MODE=status` option.
- Reason: Provide status and location alerts through ntfy without copying terminal output, while preserving upstream defaults.
