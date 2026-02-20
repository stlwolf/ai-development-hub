# raw-logs/

4層モデルの「層3: 生ログ」の保管場所。

SpecStoryの自動出力や Export Transcript のMarkdownをここにコピーして一時保管する。抽出（要約・エピソード化・ADR昇格）が終わったら破棄してよい。

## 運用

1. SpecStory出力（`.specstory/history/*.md`）のうち本プロジェクトに関連するものをここにコピー
2. エピソード記録や ADR を書く際の一次資料として参照
3. 抽出が終わったら削除可能（TTL: 30〜90日目安）

## 注意

- `.gitignore` でgit追跡対象外
- 容量が大きい（1スレッドで数百KB〜1MB超）ため、リポジトリには含めない
