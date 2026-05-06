# Slack Apps Deploy Runbook

この手順は homeserver 側から見た `life-bot` / `ai-feed-bot` / `daily-report-bot` / `ollama` の build、GHCR push、pull、起動確認、rollback の運用メモです。日時を扱う場合は JST (Asia/Tokyo) を基準にします。

このフェーズでは実デプロイを行いません。`docker build`、`docker push`、`docker compose up -d` は手順として記載するだけです。

## 1. 前提

- アプリソースは `~/projects/{app}` に置く。
- コンテナ運用は `~/homeserver/docker/{app}` に置く。
- homeserver 側にアプリソース、`Dockerfile`、`pyproject.toml`、`app/`、`tests/` を置かない。
- 自作アプリ image は GHCR を参照する。
- 実運用 `.env` は各 `~/homeserver/docker/{app}/.env` に置く。
- `.env` 実値は git 管理しない。
- GHCR owner は `<owner>` または環境変数で表記し、docs へ固定しない。
- Slack token、GitHub token、Google credentials、Health webhook token の実値は docs へ書かない。
- Slack App は life-bot の1つだけを使う。slash command は `/life` のみ。
- ai-feed-bot / daily-report-bot は Slack token を持たず、backend/worker と internal API として動かす。
- internal API は `slack-apps` Docker network 内だけで使い、host port は公開しない。

共有 network は事前に作成する。

```bash
docker network create slack-apps || true
```

## 2. Image Variables

compose 側で使用する image 変数:

```bash
LIFE_BOT_IMAGE=ghcr.io/<owner>/life-bot:latest
AI_FEED_BOT_IMAGE=ghcr.io/<owner>/ai-feed-bot:latest
DAILY_REPORT_BOT_IMAGE=ghcr.io/<owner>/daily-report-bot:latest
```

`ollama` は公式 image を使う:

```bash
ollama/ollama:latest
```

## 3. Build

life-bot:

```bash
cd ~/projects/life-bot
docker build -t ghcr.io/<owner>/life-bot:latest .
```

ai-feed-bot:

```bash
cd ~/projects/ai-feed-bot
docker build -t ghcr.io/<owner>/ai-feed-bot:latest .
```

daily-report-bot:

```bash
cd ~/projects/daily-report-bot
docker build -t ghcr.io/<owner>/daily-report-bot:latest .
```

## 4. GHCR Login

```bash
echo "$GHCR_TOKEN" | docker login ghcr.io -u <owner> --password-stdin
```

- `GHCR_TOKEN` の実値は docs、README、issue、PR に貼らない。
- PAT は packages の write/read 相当の権限を持つものを使う。
- token を shell history やログに残さない。

## 5. Push

```bash
docker push ghcr.io/<owner>/life-bot:latest
docker push ghcr.io/<owner>/ai-feed-bot:latest
docker push ghcr.io/<owner>/daily-report-bot:latest
```

## 6. homeserver .env

各ディレクトリで `.env.example` を `.env` にコピーし、実運用値は `.env` のみに書く。

```bash
cd ~/homeserver/docker/life-bot
cp .env.example .env

cd ~/homeserver/docker/ai-feed-bot
cp .env.example .env

cd ~/homeserver/docker/daily-report-bot
cp .env.example .env
```

life-bot の `.env` に設定するもの:

- `LIFE_BOT_IMAGE`
- Slack token
- Slack channel ID (`#life-*`, `#ai-feed`, `#server-report`, `#server-alert`)
- `AI_FEED_BASE_URL=http://ai-feed-bot:8000`
- `DAILY_REPORT_BASE_URL=http://daily-report-bot:8000`
- Health webhook token
- Google Calendar ID
- Google credentials path
- Web URL
- backup 設定

ai-feed-bot の `.env` に設定するもの:

- `AI_FEED_BOT_IMAGE`
- `AI_FEED_ENABLE_SLACK=false`
- `AI_FEED_ENABLE_WORKER=true`
- `AI_FEED_ENABLE_WEB=true`
- Ollama URL
- Ollama model
- fetch interval

daily-report-bot の `.env` に設定するもの:

- `DAILY_REPORT_BOT_IMAGE`
- `DAILY_REPORT_ENABLE_SLACK=false`
- `DAILY_REPORT_ENABLE_WORKER=true`
- `DAILY_REPORT_ENABLE_WEB=true`
- GitHub token
- report schedule

secret 実値は docs には書かない。

## 6.5 外部credential / env inventory

Phase 17 の実デプロイ前に、以下の外部 credential、ID、環境値、credential ファイル配置を確認する。secret 実値は `.env` または指定の secrets ディレクトリにだけ置き、docs、compose、git 管理対象ファイルには書かない。

### GHCR

- `GHCR owner`: 実運用の GitHub owner / org。docs には固定せず `<owner>` として扱う。
- `GHCR_TOKEN`: GHCR login 用 token。packages の write/read 相当権限を持つものを shell 環境にだけ置く。
- `LIFE_BOT_IMAGE`: `ghcr.io/<owner>/life-bot:latest`
- `AI_FEED_BOT_IMAGE`: `ghcr.io/<owner>/ai-feed-bot:latest`
- `DAILY_REPORT_BOT_IMAGE`: `ghcr.io/<owner>/daily-report-bot:latest`

### Slack

Slack App は life-bot 用の1つだけを作り、Socket Mode を有効化する。App-Level Token には `connections:write` を付け、Bot Token と Signing Secret を取得する。slash command は `/life` のみを使う。Interactivity を有効化し、bot を対象チャンネルに invite してから channel ID を life-bot `.env` に設定する。

life-bot:

- `SLACK_BOT_TOKEN`
- `SLACK_APP_TOKEN`
- `SLACK_SIGNING_SECRET`
- `SLACK_CHANNEL_LIFE_MONEY`
- `SLACK_CHANNEL_LIFE_TASK`
- `SLACK_CHANNEL_LIFE_RUNNING`
- `SLACK_CHANNEL_LIFE_CALENDAR`
- `SLACK_CHANNEL_LIFE_ALERT`
- `SLACK_CHANNEL_AI_FEED`
- `SLACK_CHANNEL_SERVER_REPORT`
- `SLACK_CHANNEL_SERVER_ALERT`

ai-feed-bot / daily-report-bot には Slack token を設定しない。Slack投稿、ボタン、固定パネル更新は life-bot が internal API 経由で行う。

### Google Calendar

Google Calendar は専用共有カレンダーを正本にする。個人メインカレンダーを bot に直接触らせない。Service Account JSON は `~/homeserver/docker/life-bot/secrets/google-calendar-service-account.json` に置き、life-bot compose では `./secrets:/secrets:ro` として read-only mount する。`.env` の `GOOGLE_APPLICATION_CREDENTIALS` は `/secrets/google-calendar-service-account.json` にする。

手順:

1. Google Cloud Project を作る。
2. Google Calendar API を有効化する。
3. Service Account を作る。
4. Service Account JSON を発行する。
5. JSON を `~/homeserver/docker/life-bot/secrets/google-calendar-service-account.json` に置く。
6. Google Calendar で専用共有カレンダーを作る。
7. カレンダー設定から Calendar ID を取得する。
8. Service Account のメールアドレスをそのカレンダーに共有する。
9. 権限は予定を追加・変更できるものにする。
10. life-bot `.env` に `GOOGLE_CALENDAR_ID` と `GOOGLE_APPLICATION_CREDENTIALS` を設定する。

必要な値:

- `GOOGLE_CALENDAR_ID`
- `GOOGLE_APPLICATION_CREDENTIALS=/secrets/google-calendar-service-account.json`
- Google Cloud Project
- Google Calendar API enabled
- Service Account
- Service Account JSON

### Health Auto Export

- `HEALTH_WEBHOOK_TOKEN`: token は life-bot `.env` にだけ置く。
- iOS 側 webhook URL は Tailscale 等の到達経路確定後に設定する。

### Ollama

Ollama は独立した compose service として起動し、ai-feed-bot に内包しない。host 側確認用に `127.0.0.1:11434` だけ bind する。ai-feed-bot の `OLLAMA_BASE_URL` は `slack-apps` network 内接続の `http://ollama:11434` を使う。`OLLAMA_MODEL` は ai-feed-bot `.env` で指定し、model pull は別途手動確認する。

必要な値:

- `OLLAMA_BASE_URL=http://ollama:11434`
- `OLLAMA_MODEL`

確認:

```bash
cd ~/homeserver/docker/ollama
docker compose up -d
curl -s http://127.0.0.1:11434/api/tags | head
```

### daily-report-bot

GitHub commit 集計には GitHub API を使う。daily-report-bot は `GITHUB_TOKEN` で authenticated user の repositories API から取得できる全リポジトリを対象にする。private repo、archived repo、fork repo も API で返るものは対象にする。token の権限が不足している場合は、取得できる範囲だけが集計対象になる。`GITHUB_TOKEN` が未設定、または repo 一覧取得に失敗した場合でもアプリ全体は落とさず、集計対象なしとして続行する。

必要な値:

- `GITHUB_TOKEN`
- `DAILY_REPORT_DAILY_HOUR`
- `DAILY_REPORT_DAILY_MINUTE`
- `DAILY_REPORT_WEEKLY_DAY`
- `DAILY_REPORT_WEEKLY_HOUR`
- `DAILY_REPORT_WEEKLY_MINUTE`

## 7. Pull And Up

life-bot:

```bash
cd ~/homeserver/docker/life-bot
docker compose pull
docker compose up -d
```

ai-feed-bot:

```bash
cd ~/homeserver/docker/ai-feed-bot
docker compose pull
docker compose up -d
```

daily-report-bot:

```bash
cd ~/homeserver/docker/daily-report-bot
docker compose pull
docker compose up -d
```

## 8. Ollama

```bash
cd ~/homeserver/docker/ollama
docker compose pull
docker compose up -d
```

`ai-feed-bot` からは `OLLAMA_BASE_URL=http://ollama:11434` で参照する。`ollama` は `ai-feed-bot` に内包せず、独立した compose service として運用する。

## 9. Startup Checks

life-bot:

```bash
cd ~/homeserver/docker/life-bot
docker compose ps
docker compose logs -f --tail=100
```

確認項目:

- Slack `/life ping`
- Slack `/life admin refresh-panels`
- WebUI `http://127.0.0.1:18080/healthz`
- `/money`
- `/tasks`
- `/running`
- `/calendar`
- backup 生成
- `docker/life-bot/data/life.db` が作成されること

ai-feed-bot:

```bash
cd ~/homeserver/docker/ai-feed-bot
docker compose ps
docker compose logs -f --tail=100
```

確認項目:

- Slack `#ai-feed` panel
- life-bot の `#ai-feed` ボタンから internal API が呼べること
- Ollama 接続
- RSS fetch
- draft 生成
- X 自動投稿が存在しないこと

daily-report-bot:

```bash
cd ~/homeserver/docker/daily-report-bot
docker compose ps
docker compose logs -f --tail=100
```

確認項目:

- Slack `#server-report` panel
- life-bot の `#server-report` ボタンから internal API が呼べること
- GitHub commit 集計
- `job_runs` 記録
- daily report 生成
- `docker/daily-report-bot/data/daily-report.db` が作成されること

ollama:

```bash
cd ~/homeserver/docker/ollama
docker compose ps
docker compose logs -f --tail=100
```

確認項目:

- `127.0.0.1:11434` で応答
- ai-feed-bot から接続できる

## 10. SQLite Persistence

- life-bot: `docker/life-bot/data/life.db`
- ai-feed-bot: `docker/ai-feed-bot/data/ai-feed.db`
- daily-report-bot: `docker/daily-report-bot/data/daily-report.db`

DB 実体は git 管理しない。

確認:

```bash
git status --short
```

DB、log、backup 実体が出ていないことを確認する。

## 11. Backup Checks

life-bot:

- `docker/life-bot/backup/` に backup が生成されるか確認する。

ai-feed-bot / daily-report-bot:

- 現時点では backup job は未実装扱い。
- 将来、worker または外部ジョブで backup 方針を追加する。

## 12. Rollback

`latest` 運用だけだと rollback しづらい。今後は最低限、次を併用する。

- git commit hash tag
- version tag
- `latest` と version tag の併用

tag 例:

```bash
docker tag ghcr.io/<owner>/life-bot:latest ghcr.io/<owner>/life-bot:<version>
docker push ghcr.io/<owner>/life-bot:<version>
```

rollback 例:

```yaml
image: ghcr.io/<owner>/life-bot:<version>
```

実運用では compose を直接書き換えるのではなく、各 `.env` の `LIFE_BOT_IMAGE`、`AI_FEED_BOT_IMAGE`、`DAILY_REPORT_BOT_IMAGE` を対象 tag へ切り替える。

## 13. Incident Checklist

障害時は次の順に確認する。

```bash
docker compose ps
docker compose logs --tail=200
```

- `.env` 設定
- image 環境変数
- SQLite DB path
- Slack token / channel ID
- Google credentials
- GHCR pull 権限
- Ollama 起動状況
- GitHub token
- disk 容量
- backup 有無

## 14. Guardrails

- 実デプロイ確認は Phase 16 で行う。
- この手順整理では `docker build`、`docker push`、`docker compose up -d` を実行しない。
- secret 実値、credential JSON 本体、private key は docs に書かない。
- homeserver 側にアプリソースを複製しない。
