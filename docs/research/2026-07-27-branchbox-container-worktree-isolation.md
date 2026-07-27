---
title: "branchbox — apple/container と worktree による並行開発の実行隔離（defer）"
date: 2026-07-27
status: research-complete
tags: [research-intake, worktree, container, execution-isolation, parallel-development, defer]
sources:
  - https://www.m3tech.blog/entry/2026/06/22/170000
related_ideas:
  - ideas/20260414/harness-architecture-layer-separation-control-loop.md（仮想環境 3 種分離: UI / execution / workspace）
related_research:
  - docs/research/2026-07-27-loop-engineering-intake.md（同時 intake・ループ軸）
  - docs/research/2026-07-27-team-harness-intake.md（同時 intake・チーム軸）
related_issues: [20, 21, 230]
next_step:
  trigger: "worktree の並列作業で実際に衝突が起きたとき。具体的には、複数ブランチのローカルサーバでポートが衝突したとき / あるブランチの DB マイグレーションが別ブランチを壊したとき / 並列セッションでどのブランチの画面を見ているか分からなくなったとき"
  actions:
    - "上記の衝突が起きた時点で本ノートを開き、execution 隔離を worktree より強く取る必要があるかを判断する。判断軸は『隔離の弱さが実害を出しているか』で、出ていなければ導入しない"
    - "導入検討に進む場合、ken-tunc/branchbox のライセンスを確認する（本ノート時点で未確認）。パターンのみ参照するなら不要"
    - "並列セッションの識別という観点では、既存のセッション命名フック（worktree は #issue 表示）と同じ問題を扱っている。ブランチ名をドメインにする発想を、URL 以外の識別面に転用できるか検討する"
  referenced_by: "Epic #20（wezterm-ai-mode）/ Epic #21（AIエージェント向けターミナル環境）/ #230（委譲 spawn 時のペインレイアウト）/ ideas/20260414（仮想環境 3 種分離）"
---

# branchbox — apple/container と worktree による並行開発の実行隔離

## 概要

2026 年 6-7 月の Read Later intake のうち、他の記事と層が違う 1 件。並列開発の実行環境の隔離を扱っており、当リポジトリの worktree 運用と隣接するが、現時点で導入の必要が生じていないため `defer` として記録する。再訪条件を frontmatter の `next_step.trigger` に具体化した。

検証状態の規約は同時 intake の他ノートと同じ。

---

## 記事情報

- **タイトル**: apple/container で worktree 並行開発を快適にするツールを作ってみた
- **URL**: https://www.m3tech.blog/entry/2026/06/22/170000
- **著者/組織**: 田口 / エムスリー（デジスマチーム）
- **公開日**: 2026-06-22
- **種別**: ブログ記事（自作ツール紹介）
- **要約**: Apple 純正の Linux コンテナツール apple/container と git worktree を組み合わせた並行開発環境ツール branchbox（`ken-tunc/branchbox`）の紹介。apple/container はコンテナごとに軽量 VM を立ち上げ専用 IP を割り当てるため、ブランチ名をドメインにしたローカルサーバ環境を作れる。結果として、同じポート番号でも複数ブランチが衝突せず、URL からどのブランチかを直感的に特定できる。設計の柱は 4 つで、ブランチ名のドメイン化、対象リポジトリへの Dockerfile や設定変更を要求しないこと、コンテナ化の有無を問わず動くこと、ホットリロード対応。実装上の要点として、ホスト側の `/etc/resolver` とコンテナ側の設定ファイルの 2 か所で DNS を設定する必要があること、ホストとコンテナ間でネイティブモジュールの ABI が食い違うため `node_modules` を専用ボリュームに分離すること、VM 境界をまたぐとファイル監視イベントが届かないためポーリング系の環境変数を注入すること、dev server は `0.0.0.0` にバインドしないとコンテナ専用 IP 経由で届かないことを挙げる。残った制約として、一部フレームワークで個別対応が必要なこと、apple/container に compose 相当の機能が未実装で複数コンテナ連携のツール化が今後の課題であること、使用している TLD が 2024 年の正式予約に依存することを挙げている。

---

## 本質的パターンと詳細

| # | パターン名 | 本質 | 種別 | 検証/根拠 |
|---|-----------|------|------|----------|
| P-1 | ブランチ名をドメインにして並列を識別する | 並列作業中のどれを見ているかを、URL という常に目に入る面で識別できるようにする | 設計原則 | [unverified-summary] https://www.m3tech.blog/entry/2026/06/22/170000 |
| P-2 | worktree に execution 隔離を重ねる | worktree はファイルを分けるだけなので、ポートや DB のような実行時リソースは分かれない。コンテナで実行面を分ける | 設計原則 | [unverified-summary] 同上 |
| P-3 | 対象リポジトリを汚さない | 対象リポジトリに Dockerfile や設定を追加させず、外側のツールだけで完結させる | 設計原則 | [unverified-summary] 同上 |
| P-4 | 境界をまたぐと壊れるものの一覧 | DNS の二重設定、ネイティブモジュールの ABI、ファイル監視イベント、バインドアドレス。VM 境界を挟むと壊れる箇所が決まっている | 実装パターン | [unverified-summary] 同上 |

**P-1 が既存の関心と重なる。** 当リポジトリは並列セッションの識別のためにセッション命名フックを持ち、worktree では `#issue` 形式で表示している。[verified] `canonical/CATALOG.md`（セッション命名フックの説明: worktree は `#<issue> <slug>`、並列セッション識別用）。branchbox は同じ問題を URL という別の面で解いている。識別の面を増やすという発想は、フック側にも転用できる可能性がある。[speculation]

**P-2 が defer の理由でもある。** ideas に整理した仮想環境の 3 種分離（UI 隔離 / execution 隔離 / workspace 隔離）で言えば、当環境は wez をセッションの面、worktree を workspace の面として使っており、execution の面は分けていない。[verified] `ideas/connections.md`（仮想環境隔離とセッション管理の節: wez = session fabric / worktree = execution sandbox / orchestrator = promotion manager）。ただし現状の作業実態はドキュメントとシェルスクリプトが中心で、ローカルサーバや DB マイグレーションを並列に走らせる場面がほぼない。隔離の弱さが実害を出していないので、いま導入する理由がない。[speculation]

**P-4 は導入時のチェックリストとして価値がある。** 導入を判断する場面が来たら、この 4 点が最初に踏む罠になる。記事がすべて実測で潰しているので、そのまま手順として使える。[unverified-summary]

---

## 資産マッピング結果

### トラック A: 既存資産への接続

| パターン | 接続先 | 接続の性質 | ギャップ / 新規知見 |
|---------|--------|-----------|-----------------|
| P-1 | セッション命名フック、#230 | 補強 | 並列の識別面を増やすという発想 |
| P-2 | `worktrunk-worktrees`、ideas/20260414（3 種分離） | 拡張 | execution 隔離を worktree より強く取る選択肢。現状は不要 |
| P-3 | canonical の配布方針 | 補強 | 対象を汚さず外側で完結させる方針は既存と同型 |
| P-4 | — | 補強 | 導入時のチェックリスト |

### トラック B: 新規導入候補

| パターン | 既存対応物 | 導入形態 | 実現可能性メモ |
|---------|-----------|---------|-------------|
| execution 隔離の追加（P-2） | worktree のみ | 外部ツール導入 | 実害が出ていないので現時点では見送り。導入時は `ken-tunc/branchbox` のライセンス確認が必要（未確認） |

---

## アクション判定

| パターン | 種別 | 理由 |
|---------|------|------|
| P-2 | `defer` | 実行隔離の必要が生じていない。再訪条件を frontmatter に具体化した |
| P-1 | `archive-note` | 識別面を増やす発想として記録 |
| P-3 / P-4 | `archive-note` | 導入判断時のチェックリストとして記録 |

---

## 原文を読む価値

要点で足りる。実際に導入を判断する段になったら、P-4 の 4 つの罠と設定手順を原文で確認する。
