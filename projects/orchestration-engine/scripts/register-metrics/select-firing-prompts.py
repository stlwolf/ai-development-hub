#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""凍結した主指標が発火した応答を母集団から探し、それを生んだ発話を fork の題として選ぶ。

無作為に選ぶと baseline がどの軸でも閾値に届かず、対の比較が検定不能になる（R-4 の失敗）。
軸ごとに最低本数を確保する形で選ぶ。

usage: select-firing-prompts.py <project-dir> [--cut ISO8601] [--per-axis 3]
                                [--max 15] [--out DIR] [--exclude-ids FILE]
"""
import argparse, io, json, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from metrics import measure                                  # noqa: E402
from corpus import classify_session, responses               # noqa: E402
from aggregate_shim import session_start                     # noqa: E402

FROZEN = [
    ('強調記号', 'emphasis_raw', 1),
    ('内部語', 'jargon_kinds', 4),
    ('文の数', 'sentences', 37),
    ('英語語', 'english_per1k', 26.52),
]
DEFAULT_CUT = '2026-09-05T12:05:39Z'

# 題に使えない発話。skill の読み込み・ツールの出力・パスだけの行を除く。
# **子からの中継は除かない。** 内部語と英語語は、中継に応答した文脈でしか発火しないことが
# 実測で分かった（内部語は発火 14 件のうち 12 件が中継文脈）。中継を除くと病理の在る文脈が
# 母集団から落ちる。入力が中継でも、応答は owner の端末に描かれる面なので対象である。
UNUSABLE = re.compile(r'^Base directory for this skill|^<|^/Users/|^#\s')
# 文脈の種別を記録する（判定では分けて見る）。
RELAY = re.compile(r'\[oe:|file: \.oe/|oe-send|^#\d+\s|^Step \d|^報告|統括|委譲子')


def measure_text(text):
    import tempfile
    fd, tmp = tempfile.mkstemp(suffix='.txt')
    os.close(fd)
    try:
        io.open(tmp, 'w', encoding='utf-8').write(text)
        return measure(tmp)
    finally:
        os.unlink(tmp)


def fired(m):
    return [(name, key, thr, m.get(key)) for name, key, thr in FROZEN
            if (m.get(key) or 0) >= thr]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('project_dir')
    ap.add_argument('--cut', default=DEFAULT_CUT)
    ap.add_argument('--per-axis', type=int, default=3)
    ap.add_argument('--max', type=int, default=15)
    ap.add_argument('--out', default=None)
    ap.add_argument('--exclude-ids', default=None)
    a = ap.parse_args()

    excl = set()
    if a.exclude_ids and os.path.exists(a.exclude_ids):
        excl = {x.strip() for x in io.open(a.exclude_ids, encoding='utf-8') if x.strip()}

    cands = []
    for fn in sorted(os.listdir(a.project_dir)):
        if not fn.endswith('.jsonl'):
            continue
        sid = fn[:-6]
        if sid in excl:
            continue
        p = os.path.join(a.project_dir, fn)
        if classify_session(p) != 'kept':
            continue
        if session_start(p) >= a.cut:      # 前の腕だけを対象にする
            continue
        for r in responses(p, 400):
            req = (r.get('request') or '').strip()
            # 長さの上限は題として現実的な範囲に置く。全文を送るので、
            # 200 字で切られた版より上限を上げる（#348 R-6 の欠陥への対処）。
            if not req or UNUSABLE.search(req[:200]) or not (15 <= len(req) <= 2000):
                continue
            ctx = '中継' if RELAY.search(req[:300]) else 'owner 発話'
            m = measure_text(r['text'])
            f = fired(m)
            if not f:
                continue
            cands.append(dict(sess=sid[:8], full_sid=sid, idx=r['idx'], request=req, ctx=ctx,
                              axes=[dict(axis=n, key=k, thr=t, value=v) for n, k, t, v in f],
                              resp_chars=m['total_chars']))

    by_axis = {n: [c for c in cands if any(x['axis'] == n for x in c['axes'])]
               for n, _, _ in [(n, k, t) for n, k, t in FROZEN]}
    print('=== 軸ごとの候補数（前の腕・題として使える発話があるものだけ） ===')
    for n, _, _ in FROZEN:
        print(f'  {n:8} {len(by_axis[n]):3} 組')

    picked, seen = [], set()
    dropped_axes = []
    for n, _, _ in FROZEN:
        pool = [c for c in by_axis[n] if (c['sess'], c['idx']) not in seen]
        pool.sort(key=lambda c: -max(x['value'] for x in c['axes'] if x['axis'] == n))
        if len(by_axis[n]) < a.per_axis:
            dropped_axes.append((n, len(by_axis[n])))
            continue
        for c in pool[:a.per_axis]:
            seen.add((c['sess'], c['idx']))
            c['selected_for'] = n
            picked.append(c)
    # 余りがあれば発火軸数の多い順に足す
    rest = [c for c in cands if (c['sess'], c['idx']) not in seen]
    rest.sort(key=lambda c: -len(c['axes']))
    for c in rest:
        if len(picked) >= a.max:
            break
        seen.add((c['sess'], c['idx']))
        c['selected_for'] = '追加'
        picked.append(c)

    print(f'\n=== 選んだ題 {len(picked)} 組 ===')
    for i, c in enumerate(picked):
        ax = ' / '.join(f"{x['axis']}={x['value']}(閾値{x['thr']})" for x in c['axes'])
        print(f"  q{i:02d} [{c['selected_for']}/{c['ctx']}] {c['sess']} #{c['idx']} {ax}")
        print(f"       発話: {c['request'][:60]}")
    if dropped_axes:
        print('\n=== 検定対象から外す軸（母集団に十分な発火が無い） ===')
        for n, cnt in dropped_axes:
            print(f'  {n}: 候補 {cnt} 組（最低 {a.per_axis} 組に届かない）')

    if a.out:
        os.makedirs(a.out, exist_ok=True)
        io.open(os.path.join(a.out, 'firing-prompts.json'), 'w', encoding='utf-8').write(
            json.dumps(dict(cut=a.cut, per_axis=a.per_axis,
                            axis_candidates={n: len(by_axis[n]) for n, _, _ in FROZEN},
                            dropped_axes=[dict(axis=n, candidates=c) for n, c in dropped_axes],
                            picked=picked), ensure_ascii=False, indent=1))
        os.makedirs(os.path.join(a.out, 'prompts'), exist_ok=True)
        for i, c in enumerate(picked):
            # **題は発話の全文を書く。** 切り詰めた版を書くと、モデルが切れた質問に答える。
            io.open(os.path.join(a.out, 'prompts', f'q{i:02d}.txt'), 'w',
                    encoding='utf-8').write(c['request'])
        # 送った題が元の発話と同じ長さかを、書いた直後に検査する。
        bad = [f'q{i:02d}' for i, c in enumerate(picked)
               if len(io.open(os.path.join(a.out, 'prompts', f'q{i:02d}.txt'),
                              encoding='utf-8').read()) != len(c['request'])]
        if bad:
            print(f'題が元の発話と長さが違う: {bad}', file=sys.stderr)
            raise SystemExit(2)
        print('題の長さは元の発話と一致した（切り詰めなし）')
        print(f'\n書いた: {a.out}/firing-prompts.json と prompts/')


if __name__ == '__main__':
    main()
