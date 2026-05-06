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
- Slack channel ID
- Health webhook token
- Google Calendar ID
- Google credentials path
- Web URL
- backup 設定

ai-feed-bot の `.env` に設定するもの:

- `AI_FEED_BOT_IMAGE`
- Slack token
- Slack channel ID
- Ollama URL
- Ollama model
- fetch interval

daily-report-bot の `.env` に設定するもの:

- `DAILY_REPORT_BOT_IMAGE`
- Slack token
- Slack channel ID
- GitHub token
- repository list
- report schedule

secret 実値は docs には書かない。

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
- `/feed ping` がある場合は確認
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
- `/report ping` がある場合は確認
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
