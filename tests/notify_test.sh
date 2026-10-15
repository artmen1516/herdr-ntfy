#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM

calls="$test_dir/calls"
reads="$test_dir/reads"
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
  context_json='{"workspace_label":"workspace","tab_label":"tab","message":"Context message sentinel."}'
  unset NTFY_BODY_MODE NTFY_TEST_OUTPUT NTFY_LINES
  NTFY_TOKEN=''
  COLLIE_URL=''
  : >"$calls"
  : >"$reads"
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

run_notify() (
  # Isolate user configuration, live Herdr context, and network delivery.
  export HERDR_PLUGIN_ROOT="$test_dir"
  export HERDR_PLUGIN_CONFIG_DIR="$config_dir"
  export HERDR_BIN_PATH="$root/tests/bin/herdr"
  export HERDR_PLUGIN_EVENT_JSON="$event_json"
  export HERDR_PLUGIN_CONTEXT_JSON="$context_json"
  export HERDR_PANE_ID=''
  export NTFY_URL='https://ntfy.example/topic'
  export NTFY_TITLE=Herdr
  export NTFY_TOKEN COLLIE_URL
  export NTFY_LINES="${NTFY_LINES-12}"
  if [ "${NTFY_BODY_MODE+x}" = x ]; then export NTFY_BODY_MODE; fi
  if [ "${NTFY_TEST_OUTPUT+x}" = x ]; then export NTFY_TEST_OUTPUT; fi
  export NTFY_TEST_CALLS="$calls" NTFY_TEST_READS="$reads" NTFY_TEST_BODY="$body"
  export PATH="$root/tests/bin:$PATH"
  sh "$root/notify.sh" "$@" >"$stdout" 2>"$stderr"
)

run_event() {
  event_json="$(jq -cn --arg status "$1" --arg pane "$pane_id" \
    '{data:{agent_status:$status,pane_id:$pane,message:"Event message sentinel."}}')"
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
  run_event idle
  assert_count "$calls" 1
  assert_contains "$calls" 'Title: ✅ workspace・tab (Herdr)'
  if [ "$mode" = status ]; then
    assert_body "$(printf 'Status: idle\nPane: w1:p2')"
  else
    assert_body 'Agent output from the test pane.'
  fi
  run_event idle
  assert_count "$calls" 1

  run_event working
  run_event done
  assert_count "$calls" 2
  if [ "$mode" = status ]; then
    assert_body "$(printf 'Status: done\nPane: w1:p2')"
  fi
  run_event idle
  assert_count "$calls" 2

  run_event blocked
  assert_count "$calls" 3
  assert_contains "$calls" 'Title: 🚫 workspace・tab (Herdr)'
  if [ "$mode" = status ]; then
    assert_body "$(printf 'Status: blocked\nPane: w1:p2')"
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
  if [ "$mode" = status ]; then
    assert_count "$reads" 0
  else
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

# No terminal read or free-form fallback is allowed in status mode.
reset_case
NTFY_BODY_MODE=status
for line_setting in 0 invalid; do
  NTFY_LINES="$line_setting"
  run_event blocked
  assert_body "$(printf 'Status: blocked\nPane: w1:p2')"
done
pane_id=''
run_event blocked
assert_body "$(printf 'Status: blocked\nPane: unknown')"
assert_count "$reads" 0

# Pane metadata from the context is used when absent from the event.
context_json='{"workspace_label":"workspace","tab_label":"tab","pane_id":"w2:p3"}'
run_event blocked
assert_body "$(printf 'Status: blocked\nPane: w2:p3')"
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
  done
done

# The plugin config directory remains authoritative over the root fallback.
reset_case
printf 'NTFY_BODY_MODE=status\n' >"$test_dir/.env"
run_event blocked
assert_body "$(printf 'Status: blocked\nPane: w1:p2')"
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
  if [ "$mode" = status ]; then
    assert_contains "$stdout" "$(printf 'Sample body:\nStatus: done\nPane: wE:p1')"
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

  for mode in unset output; do
    unset NTFY_BODY_MODE
    if [ "$mode" = output ]; then NTFY_BODY_MODE=output; fi
    if run_notify --dry-run; then fail 'expected output line validation to fail'; fi
    assert_contains "$stdout" 'NTFY_LINES: invalid; expected a positive integer'
    assert_count "$calls" 0
    assert_count "$reads" 0
  done
done

for action in --dry-run --test; do
  reset_case
  NTFY_BODY_MODE=statuz
  if run_notify "$action"; then fail 'expected invalid action mode to fail'; fi
  assert_contains "$stderr" 'invalid NTFY_BODY_MODE; expected output or status'
  assert_count "$calls" 0
  assert_count "$reads" 0
done

echo 'notify tests: ok (events, content modes, diagnostics, config precedence)'
