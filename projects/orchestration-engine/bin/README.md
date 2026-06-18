# bin/ — スクリプト索引

orchestration-engine の実行可能エントリの簡易リファレンス（AI エージェント / 人間向け）。背景は親 [`../README.md`](../README.md)、詳細は各スクリプト冒頭のコメントと `docs/` を参照。

scripts は 2 系統に分かれる（[`../README.md`](../README.md) 「2 系統」節）:

- **本体エンジン**: `oe`（+ 補助 `oe-capture`）
- **親子委譲 CLI（delegate-task 系）**: `oe-delegate` / `oe-send` / `oe-list` / `oe-select` / `oe-report`

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

## oe-refute — 確定前の同期反証 verb（#183 / Stage A）

確定（設計判断・根拠断定・外部仮説ジャンプ）の前に、独立した反証レーンを N 体立てて claim を反証させ、共有 verdict エンベロープ `{verdict, reason}` を同期で返す。バックエンドは `so-compare`（codex/cursor/claude マルチプロバイダ並列）を wrap する薄いラッパー。

```bash
oe-refute --claim <doc> [--lanes N] [--rubric consensus|exploration]
```

- `--claim <doc>` … 反証対象の claim doc（markdown）。**必須**。先頭の YAML frontmatter（`---`〜`---`）から `claim`（必須・1 行）/ `rubric`（`exploration`|`consensus`）/ `domain`（任意・無視可）のみパース。閉じ `---` 以降の **body は不透明**に反証レーンへ素通し（ドメイン非依存）
- `--lanes N` … 反証レーン数（既定 `2`）。`2`→`codex,cursor` / `3`→`codex,claude,cursor`。それ以外は exit 2
- `--rubric R` … 評価レンズ。`exploration`（breadth=軸5 / grounding=軸3 を第一級）/ `consensus`（問題認識/方針/リスク）。指定時 frontmatter を上書き。どちらも無ければ `exploration`
- 出力（stdout JSON）: `{verdict, reason, rubric, lanes, dissent:[{lane,verdict,note}], output_dir, audit_id}`。`output_dir` は so-compare 生出力のパス（確定時証跡のアンカー用）、`audit_id` は ULID
- 集約は **conservative**: 1 レーンでも material に refuted → 全体 refuted。全レーン survived のときのみ survived。verdict を取れないレーンは survived 扱いにせず `error` とし、dissent に記録した上で survived 確定を阻む（保守側）
- exit: `survived`→0 / `refuted`→3（**Stage A は advisory**・JSON が正本）
- 最小 audit を `<OE_DATA_DIR|project>/audit/oe-refute.jsonl` に 1 行追記

関連 lib: `session.sh`（`oe_generate_session_id`）。バックエンド: `so-compare`（`OE_REFUTE_SO_COMPARE` で実体を上書き可）

---

## oe-delegate — 子セッション起動 + キック（親子委譲）

子 Claude を `tmux split-window` で起動し、タスク（または kickoff doc）をキック（spawn + send の合成）。

```bash
oe-delegate [-w WORKSPACE] [--kickoff <path>] [--label <#N|name>] [--claude-arg <arg>] [--] <task>
```

- `--kickoff <path>` … `"<path> を読んで進めて。"` を送り、doc のディレクトリを `--add-dir` で子に開示
- `--label <#N|name>` … registry 登録ラベル（後で `oe-send <label>` で指す）
- `--claude-arg <arg>` … 子 Claude 起動時に追加引数を渡す（repeatable）。例: `--claude-arg --permission-mode --claude-arg auto`
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

## oe-select — 宛先をインタラクティブに選んで送信

`oe-list` と同一ソースの候補から fzf（無ければ番号 read）で 1 件選び、pane id を抽出して `oe-send` へ素通しする。既定で自ペインを候補から除外する。

```bash
oe-select [--print|-p] [--no-enter] [--include-self] [--kickoff <path>] [--] [ad-hoc...]
```

- `--print`, `-p` … 選んだ pane id を stdout に出して終了（送信しない）。`message` / `--no-enter` / `--kickoff` とは併用不可。例: `target="$(oe-select -p)" && oe-send "$target" "..."`
- `--include-self` … 自ペイン（`$TMUX_PANE`）も候補に含める（既定は除外）
- `--no-enter` / `--kickoff <path>` … `oe-send` へ素通し
- `ad-hoc...` … 送信メッセージ（無ければ端末から 1 行 read）。`--kickoff` 指定時は省略可
- 選択キャンセル（ESC / Ctrl-C / 空入力）は exit 130（送信も出力もしない）

関連 lib: `delegate-registry.sh`（送信は `oe-send` 経由）

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
