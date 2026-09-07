#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""#348 の腕別集計。転記（JSONL）から母集団を作り、前 / 後 v1 / 後 v2 に分けてフラグ率を出す。

腕はセッションの開始時刻で決まる。切る点は2つある（既定は #348 の値）。
  cut1 = style を有効にした時刻   / cut2 = style を直した時刻
主たる比較は 前 対 後 v2 である。

集計の主単位はセッションである（同一セッション内の応答は独立でないため）。
応答単位も併記する。

usage:
  aggregate-arms.py <project-dir> [--cut1 ISO8601] [--cut2 ISO8601]
                    [--exclude-ids FILE] [--out DIR]
"""
import argparse, io, json, os, statistics as st, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from metrics import measure                                    # noqa: E402
from corpus import classify_session, responses, layer_from_request  # noqa: E402

# HG-2 で凍結した閾値。後の腕を見てから動かさない。
FROZEN = [
    ('強調記号', 'emphasis_raw', 1),
    ('内部語', 'jargon_kinds', 4),
    ('文の数', 'sentences', 37),
    ('英語語', 'english_per1k', 26.52),
]
# 参考列（HG-3 裁定1）。採用ゲートには使わない。
REFERENCE = [('内部語（拡張）', 'jargon2_kinds', 4)]

DEFAULT_CUT1 = '2026-09-05T12:05:39Z'
DEFAULT_CUT2 = '2026-09-05T16:31:20Z'


def session_start(path):
    """転記の最初の行の timestamp をセッションの開始時刻とする。"""
    for line in io.open(path, encoding='utf-8', errors='replace'):
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue
        ts = d.get('timestamp')
        if ts:
            return ts
    return ''


def arm_of(start_ts, cut1, cut2):
    if not start_ts:
        return '不明'
    if start_ts < cut1:
        return '前'
    if start_ts < cut2:
        return '後 v1'
    return '後 v2'


def flags(row, spec):
    return [name for name, key, thr in spec if (row.get(key) or 0) >= thr]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('project_dir')
    ap.add_argument('--cut1', default=DEFAULT_CUT1)
    ap.add_argument('--cut2', default=DEFAULT_CUT2)
    ap.add_argument('--exclude-ids', default=None,
                    help='除外するセッション ID の一覧（1行1件。fork 由来など）')
    ap.add_argument('--out', default=None)
    ap.add_argument('--min-chars', type=int, default=400)
    a = ap.parse_args()

    excl = set()
    if a.exclude_ids and os.path.exists(a.exclude_ids):
        excl = {x.strip() for x in io.open(a.exclude_ids, encoding='utf-8') if x.strip()}

    rows, sess_meta, dropped = [], {}, {}
    for fn in sorted(os.listdir(a.project_dir)):
        if not fn.endswith('.jsonl'):
            continue
        sid = fn[:-6]
        if sid in excl:
            dropped['fork 由来'] = dropped.get('fork 由来', 0) + 1
            continue
        p = os.path.join(a.project_dir, fn)
        verdict = classify_session(p)
        if verdict != 'kept':
            dropped[verdict] = dropped.get(verdict, 0) + 1
            continue
        start = session_start(p)
        arm = arm_of(start, a.cut1, a.cut2)
        sess_meta[sid[:8]] = dict(start=start, arm=arm)
        for r in responses(p, a.min_chars):
            m = measure_text(r['text'])
            m.update(sess=sid[:8], arm=arm, model=r.get('model', '?'),
                     ts=r.get('ts', ''), idx=r.get('idx'),
                     layer=layer_from_request(r.get('request', ''), r['text']))
            m['_flags'] = flags(m, FROZEN)
            m['_ref_flags'] = flags(m, REFERENCE)
            rows.append(m)

    report(rows, sess_meta, dropped, a)


def measure_text(text):
    """measure() は file を取るので、一時 file を経由せずに済むよう薄く包む。"""
    import tempfile
    fd, tmp = tempfile.mkstemp(suffix='.txt')
    os.close(fd)
    try:
        io.open(tmp, 'w', encoding='utf-8').write(text)
        return measure(tmp)
    finally:
        os.unlink(tmp)


def report(rows, sess_meta, dropped, a):
    print('=== 除外 ===')
    for k, v in sorted(dropped.items()):
        print(f'  {k}: {v} セッション')
    print(f'\n=== 腕ごと（切る点 cut1={a.cut1} / cut2={a.cut2}） ===')
    for arm in ['前', '後 v1', '後 v2', '不明']:
        rs = [r for r in rows if r['arm'] == arm]
        ss = sorted({r['sess'] for r in rs})
        if not rs:
            print(f'-- {arm}: 応答 0 件')
            continue
        n_f = sum(1 for r in rs if r['_flags'])
        per = {}
        for r in rs:
            per.setdefault(r['sess'], [0, 0])
            per[r['sess']][1] += 1
            if r['_flags']:
                per[r['sess']][0] += 1
        rates = [x / y for x, y in per.values()]
        n_ref = sum(1 for r in rs if r['_ref_flags'])
        print(f'-- {arm}: セッション {len(ss)} / 応答 {len(rs)}')
        print(f'   フラグ率  応答単位 {100*n_f/len(rs):5.1f}%  '
              f'セッション単位 中央値 {100*st.median(rates):5.1f}%  平均 {100*st.mean(rates):5.1f}%')
        print(f'   参考列（拡張リスト） 応答単位 {100*n_ref/len(rs):5.1f}%')
        for name, key, thr in FROZEN:
            v = [r[key] for r in rs]
            hit = sum(1 for x in v if x >= thr)
            print(f'   {name:8} 中央値 {st.median(v):8.2f}  発火 {hit:4}/{len(rs)}')
    if a.out:
        os.makedirs(a.out, exist_ok=True)
        slim = [{k: v for k, v in r.items() if not k.startswith('_')
                 and k not in ('file',)} for r in rows]
        io.open(os.path.join(a.out, 'arms-metrics.json'), 'w', encoding='utf-8').write(
            json.dumps(slim, ensure_ascii=False, indent=1))
        io.open(os.path.join(a.out, 'arms-sessions.json'), 'w', encoding='utf-8').write(
            json.dumps(sess_meta, ensure_ascii=False, indent=1))
        print(f'\n数値のみを {a.out} に書いた（応答本文は書かない）。')


if __name__ == '__main__':
    main()
