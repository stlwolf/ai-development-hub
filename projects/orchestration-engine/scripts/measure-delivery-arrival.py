#!/usr/bin/env python3
"""配送の到達を、受け手側の一次記録から測る（read-only・#299）。

これは **transport を替えたときの前後比較に使う測定器**である。前後比較は同一の測定器で
なければ成立しないので、方法をコードとして残す。書き直すと方法が変わって比較できなくなる。

由来: #293 / #299 の調査で作った `.oe/measure-delivery-confirm.py`（作業層・gitignored）を
そのまま持ち込んだもの。**アルゴリズムは変更していない**（変えると過去の測定値と比較できない）。

## 何を測る道具か

送信ログ（`oe-events.jsonl` の `message_sent`）1 件ごとに、その本文が**受け手のセッションに
1 ターンとして取り込まれた形跡**が受け手側の transcript に在るかを突き合わせる。

`oe-selfcheck` / `oe-undelivered` が使う受領印（`prompt_received`・#299 P1）とは**別の経路**である。
使い分けはこう。

- 受領印は **#299 以降の送信にしか付かない**（前向き・ペイン束縛が機構で保証される）。
- 本測定器は **transcript が残っている限り過去へ遡れる**（後ろ向き・transport の変更をまたげる）。

したがって **transport 変更の「前」のベースラインを取れるのは本測定器だけ**である。

## 方法（最も厳しい条件・この4つを外さない）

  1. 送信ログ  ~/.claude/state/oe-events.jsonl の message_sent
  2. 到達印    全 transcript の user ターンのうち promptSource=="typed" のものだけ
               （tool_result や貼り付けを除外する。viewer の出力に preview が載るため、
                 これを外すと oe-activity を叩いただけで「到達」に化ける）
  3. 宛先束縛  ~/.claude/state/oe-heartbeat/<session_id>.json の pane で
               「意図した宛先ペイン自身のセッション」に限定する
  4. 排他割当  1 つの user ターンは 1 通の送信にしか使わない（再送の相乗りを断つ）

## 再実行の仕方

```bash
python3 projects/orchestration-engine/scripts/measure-delivery-arrival.py
OE_MEASURE_CUT=2026-09-01 python3 .../measure-delivery-arrival.py   # 起点を変える

# 保存しておいた過去のログに対して同じ方法で測り直す（前後比較の「前」を再現する）
OE_MEASURE_EVENTS=/path/oe-events.jsonl \
OE_MEASURE_TRANSCRIPTS=/path/projects \
OE_MEASURE_HEARTBEAT=/path/oe-heartbeat \
  python3 .../measure-delivery-arrival.py
```

入力先の差し替えは**突合の方法を変えない**。前後比較のために同じ方法を保存済みログへ当てるための口である。

`OE_MEASURE_CUT` は集計の起点（この日付以降の送信だけを母集団にする）。既定の `2026-07-03` は
#299 の調査時に決めた値で、**それより前は受け手側の記録が送信数に足りず分母として使えない**
ことを実測して切った境界である（2026-07-02 は送信 39 件に対し typed ターンが全コーパスで 20 件）。
**新しく前後比較を取るときは、比較したい期間の起点を明示して渡すこと。** 既定のまま使うと
過去の期間が混ざる。

## 結果は環境依存である（そのまま他所へ持ち出さない）

- **transcript の保持期間に依存する。** 消えた期間は「未確認」に化けるので、保持窓の外を
  母集団に入れてはならない。どこまで遡れるかは `oe-selfcheck` の `retention-horizon` で見る。
- **heartbeat sidecar（pane↔session の橋）に依存する。** 橋が無いセッション宛ての送信は
  母集団から落ちる（出力の「橋で解決できず除外」に件数が出る）。
- **同じ本文を再送すると 1 件の到達に複数の送信が当たりうる。** 排他割当で緩和しているが、
  完全には潰せない。
- **本文が短い送信は母集団に入らない。** 正規化後 KEY_LEN（50）文字未満は突合鍵を作れないので、
  到達確認にも未確認にも入らない。短い kick がここへ落ちる。**件数は出力の
  「本文が短く突合鍵を作れない」に出す**（黙って消さない）。率を読むときはこの件数を併せて見ること。
- **`delivery_signal` の値ごとに分けて出す。** ログに実在する値を全部列挙するので、
  #299 P0 で入った `unknown` も出る。値を決め打ちすると新しい regime が丸ごと見えなくなる。
- **Claude Code の transcript JSONL 形式に依存する。** 形式が変われば黙って 0 件になりうるので、
  `oe-selfcheck` の `transcript-format` を併せて見ること。

## 秘匿の境界（実行前に読む）

`~/.claude/projects/` 配下の**全プロジェクト**の transcript を走査する。他の作業の本文が
処理対象に入るということである。**本スクリプトは本文を出力しない**（件数と割合だけを出す）が、
出力を貼るときは件数のみに留め、突合鍵（本文の先頭）を外へ出さないこと。

## 読み方の注意

- 「到達確認」= その本文が宛先セッションに 1 ターンとして取り込まれた、まで。
  読まれた・実行された、ではない。
- 「未確認」は「未着」ではない。突合の取りこぼしを含む点推定である。
"""
import glob
import json
import os
import re
import sys
from collections import defaultdict
from datetime import datetime

# 入力先は env で差し替えられる。**突合の方法は変えない** — 差し替えは、保存しておいた過去の
# ログに対して同じ方法で測り直せるようにするためのものである（前後比較の「前」を再現するのに要る）。
EVENTS = os.environ.get(
    "OE_MEASURE_EVENTS", os.path.expanduser("~/.claude/state/oe-events.jsonl"))
PROJ = os.environ.get(
    "OE_MEASURE_TRANSCRIPTS", os.path.expanduser("~/.claude/projects"))
BEAT = os.environ.get(
    "OE_MEASURE_HEARTBEAT", os.path.expanduser("~/.claude/state/oe-heartbeat"))
KEY_LEN = 50
WIN_BEFORE, WIN_AFTER = 60, 3600
# 受信側の記録が送信数に足りている期間だけを母集団にする（plan §2.4）。
CUT = os.environ.get("OE_MEASURE_CUT", "2026-07-03")

_ctrl = re.compile(r"[\x00-\x08\x0b-\x1f\x7f]")
_ws = re.compile(r"\s+")


def norm(s):
    return _ws.sub(" ", _ctrl.sub(" ", s)).strip()


def key(s):
    n = norm(s)
    return n[:KEY_LEN] if len(n) >= KEY_LEN else None


def epoch(s):
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
    except Exception:
        return None


def load_bridge():
    """session_id -> pane（heartbeat sidecar）。最新の pane しか持たない点が限界。"""
    b = {}
    for f in glob.glob(os.path.join(BEAT, "*.json")):
        try:
            pane = (json.load(open(f)) or {}).get("pane", "")
        except Exception:
            continue
        if pane:
            b[os.path.basename(f)[:-5]] = pane
    return b


def load_turns():
    """typed な user ターンだけを (epoch, session_id, key, uuid) で返す。"""
    out = []
    for path in glob.glob(os.path.join(PROJ, "**", "*.jsonl"), recursive=True):
        try:
            fh = open(path, errors="replace")
        except Exception:
            continue
        with fh:
            for line in fh:
                if '"type":"user"' not in line:
                    continue
                try:
                    o = json.loads(line)
                except Exception:
                    continue
                if o.get("type") != "user" or o.get("promptSource") != "typed":
                    continue
                c = (o.get("message") or {}).get("content")
                if isinstance(c, str):
                    text = c
                elif isinstance(c, list):
                    parts = [b.get("text", "") for b in c
                             if isinstance(b, dict) and b.get("type") == "text"]
                    if not parts:
                        continue
                    text = " ".join(parts)
                else:
                    continue
                k, e = key(text), epoch(o.get("timestamp", ""))
                if k and e is not None:
                    out.append((e, o.get("sessionId", ""), k, o.get("uuid", "")))
    return out


def main():
    bridge = load_bridge()
    panes = set(bridge.values())
    by_key = defaultdict(list)
    for t in load_turns():
        by_key[t[2]].append(t)

    msgs = []
    dropped_short = defaultdict(int)
    with open(EVENTS) as fh:
        for line in fh:
            try:
                o = json.loads(line)
            except Exception:
                continue
            if o.get("type") != "message_sent" or o["ts"][:10] < CUT:
                continue
            prev = o.get("preview", "")
            if prev.endswith("…"):
                prev = prev[:-1]
            k = key(prev)
            if not k:
                # 正規化後 KEY_LEN 未満は突合鍵を作れないので母集団に入れられない。
                # **黙って落とさず数える。** 短い kick がここに入る（実装SO claude レーン指摘）。
                dropped_short[o.get("delivery_signal", "none")] += 1
                continue
            o["_k"], o["_e"] = k, epoch(o["ts"])
            msgs.append(o)
    msgs.sort(key=lambda m: m["_e"])

    claimed, res = set(), defaultdict(lambda: defaultdict(int))
    for m in msgs:
        to, sig = m["to"]["pane"], m.get("delivery_signal", "none")
        if to not in panes:
            res[sig]["宛先を橋で解決できない"] += 1
            continue
        res[sig]["母集団"] += 1
        cands = [t for t in by_key.get(m["_k"], [])
                 if bridge.get(t[1]) == to
                 and -WIN_BEFORE <= (t[0] - m["_e"]) <= WIN_AFTER
                 and t[3] not in claimed]
        if cands:
            best = min(cands, key=lambda t: abs(t[0] - m["_e"]))
            claimed.add(best[3])
            res[sig]["到達確認"] += 1
        else:
            res[sig]["未確認"] += 1

    print(f"=== 到達確認（{CUT} 以降・typed 限定・宛先束縛・排他割当）===")
    # **ログに実在する値を全部出す。** 初版は ("suspected_miss", "none") を決め打ちしていたので、
    # #299 P0 で導入した `unknown` が出力に一切現れず、前後比較の「後」が丸ごと見えなかった
    # （実装SO claude レーン指摘・実測で再現）。決め打ちをやめて実在値を列挙する。
    seen_sigs = sorted(set(res) | set(dropped_short))
    if not seen_sigs:
        print("  対象なし（この起点以降に message_sent が無い）")
    for sig in seen_sigs:
        rr = res[sig]
        n = rr["母集団"]
        drop = dropped_short[sig]
        if not n:
            print(f"  {sig:15s} 母集団 0"
                  f"  [橋で解決できず除外={rr['宛先を橋で解決できない']}"
                  f" / 本文が短く突合鍵を作れない={drop}]")
            continue
        print(f"  {sig:15s} 母集団={n:4d}  到達確認={rr['到達確認']:4d} "
              f"({100 * rr['到達確認'] / n:5.1f}%)  未確認={rr['未確認']:4d} "
              f"({100 * rr['未確認'] / n:5.1f}%)  [橋で解決できず除外={rr['宛先を橋で解決できない']}"
              f" / 本文が短く突合鍵を作れない={drop}]")
    print("\n注意: 「未確認」は未着ではない。突合の取りこぼしを含む点推定である。")
    print("      「本文が短く突合鍵を作れない」は到達確認にも未確認にも入っていない"
          f"（正規化後 {KEY_LEN} 文字未満。短い kick がここへ落ちる）。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
