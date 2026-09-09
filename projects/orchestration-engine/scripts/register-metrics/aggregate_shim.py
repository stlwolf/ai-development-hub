# -*- coding: utf-8 -*-
"""aggregate-arms.py はハイフンを含むので import できない。共有したい関数だけを置く。"""
import io, json


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
