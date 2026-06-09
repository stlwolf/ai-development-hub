# bin/ — スクリプト索引

orchestration-engine の実行可能エントリの簡易リファレンス（AI エージェント / 人間向け）。背景は親 [`../README.md`](../README.md)、詳細は各スクリプト冒頭のコメントと `docs/` を参照。

scripts は 2 系統に分かれる（[`../README.md`](../README.md) 「2 系統」節）:

- **本体エンジン**: `oe`（+ 補助 `oe-capture`）
- **親子委譲 CLI（delegate-task 系）**: `oe-delegate` / `oe-send` / `oe-list` / `oe-report`

---

## oe — 本体エンジン（自律オーケストレーション）

1 サイクルの自律ループ（envelope→spawn→capture→verify→monitor）。非対話・wez + `claude -p`。

```bash
bash bin/oe "タスク記述"
bash bin/oe --task-file <path>
```

関連 lib: `envelope.sh` / `spawn.sh` / `capture.sh` / `verify.sh` / `monitor.sh` / `audit.sh` / `cleanup.sh` / `constants.sh`

## oe-capture — ペイン capture（本体エンジン補助）

既存（対話中）ペインに attach し、終端マーカーを読み取って分類・KVS/audit に記録。

```bash
oe-capture <pane_id> [--session-id <id>] [--lines <N>]
```

関連 lib: `attach.sh` / `capture.sh` / `audit.sh` / `session.sh`

---

## oe-delegate — 子セッション起動 + キック（親子委譲）

子 Claude を `tmux split-window` で起動し、タスク（または kickoff doc）をキック（spawn + send の合成）。

```bash
oe-delegate [-w WORKSPACE] [--kickoff <path>] [--label <#N|name>] [--] <task>
```

- `--kickoff <path>` … `"<path> を読んで進めて。"` を送り、doc のディレクトリを `--add-dir` で子に開示
- `--label <#N|name>` … registry 登録ラベル（後で `oe-send <label>` で指す）
- tmux 内必須（`TMUX_PANE` から親ペイン取得、`PARENT_TMUX_PANE` を子へ継承）

関連 lib: `delegate-registry.sh`（キック注入は `oe-send` 経由）

## oe-send — 既存ペインへ 1 行を汎用送信

親→子の追送、子→親の戻し、関連の薄い側道会話を一手に担う送信口。

```bash
oe-send [--kickoff <path>] [--no-enter] [--] <target> [ad-hoc...]
```

- `<target>` … 生ペインID（`%N`）または ラベル（`#N` / 任意名。registry で解決）
- `--no-enter` … 投入のみ（ステージ＝人間が読んで Enter）
- 子→親の戻し: `oe-send "$PARENT_TMUX_PANE" "申し送り..."`
- payload は 1 行保証（改行は fail-fast で拒否）。自動 Enter 後に観測ベース finalize（`OE_SEND_FINALIZE=0` で無効）

関連 lib: `delegate-send.sh`（`oe_send_line`）/ `delegate-registry.sh`

## oe-list — 宛先候補の一覧

現サーバの生存ペインを source 列（pane-issue / spawn-registry / pane-title）付きで表示。`oe-send <target>` に渡すラベル / ペインID の確認用。

```bash
oe-list
```

関連 lib: `delegate-registry.sh`

## oe-report — 親へ申し送り（legacy）

親ペインへ申し送り / レビュー依頼を送る。**legacy**: 戻しは `oe-send "$PARENT_TMUX_PANE"` に一本化が方針。

```bash
oe-report [--review] <message>
```

関連 lib: `delegate-send.sh`

---

## 主要な環境変数

| 変数 | 用途 | 既定 |
|------|------|------|
| `OE_SEND_ENTER_DELAY` | 送信: リテラル送信 → Enter の小休止（秒） | `0.3` |
| `OE_SEND_FINALIZE` | 送信後 finalize の有効/無効（`0` で無効） | 有効 |
| `OE_SEND_FINALIZE_TIMEOUT` / `_INTERVAL` / `_STABLE` | finalize の settle 窓 / poll 間隔 / 終端安定回数 | `3` / `0.3` / `3` |
| `OE_DELEGATE_WAIT_SEC` | oe-delegate: 子 claude 起動待ち（秒） | `4` |
| `PARENT_TMUX_PANE` | oe-delegate が子へ渡す親ペイン（戻し用） | （自動） |

本体エンジン側（`OE_POLL_INTERVAL` / `OE_CB_*` / `OE_TARGET_AI_*` / `OE_VERIFY_AI_*` 等）は [`../lib/constants.sh`](../lib/constants.sh) を参照。
