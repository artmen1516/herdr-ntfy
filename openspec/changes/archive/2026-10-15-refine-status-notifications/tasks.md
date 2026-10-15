# Tasks

## Traceability

- Jira: None
- Source: User-approved compact status refinement and subsequent separation; see [proposal.md](proposal.md).
- Reason: Close the completed `notification-content` status scope while preserving all fifteen pending approval tasks in `add-contextual-approval-notifications`.

## Scope and completion record

These are the four completed tasks extracted from the original change, preserving their identifiers and descriptions. Their completion records existing implementation and verification, not new work performed during the split. See [design.md](design.md) for verification evidence and source/privacy boundaries.

## 1. Readable status location — notification-content

- [x] 1.1 Resolve workspace and agent against the event's explicit source pane, preferring source event agent metadata and accepting only matching context. Resolve an optional branch with bounded Git metadata reads from the verified source pane's absolute foreground cwd or cwd; verify background events, unrelated focus, missing Git, missing/invalid cwd, nonrepository/detached checkout, inherited Git routing variables, metadata failures/timeouts, and zero terminal-output reads.
- [x] 1.2 Render workspace and agent only in the status title, and `Status` followed by optional `Branch` in the body; use workspace-ID/unknown and agent-unknown title fallbacks and no visible tab/pane fields. Verify blocked, done, eligible idle, whitespace normalization, source event precedence, and no duplicate identity fields or free-form content in the body.
- [x] 1.3 Update the synthetic status dry-run title/body preview and keep output defaults/titles, fallback messages, transition filtering, headers, and pane-targeted Collie links compatible; verify diagnostics perform no live metadata/Git/content reads or HTTP requests and regression cases still pass.
- [x] 1.4 Update `.env.example` and both README variants with workspace/agent in the title and status/optional branch in the body, optional Git availability, fallback semantics, and the no-terminal-output guarantee; verify all examples match fixtures and contain no real topic, credential, or captured user content.

## 2. Accepted review remediation — notification-content

- [x] 2.1 [CR-001][MINOR] Correct the introductory title/body summaries in both README variants to distinguish output-mode titles from the status workspace/agent title and status/optional branch body; verify all four bullets against the approved examples and runtime rendering, and run `git diff --check`.

## Verification evidence

On 2026-10-15, after the compact layout refinement, the normal shell suite and inherited `HERDR_BIN_PATH=/nonexistent/herdr` suite passed, along with all five shell syntax checks, exact README fixture checks, strict OpenSpec validation, and whitespace checks. Isolated substitutes and real temporary Git fixtures exercise source identity, branch routing, failure/timeouts, and zero terminal reads. No real notifications or agent decisions were used. The scope split preserves runtime/test/documentation hashes; final post-sync verification and review are separate closure gates.

## Workflow follow-up

CR-001 remediation: the user authorized correction of the four introductory README bullets, synchronization, and archive. Both summaries now match the approved title/body examples and existing runtime; focused documentation checks and `git diff --check` passed. Only the two README files and this task record changed after the previous review; runtime, tests, specs, and pending approval artifacts retain their reviewed hashes.

- Synchronize this delta, obtain a current final technical review, and archive only this completed change, as authorized by the user.
- Keep `add-contextual-approval-notifications` active with all fifteen unchecked tasks; no approval implementation or activation is implied.
- Commit/push/PR are outside this closure request.
