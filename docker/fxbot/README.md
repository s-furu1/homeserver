# homeserver / docker / fxbot

ホームサーバー上で FX bot（`~/projects/fxbot`）を稼働させるための homeserver 運用定義です。
アプリケーション本体のロジックは別リポジトリで管理し、ここではコンテナ運用に必要な定義のみを保持します。

サーバーにアプリケーションソースは置きません。

## 役割分担

| 場所 | 内容 |
|------|------|
| `~/projects/fxbot` | アプリケーション本体・Dockerfile・テスト・仕様書 |
| `~/homeserver/docker/fxbot` | compose.yaml・環境変数サンプル・運用スクリプト・データボリューム |

イメージは GHCR 経由で取得します。使用するイメージは `ghcr.io/s-furu1/fxbot:v0.1.0` です。
homeserver 側では `latest` タグを使いません。

## ファイル構成

```text
homeserver/docker/fxbot/
├── compose.yaml
├── .env -> .env.practice
├── .env.example
├── .env.practice
├── .env.live
├── scripts/
│   └── switch-env.sh
└── data/
    ├── practice/
    │   └── trades.db
    └── live/
        └── trades.db
```

`.env` は常に symlink です。直接編集せず、`scripts/switch-env.sh` 経由で `.env.practice` または `.env.live` に切り替えます。

`.env.practice`、`.env.live`、`data/` は git 管理しません。OANDA API キーや Account ID の実値はリポジトリに書きません。

## compose.yaml

`compose.yaml` は固定タグ `ghcr.io/s-furu1/fxbot:v0.1.0` を参照します。

```yaml
services:
  fxbot:
    image: ghcr.io/s-furu1/fxbot:v0.1.0
    container_name: fxbot
    restart: unless-stopped
    env_file:
      - .env
    volumes:
      - ./data/${FXBOT_MODE}:/data
    networks:
      - homeserver
    healthcheck:
      test: ["CMD-SHELL", "test -f /tmp/fxbot_heartbeat && test $(($(date +%s) - $(stat -c %Y /tmp/fxbot_heartbeat))) -lt 180"]
      interval: 60s
      timeout: 10s
      retries: 3
      start_period: 30s
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "5"

networks:
  homeserver:
    external: true
```

`./data/${FXBOT_MODE}:/data` は practice/live の DB を分離するための設定です。`FXBOT_MODE` は shell 環境から展開されるため、素の `docker compose up -d` は使わず、必ず `scripts/switch-env.sh` から起動します。

## .env ファイル

`.env.example` を元に、サーバー上で `.env.practice` と `.env.live` を作成します。実値入りファイルはコミットしません。

```env
FXBOT_MODE=practice
OANDA_ENV=practice
OANDA_API_KEY=
OANDA_ACCOUNT_ID=

FXBOT_EXPECTED_MODE=practice
FXBOT_EXPECTED_ACCOUNT_ID=
FXBOT_DB_ENV=practice

SLACK_WEBHOOK_URL=
TZ=UTC
LOG_LEVEL=INFO

DB_PATH=/data/trades.db
DRY_RUN=true
```

`TZ=UTC` はコンテナ内の時刻を UTC に統一するために設定します。

## .env フォーマット制限

`scripts/switch-env.sh` は `.env.{mode}` を `KEY=value` 形式として検証します。

許可:

```env
KEY=value
```

禁止:

```env
export KEY=value
KEY = value
KEY="value"
KEY=value # comment
```

空白付き代入、quoted value、inline comment、`export` 構文は禁止です。

## practice 起動手順

```bash
cd ~/homeserver/docker/fxbot
cp .env.example .env.practice
vi .env.practice
./scripts/switch-env.sh practice
```

スクリプトは `.env.practice` の整合性を検証し、`.env` symlink を `.env.practice` に張り替え、`data/practice` を作成してから起動します。

## live 起動手順

```bash
cd ~/homeserver/docker/fxbot
cp .env.example .env.live
vi .env.live
docker compose stop fxbot
./scripts/switch-env.sh live
```

live 切替時は確認文字列 `I CONFIRM FXBOT LIVE` の入力が必要です。

`.env.live` では次の mode 系変数が `live` と一致している必要があります。

```env
FXBOT_MODE=live
OANDA_ENV=live
FXBOT_EXPECTED_MODE=live
FXBOT_DB_ENV=live
DB_PATH=/data/trades.db
DRY_RUN=false
```

`DRY_RUN` は `true` または `false` のみ許可します。

## 起動確認

```bash
cd ~/homeserver/docker/fxbot
docker compose ps
docker inspect --format '{{.State.Health.Status}}' fxbot
docker compose logs -f fxbot
```

## compose 構文確認

実運用では `scripts/switch-env.sh practice|live` が `.env` symlink を作ります。リポジトリ上では `.env` を commit しません。

compose 構文確認だけ行う場合は `scripts/check-compose.sh` を使います。

```bash
cd ~/homeserver/docker/fxbot
./scripts/check-compose.sh
```

`check-compose.sh` は `.env` が存在しない場合だけ、一時的に `.env -> .env.example` を作って `docker compose config` を実行します。終了後は自分が作った一時 symlink だけを削除します。既存の `.env` がある場合は上書きも削除もしません。

## healthcheck

healthcheck はコンテナ内の `/tmp/fxbot_heartbeat` の stale 判定です。
ファイルが存在し、最終更新から 180 秒未満なら healthy と判定します。180 秒以上更新されなければ unhealthy になります。

設定値:

```text
interval: 60s
timeout: 10s
retries: 3
start_period: 30s
stale threshold: 180s
```

## 更新手順

```bash
cd ~/homeserver/docker/fxbot
vi compose.yaml
./scripts/switch-env.sh "$(grep '^FXBOT_MODE=' .env | cut -d= -f2-)"
```

更新時は `compose.yaml` のタグを `v0.1.0` から次の明示タグへ変更します。`latest` は使いません。
`switch-env.sh` が `FXBOT_MODE` を export して `docker compose pull` と `docker compose up -d` を実行します。

## 停止手順

```bash
cd ~/homeserver/docker/fxbot
docker compose stop fxbot
```

## 緊急停止手順

```bash
cd ~/homeserver/docker/fxbot
docker compose stop fxbot
```

コンテナ停止だけでは OANDA 側ポジションは残ります。必要に応じて OANDA 管理画面で手動決済してください。
v1 では既存ポジションの引き継ぎ管理は非対応です。

## Uptime Kuma

Uptime Kuma では Docker container monitor で `fxbot` の healthcheck 状態を監視できます。

検知できる範囲:

- コンテナが起動しているか
- Docker healthcheck が healthy/unhealthy のどちらか
- `/tmp/fxbot_heartbeat` が 180 秒以上 stale になっていないか

検知できない範囲:

- OANDA 側の実ポジション状態
- シグナル判定や戦略ロジックの妥当性
- 約定処理の業務的な正しさ
- Slack 通知の到達性
- 既存ポジションの引き継ぎ可否

## バックアップ

次の DB を homeserver のバックアップ対象にします。

```text
docker/fxbot/data/practice/trades.db
docker/fxbot/data/live/trades.db
```

復元時はコンテナを停止し、該当 mode の `trades.db` を差し替えてから `scripts/switch-env.sh practice` または `scripts/switch-env.sh live` で起動します。
