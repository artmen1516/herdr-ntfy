# herdr-ntfy

[日本語](README-ja.md)

A [Herdr](https://herdr.dev/) plugin that sends ntfy notifications when an agent reaches `done` or `blocked`, or changes directly from `working` to `idle`.
With optional [Collie](https://github.com/AltanS/collie) integration, tap a notification to open the Herdr pane that triggered it in Collie's web interface.
The feature set is intentionally small to keep dependencies simple.

## Notification Examples

```text
Title: ✅ herdr-ntfy・main (Herdr)

Implemented the ntfy plugin.
Tests not run.
```

```text
Title: 🚫 herdr-ntfy・main (Herdr)

Blocked because NTFY_URL is not configured.
Set it in the plugin config directory .env file.
```

- `done` and `working → idle` use `✅`; `blocked` uses `🚫`.
- The plugin stores the latest status for each pane under the plugin config directory so it can recognize `working → idle` transitions.
- The notification title is `<emoji> <workspace>・<tab> (<NTFY_TITLE>)`.
- The notification body is recent output from the agent pane by default. Set `NTFY_BODY_MODE=status` to send only the status and pane ID.
- When `COLLIE_URL` is set, the notification includes a `Click` action that opens the source pane in [Collie](https://github.com/AltanS/collie) at `<COLLIE_URL>/pane/<pane_id>`.
- The plugin does not send a `Priority` header.

## Requirements

- Herdr >= 0.7.0
- `sh`
- `curl`
- `jq`

## Install

```sh
herdr plugin install horn553/herdr-ntfy
config_dir="$(herdr plugin config-dir horn553.herdr-ntfy)"
touch "$config_dir/.env"
chmod 600 "$config_dir/.env"
$EDITOR "$config_dir/.env"
```

Create `$config_dir/.env`, restrict its permissions, and put this in it.

```sh
NTFY_URL=https://ntfy.sh/your-topic
NTFY_TITLE=Herdr
NTFY_TOKEN=
NTFY_BODY_MODE=output
NTFY_LINES=12
COLLIE_URL=
```

Set `NTFY_TOKEN` when using a protected topic.

### Notification body mode

`NTFY_BODY_MODE` accepts `output` (default) or `status`. An unset or empty value selects `output`, which keeps recent pane output and the existing empty-output message fallback. In output mode, `NTFY_LINES` controls the number of recent lines.

To receive only state and location, set this in the plugin config directory `.env`:

```sh
NTFY_BODY_MODE=status
```

An agent waiting for input produces a notification such as:

```text
Title: 🚫 herdr-ntfy・main (Herdr)

Status: blocked
Pane: w1:p2
```

Status mode never reads terminal output or copies free-form event/context messages. `NTFY_LINES` is unused, including during dry-run validation. The body reports Herdr's actual `done`, `blocked`, or eligible `idle` status; a missing pane ID appears as `unknown`. Workspace/tab labels remain in the title, and optional Collie links remain available.

Values are case-sensitive. Any other nonempty mode makes the hook, dry-run, or test action fail without reading pane output or sending a notification.

### Optional Collie integration

If you already use [Collie](https://github.com/AltanS/collie) with this Herdr instance, set its base URL in `$config_dir/.env` (no trailing slash):

```sh
COLLIE_URL=https://your-tailnet-host.ts.net
```

Agent notifications will include a link to the pane that triggered them. Tap a notification to open that pane in Collie. The device opening the link must be able to reach your Collie instance.

Leave `COLLIE_URL` unset or empty to receive ntfy notifications without Collie links. The dry-run below previews the generated URL; verify click-through behavior with an actual agent notification. The `test` action sends a generic notification without a pane link.

## dry-run

Check configuration and print a sample notification. Nothing is sent to ntfy.

```console
$ herdr plugin action invoke dry-run
{"id":"cli:plugin","result":{"log":{"log_id":"plugin-log-113","status":"running"},"type":"plugin_action_invoked"}}

$ herdr plugin log list --plugin horn553.herdr-ntfy --limit 1 | jq -r '.result.logs[-1].stdout'
Herdr ntfy dry-run

curl: ok
jq: ok
NTFY_URL: ok (https://ntfy.sh/your-...)
NTFY_TITLE: Herdr
NTFY_BODY_MODE: output
NTFY_TOKEN: not set
NTFY_LINES: 12
COLLIE_URL: ok (https://your-tailnet-host.ts.net)

Sample title:
✅ verification・dry-run (Herdr)

Sample body:
Herdr ntfy dry-run: no notification was sent.

Sample click URL:
https://your-tailnet-host.ts.net/pane/wE%3Ap1

Result: ok
```

`action invoke` runs asynchronously. Check the plugin log for the dry-run output.

With `NTFY_BODY_MODE=status`, dry-run shows `NTFY_LINES: unused (status mode)` and this synthetic body without reading a pane or sending a notification:

```text
Status: done
Pane: wE:p1
```

## test

Send a real test notification to ntfy. The action validates and reports the selected mode, but always sends the same generic test body without reading a pane or adding a Collie link.

```console
$ herdr plugin action invoke test
{"id":"cli:plugin","result":{"log":{"log_id":"plugin-log-114","status":"running"},"type":"plugin_action_invoked"}}

$ herdr plugin log list --plugin horn553.herdr-ntfy --limit 1 | jq -r '.result.logs[-1].stdout'
Herdr ntfy test

curl: ok
NTFY_URL: ok (https://ntfy.sh/your-...)
NTFY_TITLE: Herdr
NTFY_BODY_MODE: output
NTFY_TOKEN: not set
COLLIE_URL: not set (notifications will have no click action)

Sending title:
🧪 verification・test (Herdr)

Sending body:
Herdr ntfy test: this notification was sent by the test action.
Sent at: 2026-07-03T00:00:00Z

ntfy response:
{"id":"...","time":...,"expires":...,"event":"message","topic":"your-topic","message":"..."}

Result: sent
```

## Local Development

```sh
herdr plugin link .
config_dir="$(herdr plugin config-dir horn553.herdr-ntfy)"
cp .env.example "$config_dir/.env"
```

During local development, `./.env` is also read as a fallback.

Run the transition tests with:

```sh
sh tests/notify_test.sh
```

The suite also covers body modes and diagnostic actions with local `herdr` and `curl` substitutes; it sends no real notifications. It pins `HERDR_BIN_PATH` to the substitute, including when run inside Herdr.

## Marketplace

Herdr's marketplace automatically indexes public GitHub repositories tagged with the `herdr-plugin` topic.

## License

[MIT](LICENSE)
