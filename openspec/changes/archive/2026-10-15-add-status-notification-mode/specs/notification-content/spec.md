# Spec Delta

## Purpose

Let users select the content of Herdr notifications while retaining existing output-based messages and offering a status-only option that does not read terminal content.

## ADDED Requirements

### Requirement: Notification body mode selection

The plugin SHALL accept the case-sensitive values `output` and `status` for `NTFY_BODY_MODE`, using the existing configuration loading precedence. An unset or empty value SHALL select `output`.

#### Scenario: Existing configuration without a mode

- **WHEN** a notification is triggered and `NTFY_BODY_MODE` is unset or empty
- **THEN** the plugin uses the existing pane-output body behavior, including its existing empty-output fallback

#### Scenario: Explicit output mode

- **WHEN** a notification is triggered with `NTFY_BODY_MODE=output`
- **THEN** the plugin uses the same body behavior as the default mode and honors `NTFY_LINES`

### Requirement: Status-only notification body

For an eligible event in `status` mode, the body SHALL contain only `Status: <semantic-status>` and `Pane: <pane-id>` on separate lines. The status SHALL be `done`, `blocked`, or `idle` as reported by Herdr. A missing pane identifier SHALL be rendered as `unknown`. Workspace and tab SHALL remain in the existing title.

#### Scenario: Agent needs attention

- **WHEN** pane `w1:p2` enters `blocked` with `NTFY_BODY_MODE=status`
- **THEN** the body is exactly `Status: blocked` followed by a newline and `Pane: w1:p2`
- **AND** the title keeps the existing blocked emoji, workspace, tab, and configured title

#### Scenario: Work completes

- **WHEN** an eligible `done` event or `working` to `idle` transition occurs in `status` mode
- **THEN** the body contains the corresponding `done` or `idle` status and the source pane identifier

#### Scenario: Pane identifier is unavailable

- **WHEN** an eligible event in `status` mode has no pane identifier in its existing event/context/environment sources
- **THEN** the body uses `Pane: unknown` without requesting terminal output

### Requirement: Status mode content boundary

In `status` mode, the plugin MUST NOT read pane output or include free-form event/context messages in the notification body. `NTFY_LINES` SHALL have no effect on status-mode event delivery or its dry-run validation.

#### Scenario: Terminal and event contain private content

- **WHEN** an eligible status-mode event includes free-form messages and the pane has terminal output available
- **THEN** no pane-read command is invoked and none of that output or message text appears in the body

#### Scenario: Output line setting is irrelevant

- **WHEN** `NTFY_BODY_MODE=status` and `NTFY_LINES` is zero or nonnumeric
- **THEN** an otherwise valid event notification or dry-run succeeds without using or rejecting the line setting

### Requirement: Unsupported mode handling

The plugin SHALL reject any nonempty `NTFY_BODY_MODE` other than `output` or `status` with a nonzero exit status and a diagnostic naming the allowed modes. It MUST NOT read pane output or publish a notification in that invocation.

#### Scenario: Invalid mode on an event

- **WHEN** the event hook receives `NTFY_BODY_MODE=statuz`
- **THEN** it exits nonzero with an allowed-mode diagnostic and invokes neither pane reading nor HTTP publication

#### Scenario: Invalid mode on an action

- **WHEN** dry-run or test is invoked with an unsupported mode
- **THEN** it exits nonzero with an allowed-mode diagnostic and sends no notification

### Requirement: Mode-aware diagnostic actions

Dry-run SHALL report the effective body mode and show a synthetic status-only body in `status` mode without sending a notification. It SHALL retain positive-integer `NTFY_LINES` validation in `output` mode. The test action SHALL report the mode and retain its existing synthetic test payload without reading pane content.

#### Scenario: Status-mode dry-run preview

- **WHEN** dry-run receives a valid status-mode configuration
- **THEN** it reports `NTFY_BODY_MODE: status` and previews `Status: done` and `Pane: wE:p1` without pane reads or HTTP publication

#### Scenario: Output-mode line validation

- **WHEN** dry-run uses default or explicit output mode with zero or nonnumeric `NTFY_LINES`
- **THEN** it fails with the existing positive-integer diagnostic

#### Scenario: Synthetic test notification

- **WHEN** the test action runs with valid configuration in either supported mode
- **THEN** it reports the effective mode and publishes the existing generic test notification without pane reads or a Collie click action

### Requirement: Existing delivery behavior remains compatible

Body selection SHALL preserve event eligibility, existing title formatting, bearer-token authentication, and optional Collie click URLs. The plugin SHALL continue notifying on `done`, `blocked`, and `working` to `idle`, while suppressing unrelated `idle` events and other states.

#### Scenario: Event transition filtering

- **WHEN** the same state sequence is processed in output and status modes
- **THEN** the modes publish the same number of notifications for the same eligible transitions

#### Scenario: Authentication and pane link

- **WHEN** an eligible status-mode event has `NTFY_TOKEN` and `COLLIE_URL` configured
- **THEN** the notification includes the existing bearer-token header and source-pane Click URL alongside the status-only body

## Traceability

- Jira: None
- Source: User request in this conversation for the `artmen1516/herdr-ntfy` fork, captured in this change's proposal.
- Reason: Support status and location notifications without copying terminal output while preserving the existing default behavior.
