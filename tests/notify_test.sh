#!/bin/sh
set -eu

# Keep fixture setup independent of inherited routing/configuration.
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_NAMESPACE
unset GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CEILING_DIRECTORIES
unset GIT_CONFIG GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM

calls="$test_dir/calls"
reads="$test_dir/reads"
metadata_calls="$test_dir/metadata-calls"
git_calls="$test_dir/git-calls"
real_git="$(command -v git)"
body="$test_dir/body"
stdout="$test_dir/stdout"
stderr="$test_dir/stderr"
case_number=0

fail() {
  echo "$*" >&2
  exit 1
}

reset_case() {
  case_number=$((case_number + 1))
  config_dir="$test_dir/config-$case_number"
  pane_id="w1:p2"
  event_json=''
  context_json='{"focused_pane_id":"w1:p2","workspace_id":"w1","tab_id":"w1:t1","workspace_label":"workspace","tab_label":"tab","focused_pane_agent":"Codex","message":"Context message sentinel."}'
  metadata_mode=ok
  git_mode=ok
  git_branch=feature/example
  pane_json='{"result":{"type":"pane_info","pane":{"pane_id":"w1:p2","workspace_id":"w1","tab_id":"w1:t1","agent":"codex","display_agent":"Codex"}}}'
  workspace_json='{"result":{"type":"workspace_info","workspace":{"workspace_id":"w1","label":"lookup-workspace"}}}'
  unset NTFY_BODY_MODE NTFY_TEST_OUTPUT NTFY_LINES
  NTFY_TOKEN=''
  COLLIE_URL=''
  : >"$calls"
  : >"$reads"
  : >"$metadata_calls"
  : >"$git_calls"
  : >"$body"
}

assert_count() {
  actual="$(wc -l <"$1" | tr -d ' ')"
  [ "$actual" = "$2" ] || fail "expected $2 call(s) in $1, got $actual"
}

assert_contains() {
  case "$(cat "$1")" in
    *"$2"*) ;;
    *) fail "expected '$2' in $1" ;;
  esac
}

assert_absent() {
  if grep -Fq -- "$2" "$1"; then
    fail "unexpected '$2' in $1"
  fi
}

assert_body() {
  actual_body="$(cat "$body")"
  [ "$actual_body" = "$1" ] || fail "unexpected notification body: $actual_body"
}

assert_status() {
  expected="$(printf 'Status: %s' "$1")"
  if [ -n "${4:-}" ]; then expected="$(printf '%s\nBranch: %s' "$expected" "$4")"; fi
  assert_body "$expected"
  assert_absent "$body" 'Pane:'
  assert_absent "$body" 'Tab:'
  assert_absent "$body" 'Agent:'
  assert_absent "$body" 'Workspace:'
  case "$1" in blocked) expected_emoji='🚫' ;; *) expected_emoji='✅' ;; esac
  expected_title="$expected_emoji ${2-workspace} · ${3-Codex} (Herdr)"
  case "$(tail -n 1 "$calls")" in
    *"Title: $expected_title -H Content-Type:"*) ;;
    *) fail "unexpected status title; expected $expected_title" ;;
  esac
}

run_notify() (
  # Isolate user configuration, live Herdr context, and network delivery.
  export HERDR_PLUGIN_ROOT="$test_dir"
  export HERDR_PLUGIN_CONFIG_DIR="$config_dir"
  export HERDR_BIN_PATH="$root/tests/bin/herdr"
  export HERDR_PLUGIN_EVENT_JSON="$event_json"
  export HERDR_PLUGIN_CONTEXT_JSON="$context_json"
  export HERDR_PANE_ID=''
  export HERDR_WORKSPACE_ID=unrelated-caller-workspace HERDR_TAB_ID=unrelated-caller-tab
  export NTFY_URL='https://ntfy.example/topic'
  export NTFY_TITLE=Herdr
  export NTFY_TOKEN COLLIE_URL
  export NTFY_LINES="${NTFY_LINES-12}"
  if [ "${NTFY_BODY_MODE+x}" = x ]; then export NTFY_BODY_MODE; fi
  if [ "${NTFY_TEST_OUTPUT+x}" = x ]; then export NTFY_TEST_OUTPUT; fi
  export NTFY_TEST_CALLS="$calls" NTFY_TEST_READS="$reads" NTFY_TEST_BODY="$body"
  export NTFY_TEST_METADATA_CALLS="$metadata_calls" NTFY_TEST_METADATA_MODE="$metadata_mode"
  export NTFY_TEST_GIT_CALLS="$git_calls" NTFY_TEST_GIT_MODE="$git_mode"
  export NTFY_TEST_GIT_BRANCH="$git_branch" NTFY_TEST_REAL_GIT="$real_git"
  export NTFY_TEST_PANE_JSON="$pane_json" NTFY_TEST_WORKSPACE_JSON="$workspace_json"
  export PATH="$root/tests/bin:$PATH"
  sh "$root/notify.sh" "$@" >"$stdout" 2>"$stderr"
)

run_event() {
  event_json="$(jq -cn --arg status "$1" --arg pane "$pane_id" \
    '{data:{agent_status:$status,pane_id:$pane,agent:"codex",display_agent:"Codex",message:"Event message sentinel."}}')"
  run_notify
}

for mode in unset empty output status; do
  reset_case
  case "$mode" in
    empty) NTFY_BODY_MODE='' ;;
    output | status) NTFY_BODY_MODE="$mode" ;;
  esac

  run_event idle
  run_event unknown
  run_event working
  assert_count "$calls" 0
  assert_count "$reads" 0
  assert_count "$metadata_calls" 0
  assert_count "$git_calls" 0
  run_event idle
  assert_count "$calls" 1
  if [ "$mode" = status ]; then
    assert_contains "$calls" 'Title: ✅ workspace · Codex (Herdr)'
  else
    assert_contains "$calls" 'Title: ✅ workspace・tab (Herdr)'
  fi
  if [ "$mode" = status ]; then
    assert_status idle
  else
    assert_body 'Agent output from the test pane.'
  fi
  run_event idle
  assert_count "$calls" 1

  run_event working
  run_event done
  assert_count "$calls" 2
  if [ "$mode" = status ]; then
    assert_status done
  fi
  run_event idle
  assert_count "$calls" 2

  run_event blocked
  assert_count "$calls" 3
  if [ "$mode" = status ]; then
    assert_contains "$calls" 'Title: 🚫 workspace · Codex (Herdr)'
  else
    assert_contains "$calls" 'Title: 🚫 workspace・tab (Herdr)'
  fi
  if [ "$mode" = status ]; then
    assert_status blocked
    assert_absent "$body" 'sentinel'
    assert_absent "$body" 'Agent output'
  fi
  assert_absent "$calls" 'Click:'

  NTFY_TOKEN='test-token'
  COLLIE_URL='https://collie.example.ts.net'
  run_event working
  run_event done
  assert_count "$calls" 4
  assert_contains "$calls" 'Authorization: Bearer test-token'
  assert_contains "$calls" 'Click: https://collie.example.ts.net/pane/w1%3Ap2'
  assert_count "$git_calls" 0
  if [ "$mode" = status ]; then
    assert_count "$metadata_calls" 4
    assert_count "$reads" 0
  else
    assert_count "$metadata_calls" 0
    assert_count "$reads" 4
    assert_contains "$reads" 'pane read w1:p2 --source recent-unwrapped --lines 12'
  fi
done

# Output mode retains line selection and both free-form message fallbacks.
reset_case
NTFY_BODY_MODE=output
NTFY_LINES=3
run_event done
assert_contains "$reads" '--lines 3'
NTFY_TEST_OUTPUT=''
run_event done
assert_body 'Event message sentinel.'
event_json='{"data":{"agent_status":"done","pane_id":"w1:p2"}}'
run_notify
assert_body 'Context message sentinel.'
context_json='{"workspace_label":"workspace","tab_label":"tab"}'
run_notify
assert_body done

# Status does not use line settings or terminal/message fallbacks.
reset_case
NTFY_BODY_MODE=status
for line_setting in 0 invalid; do
  NTFY_LINES="$line_setting"
  run_event blocked
  assert_status blocked
done
assert_count "$metadata_calls" 2
assert_count "$git_calls" 0
pane_id=''
run_event blocked
assert_status blocked unknown
assert_count "$reads" 0
assert_count "$metadata_calls" 2

# Without a source pane, keep only explicitly supplied event metadata.
reset_case
NTFY_BODY_MODE=status
pane_id=''
event_json='{"data":{"agent_status":"blocked","workspace_id":"w1","workspace_label":"project","agent":"claude"}}'
run_notify
assert_status blocked project claude
assert_count "$reads" 0
assert_count "$metadata_calls" 0
assert_count "$git_calls" 0

# The source pane may come from context when the event omits its identity.
reset_case
NTFY_BODY_MODE=status
pane_id=''
context_json='{"workspace_label":"workspace","tab_label":"files","pane_id":"w2:p3","focused_pane_agent":"Claude"}'
metadata_mode=fail
run_event blocked
assert_status blocked workspace Claude
assert_contains "$metadata_calls" 'pane get w2:p3'
assert_count "$reads" 0

# Background events reject mismatched or unbound context, including its agent
# and cwd, even when the names appear plausible.
for unrelated_context in \
  '{"focused_pane_id":"w9:p9","workspace_id":"w9","tab_id":"w9:t9"}' \
  '{"focused_pane_id":"w1:p2","workspace_id":"w9","tab_id":"w1:t1"}' \
  '{"focused_pane_id":"w1:p2","workspace_id":"w1","tab_id":"w9:t9"}' \
  '{}' \
  '{"pane_id":"w1:p2","focused_pane_id":"w9:p9"}'; do
  reset_case
  NTFY_BODY_MODE=status
  context_json="$(printf '%s' "$unrelated_context" | jq -c '. + {workspace_label:"wrong-workspace",tab_label:"wrong-tab",focused_pane_agent:"wrong-agent",focused_pane_cwd:"/wrong/repo"}')"
  event_json='{"data":{"agent_status":"blocked","pane_id":"w1:p2","workspace_id":"w1","tab_id":"w1:t1"}}'
  run_notify
  assert_status blocked lookup-workspace
  assert_count "$reads" 0
  assert_count "$metadata_calls" 2
  assert_count "$git_calls" 0
  assert_contains "$metadata_calls" 'pane get w1:p2'
  assert_contains "$metadata_calls" 'workspace get w1'
  assert_absent "$metadata_calls" 'tab get'
  assert_contains "$calls" 'Title: 🚫 lookup-workspace · Codex (Herdr)'
  assert_absent "$body" 'wrong-'
  assert_absent "$calls" 'wrong-'
done

# README fixture: source event agent wins over focus and later pane metadata.
reset_case
NTFY_BODY_MODE=status
context_json='{"focused_pane_id":"w9:p9","workspace_label":"wrong-workspace","focused_pane_agent":"wrong-agent"}'
event_json='{"data":{"agent_status":"blocked","pane_id":"w1:p2","workspace_id":"w1","agent":"codex","display_agent":"Codex","workspace_label":"herdr-ntfy"}}'
pane_json='{"result":{"pane":{"pane_id":"w1:p2","workspace_id":"w1","tab_id":"w1:t1","agent":"claude","foreground_cwd":"/source/repo"}}}'
run_notify
assert_status blocked herdr-ntfy Codex feature/example
assert_contains "$calls" 'Title: 🚫 herdr-ntfy · Codex (Herdr)'
assert_count "$metadata_calls" 1
assert_count "$git_calls" 1
assert_contains "$git_calls" '-C /source/repo symbolic-ref --quiet --short HEAD'
assert_count "$reads" 0

# Agent precedence: event display name, event kind, matching focused agent,
# verified pane display/kind, then unknown. Never inspect terminal titles.
for agent_case in event-display event-kind context pane-display pane-kind unknown; do
  reset_case
  NTFY_BODY_MODE=status
  context_json='{"focused_pane_id":"w1:p2","workspace_label":"project","focused_pane_agent":"ContextAgent"}'
  event_json='{"data":{"agent_status":"done","pane_id":"w1:p2"}}'
  expected_agent=ContextAgent
  case "$agent_case" in
    event-display)
      event_json='{"data":{"agent_status":"done","pane_id":"w1:p2","agent":"codex","display_agent":"Reviewer"}}'
      expected_agent=Reviewer ;;
    event-kind)
      event_json='{"data":{"agent_status":"done","pane_id":"w1:p2","agent":"claude","display_agent":" \n\t"}}'
      expected_agent=claude ;;
    pane-display | pane-kind | unknown)
      context_json='{"focused_pane_id":"w1:p2","workspace_label":"project"}'
      case "$agent_case" in
        pane-display) expected_agent=Codex ;;
        pane-kind)
          pane_json='{"result":{"pane":{"pane_id":"w1:p2","workspace_id":"w1","tab_id":"w1:t1","agent":"gemini"}}}'
          expected_agent=gemini ;;
        unknown)
          pane_json='{"result":{"pane":{"pane_id":"w1:p2","workspace_id":"w1","tab_id":"w1:t1","title":"Private title sentinel","terminal_title":"NotAnAgent","agent":null}}}'
          expected_agent=unknown ;;
      esac ;;
  esac
  run_notify
  assert_status done project "$expected_agent"
  assert_count "$reads" 0
  assert_count "$git_calls" 0
done

# Opaque IDs are resolved from pane metadata, never parsed as topology.
reset_case
NTFY_BODY_MODE=status
pane_id=opaque-pane
context_json='{}'
pane_json='{"result":{"pane":{"pane_id":"opaque-pane","workspace_id":"opaque-workspace","tab_id":"opaque-tab"}}}'
workspace_json='{"result":{"workspace":{"workspace_id":"opaque-workspace","label":"project"}}}'
run_event blocked
assert_status blocked project
assert_count "$metadata_calls" 2
assert_contains "$metadata_calls" 'workspace get opaque-workspace'
assert_count "$reads" 0

# Failed, invalid, or hung metadata preserves the event's source agent/IDs.
for failure in fail invalid timeout; do
  reset_case
  NTFY_BODY_MODE=status
  metadata_mode="$failure"
  context_json='{"focused_pane_id":"w9:p9","workspace_label":"wrong-workspace","focused_pane_agent":"wrong-agent"}'
  event_json='{"data":{"agent_status":"blocked","pane_id":"w1:p2","workspace_id":"w1","agent":"codex","message":"Private event sentinel."}}'
  started="$(date +%s)"
  run_notify
  elapsed=$(( $(date +%s) - started ))
  [ "$elapsed" -lt 5 ] || fail "metadata fallback took $elapsed seconds"
  assert_status blocked w1 codex
  assert_count "$metadata_calls" 1
  assert_count "$git_calls" 0
  assert_count "$reads" 0
  assert_absent "$body" 'sentinel'
  assert_absent "$body" 'wrong-'
done

reset_case
NTFY_BODY_MODE=status
metadata_mode=fail
context_json='{}'
event_json='{"data":{"agent_status":"blocked","pane_id":"w1:p2"}}'
run_notify
assert_status blocked unknown unknown
assert_count "$metadata_calls" 1
assert_count "$reads" 0

# Returned pane/location IDs must match before accepting names or cwd.
for mismatch in pane workspace tab; do
  reset_case
  NTFY_BODY_MODE=status
  context_json='{}'
  event_json='{"data":{"agent_status":"blocked","pane_id":"w1:p2","workspace_id":"w1","tab_id":"w1:t1"}}'
  pane_json="$(printf '%s' "$pane_json" | jq -c --arg field "${mismatch}_id" '.result.pane[$field] = "wrong-id" | .result.pane.foreground_cwd = "/wrong/repo"')"
  run_notify
  assert_status blocked w1 unknown
  assert_count "$metadata_calls" 1
  assert_count "$git_calls" 0
  assert_count "$reads" 0
done
for missing in empty wrong-workspace; do
  reset_case
  NTFY_BODY_MODE=status
  context_json='{}'
  workspace_json='{"result":{"workspace":{"workspace_id":"w1","label":""}}}'
  if [ "$missing" = wrong-workspace ]; then
    workspace_json='{"result":{"workspace":{"workspace_id":"w9","label":"wrong-workspace"}}}'
  fi
  run_event blocked
  assert_status blocked w1
  assert_count "$metadata_calls" 2
  assert_count "$reads" 0
done

# Normalize agent/workspace/branch control whitespace without adding fields.
reset_case
NTFY_BODY_MODE=status
context_json='{"focused_pane_id":"w1:p2","workspace_label":"  project\n one\t\r"}'
event_json='{"data":{"agent_status":"blocked","pane_id":"w1:p2","display_agent":"  Code\nx\t\r"}}'
pane_json="$(printf '%s' "$pane_json" | jq -c '.result.pane.cwd = "/source/repo"')"
git_branch="$(printf ' feature/\n example\t\r ')"
run_notify
assert_status blocked 'project one' 'Code x' 'feature/ example'
assert_contains "$calls" 'Title: 🚫 project one · Code x (Herdr)'
assert_count "$reads" 0

# Only the verified source pane's absolute foreground cwd (otherwise cwd) may
# be used. Context cwd, workspace paths/tokens, and plugin cwd are not fallbacks.
for cwd_case in foreground cwd blank-foreground relative missing nonstring; do
  reset_case
  NTFY_BODY_MODE=status
  context_json='{"focused_pane_id":"w1:p2","workspace_label":"workspace","focused_pane_cwd":"/wrong/context","worktree":{"checkout_path":"/wrong/worktree"}}'
  case "$cwd_case" in
    foreground) fields='{"foreground_cwd":"/source/foreground repo","cwd":"/wrong/shell"}' ;;
    cwd) fields='{"cwd":"/source/repo"}' ;;
    blank-foreground) fields='{"foreground_cwd":" \n\t","cwd":"/source/repo"}' ;;
    relative) fields='{"foreground_cwd":"relative/path","cwd":"/wrong/shell"}' ;;
    missing) fields='{"tokens":{"branch":"wrong-token"}}' ;;
    nonstring) fields='{"foreground_cwd":123,"cwd":{}}' ;;
  esac
  pane_json="$(printf '%s' "$pane_json" | jq -c --argjson fields "$fields" '.result.pane += $fields')"
  run_event done
  case "$cwd_case" in
    foreground | cwd | blank-foreground)
      assert_status done workspace Codex feature/example
      assert_count "$git_calls" 1
      if [ "$cwd_case" = foreground ]; then
        assert_contains "$git_calls" '-C /source/foreground repo symbolic-ref'
      else
        assert_contains "$git_calls" '-C /source/repo symbolic-ref'
      fi ;;
    *) assert_status done; assert_count "$git_calls" 0 ;;
  esac
  assert_count "$reads" 0
done

# Optional Git absence, detached/nonrepository errors, blank output, and timeout
# all omit the branch and preserve normal delivery.
for git_failure in missing detached nonrepository blank timeout; do
  reset_case
  NTFY_BODY_MODE=status
  git_mode="$git_failure"
  pane_json="$(printf '%s' "$pane_json" | jq -c '.result.pane.cwd = "/source/repo"')"
  started="$(date +%s)"
  run_event done
  elapsed=$(( $(date +%s) - started ))
  [ "$elapsed" -lt 5 ] || fail "branch fallback took $elapsed seconds"
  assert_status done
  assert_count "$git_calls" 1
  assert_count "$reads" 0
done

# A real inert Git fixture proves branch selection ignores publisher cwd and
# inherited routing variables. No real repository is changed or inspected.
reset_case
NTFY_BODY_MODE=status
git_mode=real
fixture_repo="$test_dir/source repo"
wrong_repo="$test_dir/wrong repo"
"$real_git" init --template= -q -b source-branch "$fixture_repo"
"$real_git" init --template= -q -b wrong-branch "$wrong_repo"
pane_json="$(printf '%s' "$pane_json" | jq -c --arg cwd "$fixture_repo" '.result.pane.foreground_cwd = $cwd')"
(
  export GIT_DIR="$wrong_repo/.git" GIT_WORK_TREE="$wrong_repo" GIT_COMMON_DIR="$wrong_repo/.git"
  export GIT_INDEX_FILE="$wrong_repo/index" GIT_NAMESPACE=wrong
  export GIT_OBJECT_DIRECTORY="$wrong_repo/objects" GIT_ALTERNATE_OBJECT_DIRECTORIES="$wrong_repo/objects"
  export GIT_CEILING_DIRECTORIES="$fixture_repo"
  run_event blocked
)
assert_status blocked workspace Codex source-branch
assert_count "$git_calls" 1
assert_count "$reads" 0

# Exercise real detached HEAD and nonrepository results, not just substitute
# return codes. The fixture commit is isolated and carries no user identity.
"$real_git" -C "$fixture_repo" -c core.hooksPath=/dev/null -c commit.gpgsign=false -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty -qm fixture
"$real_git" -C "$fixture_repo" checkout -q --detach
run_event done
assert_status done
pane_json="$(printf '%s' "$pane_json" | jq -c --arg cwd "$test_dir" '.result.pane.foreground_cwd = $cwd')"
run_event done
assert_status done
assert_count "$git_calls" 3
assert_count "$reads" 0

# Unsupported values fail closed even for an otherwise ignored event.
for mode in statuz STATUS ' '; do
  reset_case
  NTFY_BODY_MODE="$mode"
  for state in blocked working; do
    if run_event "$state"; then fail 'expected invalid mode to fail'; fi
    assert_contains "$stderr" 'invalid NTFY_BODY_MODE; expected output or status'
    assert_count "$calls" 0
    assert_count "$reads" 0
    assert_count "$metadata_calls" 0
    assert_count "$git_calls" 0
  done
done

# The plugin config directory remains authoritative over the root fallback.
reset_case
printf 'NTFY_BODY_MODE=status\n' >"$test_dir/.env"
run_event blocked
assert_status blocked
assert_count "$reads" 0
mkdir -p "$config_dir"
printf 'NTFY_BODY_MODE=output\n' >"$config_dir/.env"
run_event blocked
assert_body 'Agent output from the test pane.'
assert_count "$reads" 1
# Clear the synthetic root config before subsequent action tests.
: >"$test_dir/.env"

# Diagnostic actions use synthetic content and the same mode validation.
for mode in unset empty output status; do
  reset_case
  case "$mode" in
    empty) NTFY_BODY_MODE='' ;;
    output | status) NTFY_BODY_MODE="$mode" ;;
  esac
  effective_mode="${NTFY_BODY_MODE:-output}"
  run_notify --dry-run
  assert_contains "$stdout" "NTFY_BODY_MODE: $effective_mode"
  assert_contains "$stdout" 'Result: ok'
  assert_count "$calls" 0
  assert_count "$reads" 0
  assert_count "$metadata_calls" 0
  assert_count "$git_calls" 0
  if [ "$mode" = status ]; then
    assert_contains "$stdout" "$(printf 'Sample body:\nStatus: done\nBranch: feature/example')"
    assert_contains "$stdout" 'Sample title:'
    assert_contains "$stdout" '✅ verification · Codex (Herdr)'
    assert_absent "$stdout" 'Agent:'
    assert_absent "$stdout" 'Workspace:'
    assert_contains "$stdout" 'NTFY_LINES: unused (status mode)'
  else
    assert_contains "$stdout" 'Herdr ntfy dry-run: no notification was sent.'
    assert_contains "$stdout" 'NTFY_LINES: 12'
  fi

  COLLIE_URL='https://collie.example.ts.net'
  run_notify --test
  assert_contains "$stdout" "NTFY_BODY_MODE: $effective_mode"
  assert_contains "$stdout" 'Result: sent'
  assert_contains "$body" 'Herdr ntfy test: this notification was sent by the test action.'
  assert_contains "$body" 'Sent at:'
  assert_count "$calls" 1
  assert_count "$reads" 0
  assert_count "$metadata_calls" 0
  assert_count "$git_calls" 0
  assert_absent "$calls" 'Click:'
done

for line_setting in 0 invalid; do
  reset_case
  NTFY_BODY_MODE=status
  NTFY_LINES="$line_setting"
  run_notify --dry-run
  assert_contains "$stdout" 'NTFY_LINES: unused (status mode)'
  assert_contains "$stdout" 'Result: ok'
  assert_count "$calls" 0
  assert_count "$reads" 0
  assert_count "$metadata_calls" 0
  assert_count "$git_calls" 0

  for mode in unset output; do
    unset NTFY_BODY_MODE
    if [ "$mode" = output ]; then NTFY_BODY_MODE=output; fi
    if run_notify --dry-run; then fail 'expected output line validation to fail'; fi
    assert_contains "$stdout" 'NTFY_LINES: invalid; expected a positive integer'
    assert_count "$calls" 0
    assert_count "$reads" 0
    assert_count "$metadata_calls" 0
    assert_count "$git_calls" 0
  done
done

for action in --dry-run --test; do
  reset_case
  NTFY_BODY_MODE=statuz
  if run_notify "$action"; then fail 'expected invalid action mode to fail'; fi
  assert_contains "$stderr" 'invalid NTFY_BODY_MODE; expected output or status'
  assert_count "$calls" 0
  assert_count "$reads" 0
  assert_count "$metadata_calls" 0
  assert_count "$git_calls" 0
done

echo 'notify tests: ok (events, content modes, source agent/workspace/branch, diagnostics, config precedence)'
