canonical/output-styles/ — Claude Code の output style の正本を置く場所

ここに置いた .md ファイルが sync で ~/.claude/output-styles/ へ symlink として
配られる。このファイル自身は .md ではないので配られない。

ファイルの形（公式仕様）:

    ---
    name: スタイル名（省略するとファイル名になる）
    description: /config の一覧に出る説明
    keep-coding-instructions: true か false（既定は false）
    ---

    ここに本文（システムプロンプトへ足される指示）

有効化について。どのスタイルを使うかは outputStyle という設定キーで決まるが、
この鍵は hub の宣言（canonical/claude/settings.harness.json）に入れていない。
issue #348 の採用判定を待っている状態で、判定が出るまでは owner が手で決める。

注意が2つある。

配布先に同じ名前の通常ファイルが既にある場合、sync は上書きせずに警告して飛ばす。
手で置いたスタイルを勝手に置き換えないためである。正本から配りたいときは、
配布先の通常ファイルを先にどけること。

output style はセッションの開始時に一度だけ読まれる。配った直後に走っている
セッションには効かない。/clear するか、新しいセッションから効く。
