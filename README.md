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
| Phase 2 | 生活自動化（Slack bot・家計・タスク・ランニング記録） | ⬜ 未着手 |
| Phase 3 | データ集約（ストレージ増設・バックアップ強化） | ⬜ 未着手 |
| Phase 4 | AI実験場（Ollama・ComfyUI・Whisper） | ⬜ 未着手 |
| Phase 5 | 拡張・最適化 | ⬜ 未着手 |

## 技術スタック
- **インフラ**: Docker, Docker Compose, Portainer
- **ネットワーク**: Tailscale（WireGuard）, UFW
- **GPU**: NVIDIA Container Toolkit, CUDA 13.2
- **監視**: Uptime Kuma
- **DNS・広告除去**: AdGuard Home
- **書類管理**: Paperless-ngx
- **パスワード管理**: Vaultwarden

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