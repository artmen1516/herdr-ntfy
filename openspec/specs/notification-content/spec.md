# Notification Content

## Purpose

Let users select the content of Herdr notifications while retaining existing output-based messages and offering a status-only option that does not read terminal content.

## Requirements

### Requirement: Notification body mode selection

The plugin SHALL accept the case-sensitive values `output` and `status` for `NTFY_BODY_MODE`, using the existing configuration loading precedence. An unset or empty value SHALL select `output`.

#### Scenario: Existing configuration without a mode

- **WHEN** a notification is triggered and `NTFY_BODY_MODE` is unset or empty
- **THEN** the plugin uses the existing pane-output body behavior, including its existing empty-output fallback

#### Scenario: Explicit output mode

- **WHEN** a notification is triggered with `NTFY_BODY_MODE=output`
- **THEN** the plugin uses the same body behavior as the default mode and honors `NTFY_LINES`

### Requirement: Status-only notification body

For an eligible status event, the body SHALL contain `Status`, followed by `Branch` only when resolved. Status SHALL be `done`, `blocked`, or eligible `idle`. The title SHALL contain the status emoji, source workspace, source agent, and configured title, with ` · ` between workspace and agent. Workspace and agent SHALL appear only in the title. Tab and pane identifiers MUST NOT appear in the status title or body; the optional Collie link SHALL still target the source pane.

#### Scenario: Agent needs attention

- **WHEN** a source event identifies agent `Codex` in workspace `project`, entering `blocked`, and its checkout branch is `feature/example`
- **THEN** the body is exactly `Status: blocked` and `Branch: feature/example` on separate lines, without agent or workspace fields
- **AND** the title is `🚫 project · Codex (Herdr)` when the configured title is `Herdr`

#### Scenario: Work completes

- **WHEN** an eligible `done` event or `working` to `idle` transition occurs in status mode
- **THEN** the body contains only the corresponding `done` or `idle` status and optional branch, with source workspace and agent in the title

#### Scenario: Pane identifier is unavailable

- **WHEN** an eligible status event has no pane identifier in the existing event/context/environment sources
- **THEN** explicitly supplied source event agent/workspace metadata is retained in the title, unavailable agent/workspace values use `unknown`, and no pane lookup, Git read, or terminal read occurs

#### Scenario: Location labels are unavailable

- **WHEN** verified location names are unavailable but source IDs are known
- **THEN** the title uses the workspace's source ID, or `unknown` if the identity is also unavailable

#### Scenario: Agent metadata is missing or changes after the event

- **WHEN** agent identity is resolved for a source event
- **THEN** it prefers source event `display_agent`, then `agent`, then matching context's agent, then verified source-pane display agent or agent, then `unknown`
- **AND** source event identity wins over later metadata, without inspecting terminal titles, messages, or terminal output

#### Scenario: Branch is unavailable

- **WHEN** Git is missing, the source cwd is unavailable or not absolute, the checkout has detached HEAD, or a metadata/Git lookup fails or times out
- **THEN** the body contains exactly one line, `Status: <actual-status>`, and omits `Branch` without guessing from tab labels, plugin cwd, terminal text, or unrelated focused metadata

#### Scenario: Labels contain control whitespace

- **WHEN** source labels contain line breaks, carriage returns, or tabs
- **THEN** each label is normalized to a single line and cannot add body fields or HTTP headers

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

Dry-run SHALL report and synthetically preview the selected mode without sending a notification or collecting live content. In status mode it SHALL preview a workspace/agent title and status/branch body without duplicated identity fields. It SHALL retain positive-integer line validation only in output mode. Test SHALL report the mode and retain its generic synthetic payload, with no pane read or Collie action.

#### Scenario: Status-mode dry-run preview

- **WHEN** dry-run receives a valid status configuration
- **THEN** it reports `NTFY_BODY_MODE: status`, previews title `✅ verification · Codex (Herdr)` and body `Status: done` plus `Branch: feature/example`, and performs no live metadata/Git/content reads or HTTP publication

#### Scenario: Output-mode line validation

- **WHEN** dry-run uses default or explicit output mode with zero or nonnumeric `NTFY_LINES`
- **THEN** it fails with the existing positive-integer diagnostic

#### Scenario: Synthetic test notification

- **WHEN** test runs with valid configuration in either supported mode
- **THEN** it reports the effective mode and publishes the existing generic test notification without live metadata/Git/content reads or Collie links

### Requirement: Existing delivery behavior remains compatible

Body selection SHALL preserve event eligibility, output-mode title formatting, bearer-token authentication, and optional Collie click URLs. Status-mode titles SHALL follow the contextual status requirement. The plugin SHALL continue notifying on `done`, `blocked`, and `working` to `idle`, while suppressing unrelated `idle` events and other states.

#### Scenario: Event transition filtering

- **WHEN** the same state sequence is processed in output and status modes
- **THEN** the modes publish the same number of notifications for the same eligible transitions

#### Scenario: Authentication and pane link

- **WHEN** an eligible status-mode event has `NTFY_TOKEN` and `COLLIE_URL` configured
- **THEN** the notification includes the existing bearer-token header and source-pane Click URL alongside the status-only body

#### Scenario: Output title compatibility

- **WHEN** an eligible event uses default or explicit output mode
- **THEN** its title retains the existing emoji, workspace, tab, and configured title formatting

### Requirement: Notification source location

Status notifications SHALL identify the source pane's workspace and agent independently of UI focus. Unrelated focused metadata MUST NOT be used. Missing context SHALL permit metadata-only lookups for the explicit source pane. Unavailable workspace names SHALL fall back to the known source ID or `unknown`, without terminal reads. Each Herdr/Git call SHALL be bounded to one second, at most three calls total.

#### Scenario: Event comes from a background pane

- **WHEN** pane `w1:p2` emits an event while focus is on another workspace or tab
- **THEN** status notifications use workspace/agent metadata verified for `w1:p2`, never unrelated focused labels, agents, or cwd

#### Scenario: Metadata cannot be resolved

- **WHEN** metadata lookup fails or the source pane has disappeared
- **THEN** the plugin sends eligible contextual status content using the known workspace ID or `unknown`, retains any source event agent identity, omits the branch, and invokes no output-reading fallback

### Requirement: Optional source branch metadata

An optional branch SHALL come only from Git's current symbolic branch in the verified source pane's absolute `foreground_cwd`, otherwise its `cwd` when foreground cwd is absent. The lookup SHALL ignore inherited Git routing variables, leave the repository unchanged, and send no terminal input. Missing Git, invalid/missing cwd, detached HEAD, and failed lookups SHALL omit the branch. Git SHALL remain optional for status/output modes.

#### Scenario: Branch lookup is source-bound

- **WHEN** the source pane and plugin run in different repositories, including when inherited Git directory variables point elsewhere
- **THEN** the notification uses only the source pane checkout's symbolic branch
- **AND** optional Git availability does not change output/status installation requirements
