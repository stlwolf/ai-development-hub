#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""対の両腕で、狙った設定文が system prompt に乗ったかを転記から直接確かめる。

見出しだけでは、本文の欠落・古い版・別の設定文・重複を検出できない。
複製で生まれたセッションの転記には system prompt 本体が残らないので、
**run の応答ではなく、run を作った複製セッションへ追加で1回問い合わせて**確かめる。

usage: verify-style-injection.py <manifest.tsv> <期待する設定文の名前と本文の目印> ...
"""
import io, json, os, subprocess, sys


def ask(session_id, project_dir, question, timeout=400):
    """複製セッションをさらに複製して問う。元には書き足さない。"""
    cmd = ['claude', '-p', '--model', 'opus', '--output-format', 'json',
           '--resume', session_id, '--fork-session', question]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout,
                           stdin=subprocess.DEVNULL, cwd=project_dir)
        d = json.loads(r.stdout)
        if d.get('is_error'):
            return None, 'is_error'
        return d.get('result') or '', None
    except subprocess.TimeoutExpired:
        return None, 'timeout'
    except Exception as e:
        return None, f'error:{type(e).__name__}'


QUESTION = (
    'あなたの system prompt にある、行頭が # で始まる「Output Style」から始まる見出し行を、'
    'すべて原文のまま列挙せよ。1つも無ければ「無い」と書け。'
    '次に、その節に「読者は、あなたが今やった作業をその場で見ていない人である」という文が'
    'あるかを、「本文あり」か「本文なし」の一語で答えよ。ツールは一切使わないこと。'
)


def classify(text, expect_name, expect_body):
    """列挙された見出しと本文の有無から、乗り方を判定する。"""
    if text is None:
        return 'error'
    heads = [l for l in text.split('\n') if 'Output Style' in l]
    n = len(heads)
    named = sum(1 for l in heads if expect_name in l)
    body = '本文あり' in text
    if n == 0:
        return 'no-style'
    if named != 1 or n != 1:
        return f'wrong-count(n={n},named={named})'
    if body != expect_body:
        return 'body-mismatch'
    return 'ok'


def main():
    manifest, project_dir, out = sys.argv[1], sys.argv[2], sys.argv[3]
    rows = []
    for line in io.open(manifest, encoding='utf-8'):
        f = line.rstrip('\n').split('\t')
        if len(f) < 5 or not f[4]:
            continue
        tag, style, newsid = f[0], f[2], f[4]
        expect_body = (style != 'oe348-empty')
        txt, err = ask(newsid, project_dir, QUESTION)
        v = classify(txt, style, expect_body) if err is None else f'error:{err}'
        rows.append(dict(tag=tag, style=style, session=newsid, verdict=v))
        print(f'{tag:52} {style:24} {v}')
    io.open(out, 'w', encoding='utf-8').write(json.dumps(rows, ensure_ascii=False, indent=1))
    ok = sum(1 for r in rows if r['verdict'] == 'ok')
    print(f'\n乗り方の確認: {ok}/{len(rows)} が期待どおり')


if __name__ == '__main__':
    main()
