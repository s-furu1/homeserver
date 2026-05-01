# homeserver
自宅ゲーミングPC（i7-13700 / RTX 4070 Ti）をホームサーバー化した構成管理リポジトリ。
サブスク削減・ローカルAI実験・生活インフラの自前化を目的としています。

## ハードウェア構成
| 項目 | 内容 |
|---|---|
| CPU | Intel Core i7-13700 |
| GPU | NVIDIA RTX 4070 Ti（VRAM 12GB） |
| Memory | 32GB DDR5-4800 |
| Storage | NVMe SSD 1TB |
| OS | Ubuntu Server 26.04 LTS |

## フェーズ構成
| フェーズ | 内容 | 状態 |
|---|---|---|
| Phase 0 | 基盤構築（Docker・Tailscale・GPU設定） | ✅ 完了 |
| Phase 1 | 生活インフラ（AdGuard Home・Vaultwarden・Paperless-ngx） | ✅ 完了 |
| Phase 2 | AI実験場（Ollama・ComfyUI・Whisper） | ⬜ 未着手 |
| Phase 3 | 拡張・最適化 | ⬜ 未着手 |

## 技術スタック
- **インフラ**: Docker, Docker Compose, Portainer
- **ネットワーク**: Tailscale（WireGuard）, UFW
- **GPU**: NVIDIA Container Toolkit, CUDA 13.2
- **監視**: Uptime Kuma
- **DNS・広告除去**: AdGuard Home
- **書類管理**: Paperless-ngx
- **パスワード管理**: Vaultwarden

## リポジトリ運用ルール

サーバー上で動かすものは「インフラ設定」と「自作アプリのソース」を物理的に分離して管理しています。

### 構成原則

```
~/homeserver/                  # 本リポジトリ（インフラ設定モノレポ）
└── docker/
    ├── {oss-service}/         # 既製OSS：compose.yaml のみ
    │   └── compose.yaml
    └── {custom-app}/          # 自作アプリ：compose.yaml のみ（GHCRからpull）
        ├── compose.yaml
        └── .env               # gitignore

~/projects/                    # 自作アプリの独立リポジトリ群
└── {custom-app}/              # アプリごとに1リポジトリ
    ├── src/
    ├── Dockerfile
    ├── tests/
    ├── pyproject.toml
    ├── .github/workflows/     # GHCRへのCI/CDpush
    └── README.md
```

### ルール

| ルール | 内容 |
|---|---|
| **R1** | `~/homeserver/` はインフラ設定の単一モノレポとして維持する |
| **R2** | 既製OSS（Portainer・AdGuard等）は `~/homeserver/docker/{name}/` に compose.yaml のみ配置する |
| **R3** | 自作アプリは `~/projects/{app}/` に独立リポジトリを切る |
| **R4** | 自作アプリのイメージはGHCR（`ghcr.io/sotadesuyo/{app}`）に公開し、homeserver側は `image:` 指定でpullする |
| **R5** | サーバー上に自作アプリのソースは置かない（compose.yamlと.envのみ） |
| **R6** | 機密情報は `.env` に分離し、`.env.example` のみコミットする |

### この分離の理由

- インフラ変更とアプリ変更でGit履歴が混ざらず、ポートフォリオとして読みやすい
- アプリごとに独立したCI/CD・バージョニング・READMEが可能
- サーバー入れ替え時はhomeserverリポジトリを clone → `docker compose up` で復元可能
- 自作アプリは単独でも公開・配布できる（GHCRイメージ単体で稼働可能）

## 自作アプリ
本サーバー上で稼働する自作アプリは `~/projects/` 配下で独立リポジトリとして管理しています。継続的改善を前提としたエンドレス運用。

| アプリ | 役割 | リポジトリ |
|---|---|---|
| （随時追加） | | |

## ディレクトリ構成
```
homeserver/
├── docker/
│   ├── portainer/
│   ├── uptime-kuma/
│   ├── adguard/
│   ├── paperless/
│   └── vaultwarden/
└── scripts/
    └── backup.sh
```

## 関連記事
- note（ストーリー）: https://note.com/sotadesuyo/n/n4dae4ff4e6f6
- Zenn（技術詳細）: https://izanami.dev/post/2cd04951-1ddd-420a-b753-a81cec0e0e1b
