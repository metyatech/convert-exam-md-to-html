# md-to-html（PowerShell）

PowerShell 標準の `ConvertFrom-Markdown` を使って、Markdown を「問題カード + 採点基準 + 解答開閉」の単一HTMLに変換するツールです。

## 特徴

- 依存なし（PowerShell 7+ のみ）
- 入力はMarkdownなので修正が簡単
- デザインは `template.html` を編集するだけで変更可能
- `${...}` を空欄（下線）表示に置換可能

## 必要なもの

- PowerShell 7 以上（`pwsh`）

## 使い方

```powershell
pwsh -File .\convert-exam-md-to-html.ps1 `
  -InputMd .\examples\sample.md `
  -OutputHtml .\dist\sample.html `
  -Subtitle "サブタイトル（任意）"
```

- `-OutputHtml` を省略すると、入力ファイルと同じ場所に拡張子 `.html` で出力します。
- `dist` のような出力先フォルダが無い場合は自動で作成します。

## 入力Markdownの前提（最低限）

- タイトルは `# ...`
- 各問題は `## 問題N：...`（例：`## 問題1：クリックで…`）
- 各問題の中に、必要に応じて以下を含めます
  - `本試験では：...`（あるいは `**本試験では**: ...` の形式でもOK）
  - `### 採点基準・配点`
  - `### 解答` / `### 解説`

## デザイン（template）

- 見た目は `template.html` の CSS と HTML を編集して調整します。

## セキュリティ上の注意

- このツールは、入力Markdownを PowerShell 標準の `ConvertFrom-Markdown` に渡して HTML に変換します（このツール自体はHTMLの無害化/サニタイズを行いません）。
- `ConvertFrom-Markdown` は内部でMarkdownエンジン（Markdig）を使っており、Markdown内に生のHTML（例：`<script>...</script>` や `<img onerror="...">`）を書いた場合、それが出力HTMLにそのまま含まれます。
  - つまり、このツールは「入力に含まれる生HTMLを除去しない」ので、入力が信頼できないと危険です。
- そのため「不特定多数が編集したMarkdown」や「外部から受け取ったMarkdown」をこのツールでHTML化してブラウザで開くと、意図しないスクリプト実行（XSS相当）が起こり得ます。
  - 公開・配布用途では、入力を信頼できるものに限定するか、別途HTMLサニタイズ（危険なタグ/属性の除去）を行ってください。

## ライセンス

`LICENSE` を参照してください。
