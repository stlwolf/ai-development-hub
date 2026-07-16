---
id: 01KXN8ZE7FG193BRRJE7K92KHZ
title: 4層ドキュメント文体（register）の他モデル理解度実測（段階1調査）
date: 2026-07-16
type: episode
status: stable
related:
  - "#263"
---

# episode — #263 文体（register）評価・段階1調査

## Context / なぜ（自己完結）

4層ドキュメントの規約は4層のうち文体（register）だけが無規約で、生成モデルの癖（記号圧縮・体言止め断片文・括弧入れ子・高密度1行）が事実上の標準になっている。canonical は codex/cursor に現に sync 配布されているため「他モデルが読めるか」は仮定でなく実問題。段階1（本 episode）は規範を書かず、Evidence First で「現行文体は他モデルに可搬か」を実測する調査。規範化の判断（段階2）は owner が本調査の材料を見て別途行う。

- 発行 brief: `.oe/brief-263-register-eval.md`（cockpit 統括・作業層）
- scope 正本: `gh issue view 263`
- tier（暫定）: heavy（外部レビューレーンを意図起動 / 主成果が知見 / プローブ設計という非自明な設計判断）。closure は計測完了後・マージ前に確定する。

## 作業ログ（随時追記）

### 2026-07-16 着手

- worktree 自作: `docs/#263_register-eval`（`branch-naming`）。
- 本 episode 枠を作成（着手時のプレ処理）。
- 作業層ディレクトリ `.oe/`（worktree 内・gitignored）を作成。プローブ・正解キー・プレーン化版の置き場。

### 2026-07-16 Step 0 smoke（PASS）

5レーン全て生存・model 識別子を確定（極小プロンプト「1+1」＝全レーン正答「2」）:

| レーン | 解決モデル | 応答 | 秒 |
|--------|-----------|------|----|
| so: codex | `gpt-5.6-sol`（brief 想定「5.6 系」と一致） | 2 | 13 |
| so: claude | 既定 Opus・fresh `-p`（対照群） | 2 | 8 |
| so: cursor | `composer-2.5` | 2 | 107 |
| arena: gemini | `gemini-3.1-pro` | 2 | 13 |
| arena: grok | `cursor-grok-4.5-high`（Cursor Grok 4.5） | 2 | 13 |

- arena-compare は `cursor-agent`（Cursor CLI）をラップしており、Gemini / grok も Cursor のプロキシ経由で叩いている（native Gemini CLI ではない）。所見としてノートに記録する。
- 非致命の警告2件（codex 側・出力に影響なし・正答）: (1) shell snapshot 検証エラー（`~/.codex/shell_snapshots/*.tmp` の構文エラー）(2) starship session log の PermissionDenied。ブロッカーではない。
- cursor/composer-2.5 が他レーンの約8倍遅い（107秒 vs 13秒）。大 doc 読解プロンプトでは 240 秒タイムアウトに接近しうる。brief 既知の「cursor timeout 対策＝`-w` 参照・doc 単位で小さく投げる」を計測時に徹底する。
- brief では arena=`--dry-run` のみ指定だったが、dry-run は auth / 生存を確認できず Step 0 の目的（各レーン生存確認）を満たさないため、極小の実走を1本追加した（+2 レーン呼び出し・軽微）。親へ surface 済み。
- smoke 出力: `tmp/so-smoke/`・`tmp/arena-smoke/`（作業層）。

### 2026-07-16 プローブ+正解キー+プレーン化版 設計（完了・STOP）

- 4 target doc を全読（doc1 episode-259 / doc2 discussion-succession / doc3 board / doc4 spec §11+§13）。
- 評価入力を `.oe/eval-inputs/` に frozen（verbatim・再現性のため）。**全 eval-input を client 識別子スキャン済み＝CLEAN**。
  - doc1/doc3 は「全プローブを含む代表的抜粋」に絞った（プレーン化との apples-to-apples ＋ 内容 drift 低減 ＋ cursor timeout 回避）。doc2/doc4 は全文/節抜粋 verbatim。
- **client 識別子の発見（surface）**: FULL board は L26/L57/L58/L68 に `attelu`/`biz-infra` を含む → 外部クラウドレーンへ raw 送信は漏洩。対処＝識別子を含まない抜粋に限定（scan CLEAN）。full board 使用時は sanitize 要（親判断・OPEN #1）。
- プローブ = doc あたり5問（内容プローブ＝原文＋プレーン化両方 / 記号プローブ＝原文のみ）。正解キーに grounding（行/節）を付与し親 fact-check 可能に。
- プレーン化版（doc1-plain / doc3-plain）作成: 内容不変・文体のみ（完全文化・記号解除・参照明示）。probe-critical facts の残存を機械確認済み。長さ増の交絡は caveat 明示（OPEN #8）。
- 採点ルーブリック（○/△/×）+ 誤読の型分類（SYM/FRAG/NEST/REF/DROP/HALLUC/CONF）を定義。
- 計測マトリクス確定: 6 doc版 ×（so-compare 1 + arena-compare 1）= 12 呼び出し ＝ 30 レーン結果（brief 想定と一致）。
- 成果物: 正本 `.oe/probes-and-keys.md`（設計・キー・コマンド・OPEN 8点）+ `.oe/eval-inputs/*`。
- **STOP: 親へ報告**（親が正解キーを fact-check・OPEN 8点を判断 → 承認後に計測実走）。計測は未実行。

（以降、親承認後に計測 → 採点 → ノート `docs/research/2026-07-16-register-portability-eval.md` → SO → PR → closure を追記）

### 2026-07-16 計測実走 + 採点 + ノート + 弱SO（owner 承認後）

- owner 承認（正解キー fact-check PASS・OPEN 8点判断・doc3-P3 pane ID は evidence 表限定）を受けて計測実走。
- プロンプト6本生成（`.oe/probes/`・同一テンプレ）→ 12ハーネス呼び出し（sequential・cursor-agent プロキシ過負荷回避）＝30レーン結果。全 exit 0・timeout なし・非空（run ~9分）。
- 採点: 100 原文セル中 非○は5（訂正後）。内容プローブは全 register 型・全レーンで ○。非○は記号・参照プローブに集中。
- ノート作成 `docs/research/2026-07-16-register-portability-eval.md`（claim に検証状態付与）。
- **弱 impl-SO（codex/cursor・1周）がノートの material 欠陥を複数検出 → 全て反映**（下記 事実・失敗）。

## closure（gate 5・マージ前・リアルタイム＝reconstructed でない）

**tier = heavy**（トリガ: 主成果が知見〔調査〕/ 意図的に起動した外部レビュー〔計測の so-compare・arena-compare + ノートの弱 impl-SO〕/ 非自明な設計判断〔プローブ設計〕/ 実行中の方針修正〔SO が overclaim を検出しノートを大幅訂正〕/ 昇格候補あり）。

**closure gate checklist**:
- **Context / なぜ**: 冒頭 Context 節に自己完結（文体だけ無規約・自己強化ループ・他モデル未評価を Evidence First で実測）。
- **次の消費者**: (1) owner（段階2 の規範化する/しない判断の材料）(2) #256/#217（episode 品質・人間可読性軸の隣接）(3) B クラスタ〔フォーマッター系スキル調整〕(4) 再測定する調査子（設計改善6点が引き継ぎ材料）。
- **follow-up routing**:
  - 段階2（規範化）判断 → **owner**（本調査は材料提供まで）。
  - 再測定の設計改善（正解キー隔離 / 記号プローブの限定 / false-premise 独立軸 / 複数run / native Gemini / FRAG系設問追加）→ **段階2 or 別 issue で owner 判断**（ノート §段階2 に列挙）。
  - 体言止め・高密度・入れ子の register 効果 → **未検証・保留**（本測定では感度不足。段階2 の再測定対象）。
  - probes-and-keys.md の正解キー訂正 → **反映済み**（§8.5・back-propagation）。
- **status 確定**: draft → **stable**（達成度=**達成**。受け入れ基準4件〔採点マトリクス残存・可搬性の方向・誤読の型分類・段階2材料〕を満たす。ノートは SO 反映後）。
- **evidence anchor**: 採点マトリクスがノートに durable 転記済（生出力 `tmp/eval-*/` は gitignored 揮発）。SO verdict/指摘はノートと本 episode に転記。
- **SO 証跡リンク**: 計測 = `tmp/eval-{doc1..doc4,*-plain}-{so,arena}/`（揮発）。実装SO = `tmp/so-note-263/`（codex/cursor stdout・揮発）。frozen 入力 = `.oe/eval-inputs/`・`.oe/probes/`・`.oe/probes-and-keys.md`。

**事実・失敗（SO で検出され反映した点）**:
- **正解キー参照可能性（最重要交絡・自分が見落とし）**: `-w` で正解キー `.oe/probes-and-keys.md` が全レーンから読める状態だった。codex は trace で target-only を確認できたが、cursor/claude/gemini/grok は trace 不在で leakage 排除不能。→ ノート最重要 caveat に追加・再測定は workspace 外隔離。
- **doc4-P2 誤採点**: codex は偽前提の `〔§N〕` に「第N節」と意味を断定していたのに「全レーン記載なし」と誤記していた → codex を △（HALLUC）に訂正・「HALLUC 発生せず」を撤回。
- **非○セル数の取り違え**: 「4つ」（行数）を「5つ」（セル数）に訂正。
- **doc3-P4 採点非対称**: gemini △ を grok/codex と対称化して ○ に訂正。
- **[verified] タグの過剰**: 因果・一般化 claim（内容可搬の一般化・claude 対照ロジック・長さ交絡無害）を unverified-summary に降格。
- **claude 対照ロジックの弱さ**: 「claude 成功→内容の難しさでない」は弱い。内容 vs register 分離は gemini 内部（内容○/記号×△）で示すのが主・claude は補助（home-advantage 交絡）に reframe。

**決定と根拠**:
- Step0 で brief 指定の arena=`--dry-run` を極小実走に格上げ（生存確認は dry-run で不能）。
- doc1/doc3 は全文でなく代表抜粋を frozen 入力に（apples-to-apples + client 識別子回避 + cursor timeout 回避）。full board は client 識別子（別リポ名）を含むため不採用。
- 記号プローブ（notation）は原文のみ・内容プローブは原文+プレーン化。プレーン化で記号が消えるため。
- 12ハーネス呼び出しを sequential 実行（cursor-agent が so-cursor + arena-gemini + arena-grok で共有されるため並列は過負荷リスク）。

**わかったこと（W・SO 反映後の確実な範囲）**:
- 本プローブ集合では内容理解（決定・棄却理由・次アクション・status・succession チェーン・gotcha）は全 register 型・全レーンで可搬 [verified＝観測・一般化は限定]。
- 観測された register コストは狭く、in-doc 復元可能な記号（`＝ →`）decode と file:line 参照に集中し、実質 gemini（arena=Cursor プロキシ経由）に現れた。他レーンは正答。
- codex/cursor（他エージェント）は電報体・board の記号を正答＝「他モデルに shorthand で不利」仮説は記号 decode では不支持。ただし codex に偽前提 HALLUC の別問題。

**原則（Pattern / Anti-pattern）**:
- Anti-pattern: 評価器（レーン）に正解キーを workspace 内で読める状態で渡す（leakage 交絡）。→ Pattern: 正解キーは評価対象 workspace の外に隔離し、読み取り可能 file を対象入力のみに限定。
- Anti-pattern: 記号プローブに in-doc 未定義の記法（★・偽前提の 〔§N〕）を混ぜる → 「記載なし」の証拠規律や hallucination-resistance を register decode と取り違える。→ Pattern: 記号プローブは in-doc 復元可能な記号に限定し、false-premise は独立軸に分ける。
- Anti-pattern: 非観測を「無害」と読む（ceiling で感度不足のとき）。→ Pattern: 「本集合では検出されず」に留め、狙った設計で再測定。

**蒸留シグナル**: 昇格候補 = 調査ノート自体が既に committed 昇格物（`docs/research/`）。方法論（評価器への正解キー隔離・in-doc 復元可能記号への限定）は **skill/rule 昇格候補**だが、1回の調査ゆえ **なし（段階2 の再測定で再現したら検討）**。段階2 の規範化判断は owner。

**残課題**:
- 段階2 規範化判断 → owner（材料提供済み）。
- 再測定の設計改善6点 → ノート §段階2（owner/別 issue）。
- 体言止め・高密度・入れ子の効果 → 未検証・保留。

**Step 4（heavy 外部チェック）辞退**: 辞退理由 = closure の主リスク（失敗の選択的省略）は、直前の弱 impl-SO が note に対して外部から検出し、その material 欠陥を本 closure の「事実・失敗」節に全て転記済み。/ 既存チェックで覆った観点: 失敗の省略〔SO 検出→反映〕・routing〔follow-up 全件行き先あり〕・evidence anchor〔マトリクス転記済〕・back-propagation〔probes-and-keys §8.5 へ訂正反映〕。/ 未実施観点と判断: なし（closure 品質の4観点は impl-SO + 本 checklist で覆った・別 SO は重複）。
