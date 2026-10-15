# herdr-ntfy

[English](README.md)

[Herdr](https://herdr.dev/)にて、agentが `done` または `blocked` になったとき、または `working` から直接 `idle` に変化したとき、ntfyへ通知するプラグインです。
オプションの [Collie](https://github.com/AltanS/collie) 連携を設定すると、通知をタップして、通知元のHerdr paneをCollieのWeb画面で開けます。
機能を最低限に抑えることで、依存関係をシンプルにしています。

## 通知例

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

- `done` と `working → idle` は `✅`、`blocked` は `🚫` で通知します。
- `working → idle` の変化を判定するため、paneごとの直近statusをplugin config directoryに保存します。
- `output` モードの通知タイトルは `<emoji> <workspace>・<tab> (<NTFY_TITLE>)` です。`status` モードでは `<emoji> <workspace> · <agent> (<NTFY_TITLE>)` を使用します。
- 通知本文は既定でagent paneの直近出力です。`NTFY_BODY_MODE=status` を設定すると、本文は `Status` と、取得できた場合のみ続く `Branch` になり、workspaceとagentはタイトルにのみ表示します。
- `COLLIE_URL` を設定すると、通知に [Collie](https://github.com/AltanS/collie) の対象paneを開く `Click` アクションが付きます（`<COLLIE_URL>/pane/<pane_id>`）。
- `Priority` ヘッダーは送信しません。

## 必要なもの

- Herdr >= 0.7.0
- `sh`
- `curl`
- `jq`

## インストール

```sh
herdr plugin install horn553/herdr-ntfy
config_dir="$(herdr plugin config-dir horn553.herdr-ntfy)"
touch "$config_dir/.env"
chmod 600 "$config_dir/.env"
$EDITOR "$config_dir/.env"
```

`$config_dir/.env` を作成して権限を絞り、以下を設定してください。

```sh
NTFY_URL=https://ntfy.sh/your-topic
NTFY_TITLE=Herdr
NTFY_TOKEN=
NTFY_BODY_MODE=output
NTFY_LINES=12
COLLIE_URL=
```

保護されたtopicを使う場合は `NTFY_TOKEN` を設定します。

### 通知本文のモード

`NTFY_BODY_MODE` には `output`（既定）または `status` を指定します。未設定または空の場合は `output` となり、paneの直近出力と、出力が空の場合の既存のメッセージfallbackを維持します。`output` モードでは `NTFY_LINES` で直近出力の行数を指定します。

状態と場所だけを受け取るには、plugin config directoryの `.env` に以下を設定してください。

```sh
NTFY_BODY_MODE=status
```

agentが入力待ちの場合、例えば以下の通知になります。

```text
Title: 🚫 herdr-ntfy · Codex (Herdr)

Status: blocked
Branch: feature/example
```

`status` モードはworkspaceとagentをタイトルにのみ表示し、本文には繰り返しません。本文は `Status` と、取得できた場合のみ続く `Branch` で構成され、branchが不明なら状態の1行だけになります。terminal出力を読み取らず、event/contextの自由記述メッセージもコピーしません。`NTFY_LINES` はdry-runの検証時も使用しません。本文にはHerdrの実際の `done`、`blocked`、または通知対象の `idle` を表示します。tab/pane IDは表示しません。任意のCollieリンクは引き続き通知元のpaneを開きます。`output` モードのタイトルと本文は従来どおりです。

タイトルの名前は、現在フォーカスされている場所ではなく、eventを発生させたpaneに対応します。agentは通知元eventの `display_agent`、次に `agent` を優先し、不足する場合だけ一致するcontextまたはpaneのメタデータを使います。agentが不明なら `unknown` を表示します。workspace名が不明なら通知元workspace ID、次に `unknown` を表示します。無関係なフォーカス先、terminalタイトル、自由記述メッセージから推測しません。

Gitは任意です。Herdrには型付きbranchフィールドがないため、検証済み通知元paneの絶対パス `foreground_cwd`、なければ `cwd` からGitで現在のbranchを読み取ります。継承したGitのディレクトリ指定変数を無視し、plugin自身のcheckoutやフォーカス先のcwdを代用しません。Git/cwdがない場合、Git管理外、detached HEAD、取得失敗の場合は `Branch` 行を省略します。メタデータ/Gitの取得は各1秒、合計最大3回で、agentのterminalへコマンドは送信しません。

値は大文字と小文字を区別します。空でない他の値を指定すると、hook、dry-run、test actionはpane出力の読み取りや通知送信を行わずに失敗します。

### Collie連携（任意）

このHerdrインスタンスで [Collie](https://github.com/AltanS/collie) を利用している場合は、`$config_dir/.env` にCollieのベースURLを設定してください（末尾スラッシュなし）。

```sh
COLLIE_URL=https://your-tailnet-host.ts.net
```

agentの通知に通知元paneへのリンクが追加されます。通知をタップすると、そのpaneをCollieで開けます。リンクを開く端末からCollieインスタンスへアクセスできる必要があります。

`COLLIE_URL` が未設定または空の場合は、Collieへのリンクなしでntfy通知を受け取れます。以下のdry-runで生成されるURLを確認し、実際のagent通知でリンク先への遷移を確認してください。`test` アクションはpaneへのリンクを含まない汎用のテスト通知を送信します。

## dry-run

設定内容を確認し、サンプル通知内容を表示します。ntfyには送信しません。

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

`action invoke` は非同期で実行されます。dry-runの出力はplugin logで確認してください。

`NTFY_BODY_MODE=status` の場合、dry-runは `NTFY_LINES: unused (status mode)` と以下のサンプルタイトル・本文を表示します。実際のメタデータ/Git取得、paneの読み取り、通知送信は行いません。

```text
Sample title:
✅ verification · Codex (Herdr)

Sample body:
Status: done
Branch: feature/example
```

## test

ntfyへ実際にテスト通知を送信します。選択したモードを検証・表示しますが、どちらのモードでも同じ汎用テスト本文を送信します。paneの読み取りやCollieリンクの追加は行いません。

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

## ローカル開発

```sh
herdr plugin link .
config_dir="$(herdr plugin config-dir horn553.herdr-ntfy)"
cp .env.example "$config_dir/.env"
```

ローカル開発中は `./.env` もfallbackとして読みます。

status変化のテストは以下で実行できます。

```sh
sh tests/notify_test.sh
```

テストは本文モード、通知元とフォーカス先の区別、agentの優先順位、任意のbranch、取得のタイムアウト、診断actionも対象とし、ローカルの `herdr`、`curl`、`git` の代替を使用するため、実際の通知は送信しません。Herdr内で実行した場合も、`HERDR_BIN_PATH` はテスト用の代替に固定されます。メタデータ/Git取得とterminal出力の読み取りは別々に記録します。一時Gitリポジトリで、通知元branch、継承Git変数の無視、detached HEAD、Git管理外の動作を検証し、実際のcheckoutは変更しません。

## Marketplace

Herdr marketplaceは `herdr-plugin` topicが付いたpublic GitHub repositoryを自動indexします。

## License

[MIT](LICENSE)
