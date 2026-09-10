#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""実セッションの transcript から assistant のテキスト応答だけを抜く。
本リポジトリ（hub）のセッションだけを対象にする。他リポの内容は読まない。"""
import io, json, os, sys

def extract(path, min_chars=400):
    out = []
    for line in io.open(path, encoding='utf-8', errors='replace'):
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get('type') != 'assistant':
            continue
        msg = d.get('message') or {}
        if msg.get('role') != 'assistant':
            continue
        parts = [c.get('text', '') for c in (msg.get('content') or [])
                 if isinstance(c, dict) and c.get('type') == 'text']
        txt = '\n'.join(p for p in parts if p).strip()
        if len(txt) >= min_chars:
            out.append(txt)
    return out

if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    n = 0
    for fn in sorted(os.listdir(src)):
        if not fn.endswith('.jsonl'):
            continue
        for i, t in enumerate(extract(os.path.join(src, fn))):
            n += 1
            io.open(os.path.join(dst, f'real-{fn[:8]}-{i:03d}.txt'), 'w', encoding='utf-8').write(t)
    print(f'extracted {n} assistant messages')
