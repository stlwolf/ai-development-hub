# SO判定のawk互換性の検証

`test_so_verdict.sh`・`test_oe_refute.sh`・`test_oe_review.sh` は、`SO_TEST_AWK` に実行ファイルの絶対パスを渡すと、そのawkを使う。各テストの一時ディレクトリにリンクを作り、呼び出すCLIにも同じawkを使わせる。指定が無ければ従来のPATHを使う。不正な指定はFATALで終了する。

macOSのシステムawkを明示して検証する:

```bash
for test in test_so_verdict.sh test_oe_refute.sh test_oe_review.sh; do
  SO_TEST_AWK=/usr/bin/awk bash "projects/orchestration-engine/tests/$test" || exit 1
done
```

`bash --version` で使用するBashも確認する。Bash 3.2と5の両方で確認する場合は、それぞれのBashから上のテストを実行する。

LinuxでMac系awkとの違いを確認する場合も、One True Awkをビルドした実行ファイルを同じ方法で指定できる:

```bash
SO_TEST_AWK=/absolute/path/to/one-true-awk bash projects/orchestration-engine/tests/test_so_verdict.sh
```

PR #606では、One True Awkの `version 20200816`（[upstream commit 9804285](https://github.com/onetrueawk/awk/tree/9804285af0866f90731a6e0ce767ab0e7b23b6c6)）をLinux上でビルドし、修正前の2種類の構文エラーと抽出テストのPASS=18・FAIL=15を再現した。これはAppleのシステムバイナリではなく、macOS実機での再確認を代替したと主張するものではない。

とくに次の形を保つ:

- awkの `-v` に行番号を渡すときは、改行でなく空白でつなぐ。
- `print` に比較・条件式を渡すときは、式全体を括弧で囲む。

既存の単独判定・重複判定のテストが、それぞれの構文を崩した場合の回帰テストも兼ねる。Linuxの既定awkだけで通ったことを、Mac系awkで通ったこととは扱わない。
