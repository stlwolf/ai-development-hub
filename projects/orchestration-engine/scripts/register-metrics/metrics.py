#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""#348 応答の決定論的指標。plan v2 §4.4 の表に対応する。

方針:
- コードブロック・表・見出し・箇条書きは散文から外し、別に数える。
- 記号と体言止めは 1,000 文字あたりに正規化する（長さとの相関を切るため）。
- 機械判定が怪しいものは値と一緒に素材（第1文など）を出し、人が見られるようにする。
"""
import io, json, re, sys, unicodedata

FENCE = re.compile(r'^\s*```')
HEADING = re.compile(r'^\s{0,3}#{1,6}\s')
BULLET = re.compile(r'^\s*(?:[-*+]\s|\d+[.)]\s)')
BOLD_LABEL = re.compile(r'^\s*\*\*[^*]+\*\*[:：]?\s*$')
# コロンで終わる短い独立行は、リストを導くラベルであって文ではない。
COLON_LABEL = re.compile(r'^\s*\S[^。！？\n]{0,30}[:：]\s*$')
TABLE = re.compile(r'^\s*\|')
QUOTE = re.compile(r'^\s*>')
INLINE_CODE = re.compile(r'`[^`]*`')
ASCII_WORD = re.compile(r'[A-Za-z][A-Za-z0-9_.\-]*')
# §8 が名指しする形: 英語 + する/させる。名前か修飾語かの曖昧さが無く機械判定できる。
# 統括の読み（実例3）を受けて足した検出器。
# 強調記号: 文法の代用（接着記号）とは別物なので、混ぜずに分けて数える。
EMPHASIS = '⚠❗‼★☆🔴🚨✅❌'
# 内部識別子: ULID / tmux pane ID / 説明の無い issue 番号 / 内部状態語。
ULID_RE = re.compile(r'\b[0-9A-HJKMNP-TV-Z]{26}\b')
PANE_RE = re.compile(r'%\d{1,3}\b')
ISSUE_RE = re.compile(r'#\d{1,5}\b')
# ラベル行: 見出し記法を持たないが、句点で終わらない短い独立行。構造の代用。
LABEL_LINE = re.compile(r'^\s*\S[^。！？\n]{0,28}$')
# 使役（子にやらせる形）は統括のレジスタに固有で、owner の判断には要らない工程の実況になりやすい。
CAUS_RE = re.compile(r'させ(?:ます|ました|る|た|ず|ない|よう)')
# 内部語: この環境の中でしか通じない語。owner は会話の外にいる読者なので、定義なしで使うと読めない。
# 環境固有の一覧であり、増やせる形にしておく（統括の読み2）。
JARGON = ['no_opportunity', 'NK item', '負の知見', 'HG', 'gate 2', 'gate 3', 'gate 4',
          'SO レーン', '弱 SO', '強 SO', 'oe-', '巡', '撃つ', '撃て', '撃っ',
          'ヘッジ', 'landing', 'trigger', 'malform', '昇格の印', '蒸留', 'brief', 'board',
          'Omitted', 'reparent', 'takeover', '駆動層', '固定節']

# 拡張リスト（実例4 由来・**参考列のみ**。採用ゲートには使わない = HG-3 裁定1）。
# 指摘された文から語を拾って足すと、その文に合わせた物差しになるので、凍結側とは分けて持つ。
JARGON_EXT = JARGON + ['収集窓', 'keep-coding-instructions', '観察2件', '合図',
                       '窓を閉じ', '崩れていたら', '前の腕', '後の腕', '切る点',
                       '母集団', 'フラグ率', '閾値', '凍結', '対比', 'fork']
EN_SURU = re.compile(r'[A-Za-z][A-Za-z0-9_\-]{1,}\s*(?:する|される|させる|した|します|しない|しま)')
HIRAGANA = lambda ch: '぀' <= ch <= 'ゟ'

# 作業対象の名前（§8 が英語のままでよいと認めている側）。descriptive な英語だけを残すための allowlist。
ALLOW = {w.lower() for w in """
git github pr prs issue issues commit commits branch branches merge rebase worktree wt sync
hook hooks skill skills agent agents claude code opus fable sonnet haiku cursor codex cli sdk
json yaml toml md markdown url uri id ids api apis http https ok ng ci cd repo repos
oe oe-send oe-refute oe-tree oe-review oe-select so hg nk ulid uuid tsv csv
system prompt settings config style styles output input tool tools session sessions
canonical rules rule readme catalog docs doc episode plan decision discussion kickoff
concise readable-conversation keep-coding-instructions outputstyle model models token tokens
headless main conversation subagent env path bash python shell script scripts
""".split()}

def split_layers(text):
    """行を種別に分ける。散文だけを返し、他は数える。"""
    lines = text.split('\n')
    prose, headings, bullets, tables, quotes, code = [], 0, 0, 0, 0, 0
    bullet_txt, table_txt, heading_txt = [], [], []
    in_code = False
    for ln in lines:
        if FENCE.match(ln):
            in_code = not in_code
            code += 1
            continue
        if in_code:
            code += 1
            continue
        if HEADING.match(ln):
            headings += 1
            heading_txt.append(ln)
            continue
        if TABLE.match(ln):
            tables += 1
            table_txt.append(ln)
            continue
        if BULLET.match(ln):
            bullets += 1
            bullet_txt.append(ln)
            continue
        if QUOTE.match(ln):
            quotes += 1
            continue
        if COLON_LABEL.match(ln) and not ln.strip().startswith(('-','*','|','>')):
            headings += 1
            heading_txt.append(ln)
            continue
        if BOLD_LABEL.match(ln):
            headings += 1
            heading_txt.append(ln)
            continue
        prose.append(ln)
    return ('\n'.join(prose),
            dict(headings=headings, bullets=bullets,
                 table_lines=tables, quote_lines=quotes, code_lines=code),
            dict(prose='\n'.join(prose), bullets='\n'.join(bullet_txt),
                 tables='\n'.join(table_txt), headings='\n'.join(heading_txt)))

def sentences(prose):
    s = re.split(r'(?<=[。！？])', prose)
    return [x.strip() for x in s if x.strip()]

def _strip_tail(s):
    """文末の飾りを落として、述語の最後の文字を露出させる。
    落とすもの: 句点 / 末尾の括弧注記（（file:line）など）/ 末尾のインラインコード / 閉じ引用。
    順序に依存しないよう、変化しなくなるまで繰り返す。"""
    x = s.rstrip()
    prev = None
    while x != prev:
        prev = x
        x = re.sub(r'[。！？…\s]+$', '', x)
        x = re.sub(r'（[^（）]*）$', '', x)
        x = re.sub(r'\([^()]*\)$', '', x)
        x = re.sub(r'`[^`]*`$', '', x)
        x = re.sub(r'[」』”"\'\]】〕]+$', '', x)
        x = re.sub(r'[*_~]+$', '', x)        # markdown の強調記号
    return x

def taigen_dome(sents):
    """体言止め = 文末の飾りを落とした後、最後の文字がひらがなでないもの。
    散文の文だけを対象にする（箇条書きと表と見出しは呼び出し側で除外済み）。"""
    n, examples = 0, []
    for s in sents:
        t = _strip_tail(s)
        if not t:
            continue
        if not HIRAGANA(t[-1]):
            n += 1
            if len(examples) < 3:
                examples.append(s[-50:])
    return n, examples

def english_modifiers(prose):
    """散文中の ASCII 語のうち、作業対象の名前 allowlist に無いもの。§8 の近似。"""
    p = INLINE_CODE.sub(' ', prose)          # インラインコードは名前なので外す
    p = re.sub(r'[「『][^」』]*[」』]', ' ', p)   # 引用は本人の語彙ではないので外す
    words = ASCII_WORD.findall(p)
    out = [w for w in words if w.lower().strip('.-_') not in ALLOW]
    return len(out), out[:10]

def first_sentence_type(sents, prompt_head=''):
    """第1文の型（4値）を機械的に当てにいく。怪しいものは unknown を返し素材を添える。"""
    if not sents:
        return 'empty', ''
    s = sents[0]
    if re.search(r'(調査しました|確認しました|読みました|見ました|調べました|実行しました|やりました|入っていません|していません)', s):
        return 'narration', s
    if re.search(r'(まず|これから|ここでは|以下|次のとおり|説明します|整理します|見ていきます)', s):
        return 'preamble', s
    if re.search(r'(進めます|調べます|確認します|検討します|考えます|作ります|やっていきます)$', s.rstrip('。')):
        return 'plan', s
    if re.search(r'(推奨|結論|採る|べき|が良い|がよい|を選ぶ|で足りる|だけです|ありません|です|ます)', s):
        return 'conclusion', s
    # 問題の言い換え: プロンプト冒頭と 16 文字以上の共通部分があり、断定が無い
    for n in range(len(prompt_head), 15, -1):
        if prompt_head[:n] and prompt_head[:n] in s:
            return 'restate', s
    return 'unknown', s

def options_count(text):
    return len(re.findall(r'(?:^|\s)(?:案|選択肢|候補|Option)\s*[0-9A-Za-zＡ-Ｚ一二三四五]', text))

def measure(path, prompt_head='', required=None):
    text = io.open(path, encoding='utf-8').read()
    total = len(text)
    prose, layers, layer_txt = split_layers(text)
    sents = sentences(prose)
    prose_chars = len(prose)
    tg, tg_ex = taigen_dome(sents)
    GLUE = '→＝★〔〕'
    glue = sum(prose.count(c) for c in GLUE)
    glue_bullets = sum(layer_txt['bullets'].count(c) for c in GLUE)
    glue_tables = sum(layer_txt['tables'].count(c) for c in GLUE)
    nakaguro = prose.count('・')
    en, en_ex = english_modifiers(prose)
    en_suru_n = len(EN_SURU.findall(prose))
    emph = sum(text.count(c) for c in EMPHASIS)
    ulid_n = len(ULID_RE.findall(text))
    pane_n = len(PANE_RE.findall(text))
    issue_n = len(ISSUE_RE.findall(text))
    caus_n = len(CAUS_RE.findall(text))
    jargon_hits = [w for w in JARGON if w in text]
    jargon_n = sum(text.count(w) for w in JARGON)
    jargon2_hits = [w for w in JARGON_EXT if w in text]
    jargon2_n = sum(text.count(w) for w in JARGON_EXT)
    past_report_n = sum(1 for x in sents if x.rstrip().endswith(('ました。', 'ています。', 'ていました。')))
    label_n = sum(1 for ln in layer_txt['prose'].split('\n')
                  if ln.strip() and LABEL_LINE.match(ln) and not ln.strip().startswith(('-', '*', '|', '>')))
    fst, fst_src = first_sentence_type(sents, prompt_head)
    k = max(prose_chars, 1) / 1000.0
    m = dict(
        file=path.split('/')[-1],
        total_chars=total,
        prose_chars=prose_chars,
        sentences=len(sents),
        glue_per1k=round(glue / k, 2), glue_raw=glue,
        glue_bullets=glue_bullets, glue_tables=glue_tables,
        glue_all_raw=glue + glue_bullets + glue_tables,
        glue_all_per1k=round((glue + glue_bullets + glue_tables) / max(total,1) * 1000, 2),
        prose_ratio=round(prose_chars / max(total, 1), 3),
        nakaguro_per1k=round(nakaguro / k, 2), nakaguro_raw=nakaguro,
        taigen_per1k=round(tg / k, 2), taigen_raw=tg,
        english_per1k=round(en / k, 2), english_raw=en,
        en_suru_raw=en_suru_n, en_suru_per1k=round(en_suru_n / k, 2),
        emphasis_raw=emph, emphasis_per1k=round(emph / max(total, 1) * 1000, 2),
        internal_ids=ulid_n + pane_n + issue_n,
        ulid_n=ulid_n, pane_n=pane_n, issue_n=issue_n,
        causative_raw=caus_n, causative_per1k=round(caus_n / k, 2),
        jargon_raw=jargon_n, jargon_kinds=len(jargon_hits),
        jargon2_raw=jargon2_n, jargon2_kinds=len(jargon2_hits),
        jargon_per1k=round(jargon_n / max(total, 1) * 1000, 2),
        past_report_sent=past_report_n,
        label_lines=label_n,
        structure_lines=layers['headings'] + label_n,
        headings_per1k=round(layers['headings'] / max(total,1) * 1000, 2),
        first_sentence_type=fst,
        throat_clearing=1 if fst in ('narration', 'preamble', 'plan') else 0,
        options=options_count(text),
        **layers,
    )
    if required:
        missing = [r['name'] for r in required
                   if not any(alt in text for alt in r['any_of'])]
        m['required_missing'] = len(missing)
        m['required_total'] = len(required)
        m['required_missing_items'] = missing
    m['_first_sentence'] = fst_src[:80]
    m['_taigen_examples'] = tg_ex
    m['_english_examples'] = en_ex
    return m

if __name__ == '__main__':
    prompt_head = ''
    args = sys.argv[1:]
    if args and args[0] == '--prompt':
        prompt_head = io.open(args[1], encoding='utf-8').read().strip()[:40]
        args = args[2:]
    req = None
    if args and args[0] == '--required':
        import json as _j
        spec = _j.load(io.open(args[1], encoding='utf-8'))
        req = spec[args[2]]
        args = args[3:]
    rows = [measure(p, prompt_head, req) for p in args]
    print(json.dumps(rows, ensure_ascii=False, indent=2))
