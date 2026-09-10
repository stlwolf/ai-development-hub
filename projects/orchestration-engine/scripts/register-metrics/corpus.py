#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""#348 案A の母集団を JSONL から作る。
裁定（ruling-348-hg2）の絞り: owner が直接やり取りしたセッションの、owner 宛 main conversation の応答。
除外は3種（委譲子セッション / agent 間のレーン / 計測 probe）+ subagent の sidechain。
"""
import io, json, os, re, sys

BRIEF_KICK = re.compile(r'\.oe/brief-')
AGENT_LANE = re.compile(r'独立した反証エージェント|adversarial verifier|^#\s*設計SO|ゼロベース代替探索|純粋セカンドオピニオン|独立した読解と反論')
PROBE = re.compile(r'^\d\s*\+\s*\d\s*の答えだけ|行頭が\s*#\s*で始まる見出し行|Concise Style Active|^Step 3 完了・調査終了|system-reminder として渡されている')
DECISION = re.compile(r'判断してほしい|決めてほしい|裁定|どちらを|選んでください|承認をお願い|判断してください|決めてください|お願いしたいこと|判断してほしい点')

def first_user_text(path):
    for line in io.open(path, encoding='utf-8', errors='replace'):
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get('type') != 'user':
            continue
        m = d.get('message') or {}
        c = m.get('content')
        txt = ' '.join(x.get('text', '') for x in c
                       if isinstance(x, dict) and x.get('type') == 'text') if isinstance(c, list) else (c or '')
        txt = re.sub(r'<system-reminder>.*?</system-reminder>', '', txt, flags=re.S)
        txt = re.sub(r'<local-command-caveat>.*?</local-command-caveat>', '', txt, flags=re.S).strip()
        if txt:
            return txt
    return ''

def classify_session(path):
    t = first_user_text(path)
    if BRIEF_KICK.search(t):
        return 'excluded:委譲子セッション'
    if AGENT_LANE.search(t):
        return 'excluded:agent 間のレーン'
    if PROBE.search(t):
        return 'excluded:計測 probe'
    return 'kept'

def responses(path, min_chars=0):
    out = []
    idx = 0
    last_user = ''
    for line in io.open(path, encoding='utf-8', errors='replace'):
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get('type') == 'user' and not d.get('isSidechain'):
            mm = d.get('message') or {}
            cc = mm.get('content')
            ut = ' '.join(x.get('text', '') for x in cc
                          if isinstance(x, dict) and x.get('type') == 'text') if isinstance(cc, list) else (cc or '')
            ut = re.sub(r'<system-reminder>.*?</system-reminder>', '', ut, flags=re.S)
            ut = re.sub(r'<local-command-caveat>.*?</local-command-caveat>', '', ut, flags=re.S).strip()
            if ut:
                last_user = ut
            continue
        if d.get('type') != 'assistant' or d.get('isSidechain'):
            continue
        m = d.get('message') or {}
        if m.get('role') != 'assistant':
            continue
        parts = [c.get('text', '') for c in (m.get('content') or [])
                 if isinstance(c, dict) and c.get('type') == 'text']
        txt = '\n'.join(p for p in parts if p).strip()
        if len(txt) < min_chars:
            continue
        idx += 1
        # request は全文を持つ。題として送る用途があるので切らない。
        # 表示や記録で短くしたいときは、使う側で切る（request_excerpt を使う）。
        # 200 字で切っていた版は、fork の題がそのまま切れた質問になっていた（#348 R-6 の欠陥）。
        out.append(dict(text=txt, model=m.get('model', '?'), idx=idx,
                        request=last_user, request_excerpt=last_user[:200],
                        ts=d.get('timestamp', '')))
    return out

# 層は「直前の user 発話」で切る（介入前の変数）。応答の中身で切ると style が層を動かす。
ASK_DECISION = re.compile(r'決めて|判断|どっち|どちら|選んで|裁定|承認|いい？|どうする|進めて(いい|よい)|OK？')
ASK_INVESTIGATE = re.compile(r'調べ|確認して|見て|どうなって|なぜ|原因|状況|一覧|あったっけ|どこ')

def layer_from_request(req_text, resp_text):
    if len(resp_text) < 400:
        return 'C 短答'
    t = req_text or ''
    if ASK_DECISION.search(t):
        return 'A 判断要求'
    if ASK_INVESTIGATE.search(t):
        return 'B 調査報告'
    return 'D その他'

def build(src, out_dir, min_chars=400):
    os.makedirs(out_dir, exist_ok=True)
    kept_sess, excl = [], {}
    n = 0
    for fn in sorted(os.listdir(src)):
        if not fn.endswith('.jsonl'):
            continue
        p = os.path.join(src, fn)
        v = classify_session(p)
        if v != 'kept':
            excl[v] = excl.get(v, 0) + 1
            continue
        kept_sess.append(fn)
        for r in responses(p, min_chars):
            n += 1
            r['sess'] = fn[:8]
            r['layer'] = layer_from_request(r.get('request', ''), r['text'])
            io.open(os.path.join(out_dir, f"{fn[:8]}-{r['idx']:04d}.txt"), 'w', encoding='utf-8').write(r['text'])
            io.open(os.path.join(out_dir, f"{fn[:8]}-{r['idx']:04d}.meta.json"), 'w', encoding='utf-8').write(
                json.dumps({k: v for k, v in r.items() if k != 'text'}, ensure_ascii=False))
    return kept_sess, excl, n

if __name__ == '__main__':
    src, out = sys.argv[1], sys.argv[2]
    ks, ex, n = build(src, out)
    print('採用セッション:', len(ks))
    for k, v in sorted(ex.items()):
        print(f'  {k}: {v}')
    print('採用応答（400 文字以上）:', n)
