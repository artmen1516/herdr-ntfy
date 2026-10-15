# Design

## Context

See [proposal.md](proposal.md) for motivation and scope. `notify.sh` loads the plugin-config `.env` (falling back to the plugin-root `.env`), filters events using remembered pane status, constructs the existing title, and reads recent pane output. An empty read falls back to event/context message text and then status. Dry-run and test are separate entry points that also load configuration.

The test suite substitutes `herdr` and `curl` through `PATH`, but inherits `HERDR_BIN_PATH`, which can bypass its Herdr substitute inside a live session. The content boundary and test isolation therefore need explicit verification.

## Goals / Non-Goals

**Goals:** Keep one authoritative mode resolver, isolate status-only formatting from output collection, and prove that status-mode execution cannot reach a pane read or free-form message fallback.

**Non-Goals:** No new runtime dependencies, lifecycle-state algorithm changes, plugin identity changes, or changes to configuration precedence. Scope otherwise follows the proposal.

## Decisions

### 1. Resolve and validate the mode after loading configuration

Use a shared POSIX-shell resolver with `${NTFY_BODY_MODE:-output}` and exact `output|status` matching. Call it after `load_env` in the event, dry-run, and test paths. An unsupported value produces a nonzero exit and a diagnostic listing the accepted values before state processing, pane reads, or HTTP publication. Do not print credentials or config file contents.

Defaulting unknown values to output was rejected because a typo could cause terminal content to be published unexpectedly. Unset and empty values still select output for compatibility.

### 2. Branch before collecting output

Retain the existing event filter and title construction. Only the output branch may call `herdr pane read` or use the current event/context message fallbacks. The status branch formats exactly two English lines: `Status: <status>` and `Pane: <pane-id>`, substituting `unknown` for a missing pane ID. Use the already-resolved, single-line pane identifier; normalize control whitespace with the existing label-cleaning behavior before inserting it. Preserve Herdr's actual status, including `idle` on an eligible working-to-idle transition.

Routing status mode through an empty-output fallback was rejected: that path already accepts arbitrary message text and would weaken the content boundary. Retain authentication, title formatting, and Collie URL construction outside the content branch.

### 3. Keep diagnostic actions synthetic

Dry-run reports the effective mode and, for status, previews `Status: done` and `Pane: wE:p1`. It skips `NTFY_LINES` validation in status mode and explains that the setting is unused; output mode retains its existing positive-integer check and current synthetic preview. Neither mode reads a real pane during dry-run.

The test action validates and reports the mode but retains its generic synthetic payload and absent Click action. Replacing it with a real pane read was rejected because an installation test should remain independent of terminal content. Do not broaden existing test-action line validation in this change.

### 4. Prove the boundary with local substitutes

Explicitly set the test subprocess's `HERDR_BIN_PATH` to `tests/bin/herdr`, rather than relying only on `PATH`. Let that substitute record read invocations in a temporary file. Use sentinel terminal output and event/context messages to verify the status body contains none of them and records zero reads. Keep all calls to the existing local curl substitute; use temporary configuration/state directories.

Cover default/empty/explicit output, all eligible status events, ignored states, missing pane identifiers, irrelevant status-mode line settings, invalid modes in all entry points, dry-run previews, generic test payloads, authentication, and encoded Collie URLs. Existing transition assertions remain regression coverage. Update both README variants and `.env.example`, leaving output as the documented default.

## Risks / Trade-offs

- [An output fallback leaks message text] -> Separate the body branches and assert no pane reads or sentinel content in status mode.
- [Tests call the live Herdr binary] -> Override `HERDR_BIN_PATH` inside the test harness and verify with an inherited sentinel executable path.
- [Users expect status-only to hide all metadata] -> Document that workspace/tab labels, pane IDs, and optional Collie links remain visible.
- [Existing state tracking has session/concurrency limitations] -> Preserve that algorithm; broader event tracking is outside this change.

## Migration Plan

No configuration migration is required: unset, empty, and explicit output retain current behavior. After implementation is reviewed, users can opt in by adding `NTFY_BODY_MODE=status` to the plugin-config `.env`; reverting to `output` restores terminal-output notifications. Installation, real topic selection, and delivery testing are separate follow-up work.

## Verification

Run `sh tests/notify_test.sh` with the test harness override and `env HERDR_BIN_PATH=/nonexistent/herdr sh tests/notify_test.sh` to prove isolation. Run `sh -n` on every changed shell file. Validate the OpenSpec change with `openspec validate add-status-notification-mode --strict` and review that all actual deliveries were simulated.

## Traceability

- Jira: None
- Source: User request in this conversation to extend the personal `artmen1516/herdr-ntfy` fork, as recorded in [proposal.md](proposal.md).
- Reason: Provide status and location alerts without copying terminal output, preserving existing defaults.
