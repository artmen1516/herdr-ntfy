# Design

## Context

See [proposal.md](proposal.md) for the user-approved scope. This document records the completed status implementation extracted from group 1 of `add-contextual-approval-notifications`; its approval groups remain pending in that change. The canonical predecessor offered metadata-only status but displayed opaque pane IDs and workspace/tab titles. An event's source pane can differ from UI focus.

## Goals / Non-Goals

**Goals:** Identify the source workspace and agent with compact presentation, bounded read-only metadata access, and no required dependency beyond the existing shell runtime.

**Non-Goals:** Question extraction, remote control, approval adapters, bridge infrastructure, live delivery changes, or a claim of verified Watch action buttons.

## Decisions

### 1. Put identity in the title and state in the body

Render the approved example:

```text
Title: 🚫 project · Codex (Herdr)

Status: blocked
Branch: feature/example
```

Workspace and agent appear only in the title to keep the body compact. Use semantic `idle` for eligible working-to-idle transitions. Omit an unavailable branch. Keep pane identity in the optional Collie link. Preserve output-mode titles. Normalize control whitespace with the existing label-cleaning convention; workspace falls back to a known source ID and then `unknown`, and agent falls back to `unknown`. The earlier tab/pane presentation was rejected because tabs may contain files or unrelated terminals.

### 2. Bind metadata to the event source

Prefer source event `display_agent`, then `agent`, then matching context's `focused_pane_agent`, then verified source-pane display agent/agent. Never infer an agent from terminal titles, tab labels, messages, session paths, or rendered output. Context bound to a different pane, workspace, or tab is not authoritative. Require matching pane bindings before accepting focused context.

Read metadata with explicit-source `pane.get`, validating returned pane and known location IDs. Use a verified workspace ID for optional `workspace.get` when its label is missing. Treat IDs as opaque. When no pane ID is available, preserve explicit event metadata and skip pane/Git reads. Do not change focus or request rendered content.

### 3. Keep branch metadata optional and source-bound

The inspected Herdr schema has no typed branch field. With optional Git available, use `git -C <verified-source-cwd> symbolic-ref --quiet --short HEAD`. Use absolute `foreground_cwd`, otherwise `cwd` only when foreground cwd is absent/blank. A supplied invalid foreground path does not authorize guessing a different source path.

Clear inherited `GIT_DIR`, `GIT_WORK_TREE`, `GIT_COMMON_DIR`, `GIT_INDEX_FILE`, `GIT_NAMESPACE`, `GIT_OBJECT_DIRECTORY`, `GIT_ALTERNATE_OBJECT_DIRECTORIES`, and `GIT_CEILING_DIRECTORIES` for this lookup. Never fall back to the plugin checkout, focused context cwd, workspace paths, or terminal text. Missing Git/cwd, nonrepositories, detached HEAD, failures, and timeouts omit the branch. No terminal input, repository writes, or new required runtime is introduced.

### 4. Bound metadata access and keep diagnostics inert

A POSIX shell watchdog and private temporary output bound each read-only call to one second, at most three calls: `pane.get`, optional `workspace.get`, optional Git. This avoids an additional timeout package. Metadata failure retains source identity fallbacks and cannot trigger a terminal read.

Status dry-run previews a synthetic workspace/agent title and status/branch body. Dry-run and generic test collect no live metadata/Git/content; only test sends its existing synthetic payload. Status ignores `NTFY_LINES`. Existing eligibility, authentication, fallback messages in output mode, and pane-targeted Collie links remain compatible.

## Risks / Trade-offs

- [Focused context belongs to another event source] -> Validate bindings and use explicit-source metadata; prefer event agent identity over later metadata.
- [Inherited Git variables select another checkout] -> Isolate routing variables and use only verified absolute pane cwd.
- [Metadata processes stall delivery] -> Bound each call and degrade to known identity/status without branch.
- [Agent/workspace names are unavailable] -> Show source workspace ID or `unknown`; do not inspect free-form content.
- [Small screens truncate long metadata] -> Keep identity in the title and the body limited to state and optional branch; no claim that every label always fits.

## Verification

The completed implementation passed the normal shell suite, the inherited `HERDR_BIN_PATH=/nonexistent/herdr` suite, syntax checks for all five shell files, exact README fixture checks, and strict OpenSpec validation before this scope split. Local substitutes cover background events, mismatched context/IDs, precedence/fallbacks, metadata/Git failures and timeouts, normalization, and zero terminal reads. Isolated real Git fixtures verify source selection despite inherited routing, detached HEAD, and nonrepository fallback. These checks send no real notifications or agent input.

The split changes planning artifacts only; compare runtime, tests, configuration examples, and README hashes with the pre-split snapshot before final review. Run final specification verification and technical review after synchronization. This record is not itself a final review verdict or native approval evidence.

## Migration Plan

The user has already reviewed the implemented layout. Synchronize this delta into the canonical capability, review that exact boundary, and archive this status change. Preserve all fifteen pending approval tasks in the original active change, which now builds on the contextual status baseline. No deployment or live configuration change is part of this closure.

Runtime rollback can select existing `output` mode or restore the predecessor implementation through a separately scoped change; no configuration/data migration is required. Reversing the OpenSpec split must preserve both task sets and predecessor history.

## Traceability

- Jira: None
- Source: User-approved compact status refinement and subsequent scope separation; see [proposal.md](proposal.md).
- Reason: Close completed metadata-only work independently of the optional remote approval design.
