---
id: 01KVM14NA3H55B82AHDA07P29S
title: "#203 oe-delegate の split を親ペイン基準にする実装エピソード"
date: 2026-06-21
type: episode
status: stable
related:
  - type: implements
    ref: "#203"
  - type: relates_to
    ref: "#174"
  - type: parent
    ref: "#169"
---

# #203 oe-delegate の split を親ペイン基準にする実装エピソード

> リアルタイム追記（reconstructed ではない）。cockpit 統括セッション（`%32`）が WORKTREE
> `fix/#203_oe_delegate_parent_pane_split` で直接実装（委譲なし・最小修正）。

## コンテキスト / 動機

`oe-delegate` で子ペインを起動すると、親がいるウィンドウではなく **その時フォーカスが当たっている
ウィンドウ**に新規ペインが生えていた。複数ウィンドウ運用（例: 2 番目のウィンドウの 2nd pane に親）で、
親が別ウィンドウを active にしている間に委譲すると子が無関係なウィンドウに散り、人間が追えない。

## 根本原因（一次確認）

- `bin/oe-delegate:91` で親ペインを `PARENT_PANE="${TMUX_PANE:-}"` として捕捉・`:92` で非空検証済み。
- だが `:134` の `tmux split-window` に **`-t "$PARENT_PANE"` を渡していなかった** → `split-window` は
  既定で **アクティブ（フォーカス中）ペイン**を分割する。`-d` はフォーカス移動の抑止だけで、生える
  「場所」は `-t` が決める（無ければ active 基準）。

## 修正（最小・scope (a)）

`bin/oe-delegate:134` に `-t "$PARENT_PANE"` を追加（1 トークン）。`PARENT_PANE` は `:92` で検証済みのため
追加ガード不要。理由はインラインコメントに明記。

```bash
CHILD_PANE="$(tmux split-window -d -P -F "#{pane_id}" -t "$PARENT_PANE" -c "$WORKSPACE" "$CHILD_COMMAND")"
```

scope (b)（`#174` 同様の `--target self/parent-window/explicit` を delegate 経路にも持たせる）は
**過剰のため見送り**（issue 既定）。`oe-kick`（`#178`）は `oe-delegate` の薄いラッパーで同経路 → 自動で恩恵。

## 検証

- `test_oe_delegate.sh` 拡張: mock tmux が `split-window` の**全 argv** を `split-argv.log` に記録するよう追加
  （従来は最終引数=子コマンドのみ）。新テスト [11] で `-t %1`（親ペイン）が argv に含まれること + 子コマンド
  文字列が非破壊であることをアサート。**fix が無ければ [11] は落ちる実ガード**。
- shellcheck: `oe-delegate` / `test_oe_delegate.sh` ともに rc=0。
- テスト: **bash 3.2.57 / 5.2.37 で 20/20 PASS**（新規 [11] 含む・既存非破壊）。

## 同 PR に相乗りした doc 衛生（ユーザー承認）

bin README 乖離チェック（read-only 監査）で見つかった唯一の実質ギャップ:
- 環境変数表に `OE_SEND_SIGNAL_MISS` が欠落（oe-send の rc4 手動フォールバック分岐がこの変数依存）。
  `delegate-send.sh:210`（既定 `0`・opt-in）/ `oe-send:76-80`（rc4→手動フォールバック表示）を一次確認のうえ
  表へ 1 行追加。あわせて oe-delegate 項に親ペイン targeting の挙動を 1 行追記。
- nits（oe-refute usage の `[--]` 省略 / README:45 の「so-compare 生出力」語）は見送り。

## closure

- status: `stable`。consumer = oe-delegate / oe-kick 利用者（委譲時の子ペイン位置）。
- 実装SO（oe-review）は **スキップ**（ユーザー判断）: 既検証済み変数を既存フラグに渡す 1 トークン追加で
  欠陥面がほぼゼロ・実挙動は mock テストが担保（Minimal Scope）。
- tier: light（mock テスト + shellcheck + bash 両対応で十分）。
- Decision 昇格: **なし**。`#174` の targeting 原則（split は親基準）の delegate 経路への適用に過ぎず、新しい
  設計決定ではない。ADR 化の蒸留シグナル無し。
- routing: 親（`%32`）が直接実装 → PR → Copilot レビューで締め。
