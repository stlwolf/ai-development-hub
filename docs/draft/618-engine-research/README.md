# #618 engine の現在地と外の状況の下調べ（2026-11-10）

[#618](https://github.com/stlwolf/ai-development-hub/issues/618)（orchestration-engine の現在地と方向性を年内に決める）のフェーズ1とフェーズ2のために、調査の下請け（サブエージェント）4本が書いた調査メモである。まとめと見取り図は次の discussion にある。

- `projects/orchestration-engine/docs/discussions/2026-11-10-discussion-618-engine-current-state-and-direction-map.md`

## ファイル

| ファイル | 中身 | 読んだもの |
|---|---|---|
| `phase1-implementation.md` | 実装の現在地。verb 29本と lib 23本の表、状態の置き場、環境への依存、人が手を動かしている所、規模、構造の歪み | `projects/orchestration-engine/` の bin・lib・tests・schemas・launchd、engine 用の hook と statusLine、`scripts/sync/` |
| `phase1-history.md` | 文書から読む経緯。年表、decision 24本の一覧と上書きの関係、繰り返す痛み、止まっている計画、目的の変化、文書の量 | engine の蒸留の木（decision は全件、episode は約20本を本文まで）、`docs/orchestration-engine/`、`docs/harness/` の関係する文書 |
| `phase2-prior-research.md` | 2026-02 の21ツール調査と #605 の調べものの要約 | `projects/orchestration-research/`、#605 の discussion と decision |
| `phase2-external.md` | 2026-02 以降の外の状況（Web 調査） | Claude Code 公式ドキュメント、各ツールの GitHub。Codex・Cursor・MCP・A2A などの公式サイトはネットワークの許可外で、二次情報にとどまる |

## 読むときの注意

- 4本とも調査の下請けが書いたもので、書き手（統括ではないクラウドのセッション）が元の資料を開いて確かめたのは一部である。確かめた箇所は discussion の「調べ方」の節に挙げた。ほかの主張は `evidence-verification-rule` の `unverified-summary` として読む。
- 実装のテストの実測は、Linux・root・bash 5.2 の sandbox で回した結果である。macOS の実機では確かめていない。
- このディレクトリは凍結した下調べとして置く。中身を直すときは discussion の側を直す。
