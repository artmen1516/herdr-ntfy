# Tasks

## Traceability

- Jira: None
- Source: User request in this conversation for `artmen1516/herdr-ntfy`; see [proposal.md](proposal.md).
- Reason: Provide status and location alerts without copying terminal output while preserving existing defaults. All groups below implement the `notification-content` capability.

## 1. Body selection and regression coverage

- [x] 1.1 Pin the test subprocess's `HERDR_BIN_PATH` to the local Herdr substitute and record pane-read invocations in a temporary file; verify the existing suite passes with `HERDR_BIN_PATH=/nonexistent/herdr` inherited.
- [x] 1.2 Add the shared body-mode resolver and separate status-only formatting from output collection; verify unset, empty, and explicit output keep their existing behavior, while eligible status events produce the exact two-line body, handle a missing pane as `unknown`, never read a pane, and ignore free-form message sentinels and `NTFY_LINES`.
- [x] 1.3 Validate unsupported modes on the event path before output collection or publication; verify a nonzero exit and allowed-mode diagnostic with zero pane reads and zero curl calls. Retain tests for ignored states, completion transitions, title formatting, authentication, and Collie URLs in supported modes.
- [x] 1.4 Document `NTFY_BODY_MODE=output|status`, output as the default, status-only examples, visible metadata, and the mode-specific role of `NTFY_LINES` in `.env.example` and both README variants; verify examples match the implemented event bodies and contain no real topic or token.

## 2. Diagnostic actions and their documentation

- [x] 2.1 Report and validate the selected mode in dry-run, show the synthetic status preview, and skip line-count validation only in status mode; verify no pane read or HTTP publication occurs, invalid modes fail, and output mode retains positive-integer line validation.
- [x] 2.2 Report and validate the mode in the test action while preserving its generic synthetic body and absent Click header; verify both valid modes through the curl substitute and verify invalid modes publish nothing.
- [x] 2.3 Update diagnostic-action examples and explanations in both README variants; verify their output matches the corresponding tests and documents no-send dry-run behavior.

## 3. Integration verification

- [x] 3.1 Run `sh tests/notify_test.sh`, `env HERDR_BIN_PATH=/nonexistent/herdr sh tests/notify_test.sh`, and `sh -n` on changed shell files; verify all tests pass with only local curl/Herdr substitutes and no real notifications.
- [x] 3.2 Run `openspec validate add-status-notification-mode --strict`, verify implementation/spec/design/task consistency, and complete the final technical review; verify the reviewed diff contains only the authorized feature, its regression coverage, documentation, and planning artifacts.
