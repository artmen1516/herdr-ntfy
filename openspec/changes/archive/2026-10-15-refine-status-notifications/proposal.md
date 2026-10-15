# Proposal

## Why

An opaque pane identifier does not identify which project or agent needs attention on iPhone or Apple Watch. The user has reviewed the implemented compact status layout and requested that it be closed independently of the still-pending remote approval work.

## What Changes

- Replace visible tab/pane labels in status notifications with workspace and responding agent in the title, and `Status` followed by an optional source-checkout `Branch` in the body.
- Resolve metadata against the event's source pane, independently of UI focus, with bounded metadata-only lookups and explicit fallbacks.
- Update synthetic diagnostics, regression fixtures, configuration examples, and both README variants for the compact layout.
- Extract the four completed status tasks from `add-contextual-approval-notifications`. This change records their existing implementation; the original change retains all fifteen pending approval tasks.

## Goals

- Identify the source workspace and agent on a small screen without duplicated identity fields.
- Preserve the no-terminal-output guarantee, output-mode behavior, notification eligibility, authentication, and pane-targeted Collie links.
- Synchronize and close the completed status scope independently of approval feasibility.

## Non-goals

- Adding an approval mode, questions, decision buttons, a bridge, or a native approval adapter.
- Deploying components, changing live configuration, sending device tests, or approving agent work.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `notification-content`: Compact status title/body, verified source metadata, optional branch, and inert diagnostics. Other mode selection and content boundaries remain as specified in the canonical capability.

## Impact

- Existing implementation: `notify.sh`, `tests/notify_test.sh`, `tests/bin/herdr`, and `tests/bin/git`.
- Existing user documentation: `.env.example`, `README.md`, and `README-ja.md`.
- Required runtime dependencies remain POSIX `sh`, `curl`, and `jq`; Git is optional for branch metadata.
- Baseline: the canonical `notification-content` specification synchronized from `add-status-notification-mode`. Preserve that predecessor's history and unrelated requirements.
- Risks: focused metadata could misidentify a background event; inherited Git routing could select another checkout; metadata failures could delay delivery. Verify source identity, isolate Git routing, bound calls, and omit unavailable data without a terminal-content fallback.

## Traceability

- Jira: None
- Source: User conversation approving workspace/agent in the title, status/optional branch in the body, and subsequent separation and closure of this completed scope.
- Reason: Deliver the reviewed metadata-only improvement independently while preserving all pending requirements in `add-contextual-approval-notifications`.
