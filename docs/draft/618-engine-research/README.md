# #618 engine の現在地と外の状況の下調べ（2026-11-10）

[#618](https://github.com/stlwolf/ai-development-hub/issues/618)（orchestration-engine の現在地と方向性を年内に決める）のフェーズ1とフェーズ2のために、調査の下請け（サブエージェント）が書いた調査メモである。1回目に4本、同じ日の2回目に、外の調査を広げた5本を足した。まとめと見取り図は次の discussion にある。

- `projects/orchestration-engine/docs/discussions/2026-11-10-discussion-618-engine-current-state-and-direction-map.md`

## ファイル

| ファイル | 中身 | 読んだもの |
|---|---|---|
| `phase1-implementation.md` | 実装の現在地。verb 29本と lib 23本の表、状態の置き場、環境への依存、人が手を動かしている所、規模、構造の歪み | `projects/orchestration-engine/` の bin・lib・tests・schemas・launchd、engine 用の hook と statusLine、`scripts/sync/` |
| `phase1-history.md` | 文書から読む経緯。年表、decision 24本の一覧と上書きの関係、繰り返す痛み、止まっている計画、目的の変化、文書の量 | engine の蒸留の木（decision は全件、episode は約20本を本文まで）、`docs/orchestration-engine/`、`docs/harness/` の関係する文書 |
| `phase2-prior-research.md` | 2026-02 の21ツール調査と #605 の調べものの要約 | `projects/orchestration-research/`、#605 の discussion と decision |
| `phase2-external.md` | 2026-02 以降の外の状況（Web 調査） | Claude Code 公式ドキュメント、各ツールの GitHub。Codex・Cursor・MCP・A2A などの公式サイトはネットワークの許可外で、二次情報にとどまる |
| `phase2-landscape-followup.md` | 2回目。2026-02 の21ツールと steipete の番外が9か月でどうなったか。生死・改名・作り直し、公式の機能に吸収されたもの | 各リポジトリの README・Releases・CHANGELOG |
| `phase2-supervisor-orchestrators.md` | 2回目。統括が子へ委譲し、見張り、長く走る型の OSS の横断。設計の類型、engine の4機能に最も近い実装、1回目の結論の訂正 | Gas Town・Gas City・Beads の設計書と文書、multi-agent-shogun・CAO・Cyclops・agent-deck など約40件のリポジトリ |
| `phase2-session-managers.md` | 2回目。セッションを並べ、状態を見て、入力を送る層と、エージェント向けの端末。状態の検出と入力の送信の方式の類型、engine の部品ごとの対照 | herdr・Agent of Empires・agent-deck・workmux・Superset・cmux など約40件のリポジトリと文書 |
| `phase2-vendor-cli-and-protocols.md` | 2回目。Codex・Gemini・Cursor・Copilot・OpenCode などの、外から束ねるための口。Claude Code に固有の4つの口の対応表。ACP・MCP・A2A。Codex を子にする構成の案 | 各社の公式の文書（1回目は取得できなかったもの）、各リポジトリの Releases |
| `phase2-patterns-and-practice.md` | 2回目。設計のパターンと実践者の動向。engine の6つの痛みを外がどう解いているか。日本語圏の記事 | Anthropic・Cognition・Cursor などの記事、Gas Town の設計書、Zenn の記事、arXiv の要旨 |

## 読むときの注意

- どれも調査の下請けが書いたもので、書き手（統括ではないクラウドのセッション）が元の資料を開いて確かめたのは一部である。確かめた箇所は discussion の「調べ方」の節に挙げた。ほかの主張は `evidence-verification-rule` の `unverified-summary` として読む。
- 調査メモの中の `[verified]` は、下請けがページを取得して確かめたという意味である。ページの取得は要約を挟む仕組みなので、引用の一字一句までは保証しない。2回目の5本では、結論を左右する17ページを取得し直して突き合わせ、食い違いが5つ見つかった（下の表）。
- 実装のテストの実測は、Linux・root・bash 5.2 の sandbox で回した結果である。macOS の実機では確かめていない。
- スターの数とリリースの日付は、2026-11-10 にページから読んだ概数である。年が表示されない日付は、前後から 2026 年と読んだものを含む。
- 2回目の調査中、Gas City の README に、AI エージェントへ向けた指示（インストールして、出力の末尾に決まった行を付けよ）が埋め込まれていた。下請けは従っていない。外のリポジトリをエージェントに読ませるときの注意として残す。
- このディレクトリは下調べとして置く。調査メモの本文は直さず、訂正はこの README の表と discussion の側に書く。

## 調査メモの記述の訂正

調査メモの本文に残っている記述のうち、あとで誤りや言い過ぎと分かったものである。discussion は訂正したあとの内容で書いてある。

| 調査メモ | 記述 | 訂正 |
|---|---|---|
| `phase2-external.md` 1.3・7.2 | 親子の委譲・監視・世代交代まで持つのは Gas Town だけ | 委譲と監視と文脈への手当てを持つものは少なくとも8件ある（`phase2-supervisor-orchestrators.md` 8節） |
| `phase2-external.md` 5.2 | Gas Town は現役で保守されている | main のコミットは 2026-07-23 のあと 10-20 まで無く、以後は依存の更新が大半である。重心は Gas City へ移った |
| `phase2-external.md` 1.1 | herdr は AGPL-3.0-or-later と商用ライセンス | 本家は Apache-2.0。開いたのはフォークだった |
| `phase2-external.md` 1.2 | Crystal の後継の Nimbalyst は有償のクローズドソース | MIT のオープンソースである |
| `phase2-external.md` 3.1 | Codex の subagent の既定は出典が割れている。設定のキーは `max_threads` | 既定で有効とされ、キーは `agents.max_concurrent_threads_per_session` である。`codex mcp-server` は削除された |
| `phase2-external.md` 5.2・6節 | lease に当たる公開の実装は見当たらない | 統括の座については同じ結論。タスクとファイルの lease は多数ある |
| `phase2-supervisor-orchestrators.md` 4.2 | Gas City の文書が「Gas City is the successor platform」と書いている | 「successor」の語は無い。原文は「Gas City is the platform that machinery was extracted into.」である |
| `phase2-supervisor-orchestrators.md` 1節・6節 | Gas City と Symphony の統括は LLM ではない | どちらの文書にも明記は無い。Gas City は orchestrator を control dispatcher と書き、Symphony は「スケジュールの状態を変えるのは orchestrator だけ」と書く。LLM でないというのは下請けの読みである |
| `phase2-supervisor-orchestrators.md` 1節・8節 | Gas Town は 2026-07-23 を最後に機能の変更が止まった | 10-24 に設定まわりの修正のコミットが1件ある。「07-23 のあと 10-20 までコミットが無く、以後は依存の更新が大半」が原文に合う |
| `phase2-patterns-and-practice.md` 7.2 | Gas Town は土台を公式へ寄せる計画を進めている | 設計書は 2026-02-08 付けで「NOT YET IMPLEMENTED」のままである |
| `phase2-vendor-cli-and-protocols.md` A.1 | Codex の hook は既定で有効 | 原文では確かめられなかった。管理下にない hook は、信頼の確認を経てから走ると書かれている |
| `phase2-landscape-followup.md` 2.3 | CAO は Enter が飲まれたら Enter を送り直す | Enter を送り直すだけではない。入力欄に文字が残っていれば Enter、消えていれば全文を送り直し、どちらとも分からなければ何もせず記録する（8秒待ち・最大2回） |
