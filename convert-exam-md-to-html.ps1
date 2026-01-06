<#
.SYNOPSIS
  Markdown を単一HTMLに変換します（問題カード + 解答開閉）。

.DESCRIPTION
  PowerShell の `ConvertFrom-Markdown` を利用してMarkdownをHTMLに変換し、
  `template.html` に差し込んで1つのHTMLファイルとして出力します。

  - `## 問題N：...` を問題カードとして扱います。
  - `${...}` は入力欄に置換します（出力HTML内でプレースホルダーを入力欄に変換）。

.PARAMETER InputMd
  入力Markdownファイルのパス。

.PARAMETER OutputHtml
  出力HTMLファイルのパス（省略すると InputMd と同名で拡張子 .html）。

.PARAMETER Subtitle
  ヘッダー直下に表示するサブタイトル（任意）。

.PARAMETER TemplateHtml
  HTMLテンプレートのパス（省略するとスクリプトと同じ場所の `template.html`）。

.EXAMPLE
  pwsh -File .\\convert-exam-md-to-html.ps1 -InputMd .\\examples\\sample.md -OutputHtml .\\dist\\sample.html
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$InputMd,

  [string]$OutputHtml,

  [string]$Subtitle = "",

  [string]$TemplateHtml
)

$ErrorActionPreference = 'Stop'

function Get-TitleFromMarkdown([string]$markdown, [string]$fallback) {
  $match = [regex]::Match($markdown, '(?m)^#\s+(.+)$')
  if ($match.Success) { return $match.Groups[1].Value.Trim() }
  return $fallback
}

function Split-ByH2([string]$markdown) {
  $lines = $markdown -split "`r?`n"
  $sections = @()

  $currentHeading = $null
  $currentLines = New-Object System.Collections.Generic.List[string]

  foreach ($line in $lines) {
    $m = [regex]::Match($line, '^##\s+(.+)$')
    if ($m.Success) {
      if ($null -ne $currentHeading) {
        $sections += [pscustomobject]@{
          Heading = $currentHeading
          Body    = ($currentLines -join "`n").Trim()
        }
      }

      $currentHeading = $m.Groups[1].Value.Trim()
      $currentLines = New-Object System.Collections.Generic.List[string]
      continue
    }

    if ($null -ne $currentHeading) {
      $currentLines.Add($line)
    }
  }

  if ($null -ne $currentHeading) {
    $sections += [pscustomobject]@{
      Heading = $currentHeading
      Body    = ($currentLines -join "`n").Trim()
    }
  }

  return $sections
}

function Get-QuestionMeta([string]$h2Heading) {
  $match = [regex]::Match($h2Heading, '^問題\s*([0-9]+)\s*[:：]\s*(.+)$')
  if (-not $match.Success) { return $null }

  return [pscustomobject]@{
    Number = [int]$match.Groups[1].Value
    Title  = $match.Groups[2].Value.Trim()
  }
}

function Remove-HrLines([string]$text) {
  return ($text -replace '(?m)^\s*---\s*$\r?\n?', '').Trim()
}

function Find-FirstIndex([string[]]$lines, [scriptblock]$predicate) {
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if (& $predicate $lines[$i]) { return $i }
  }
  return -1
}

function Normalize-TipText([string]$tipText) {
  $text = $tipText.Trim()

  # `** 本試験では**: ...` のようなパターン（見出し部分を太字にしている場合）
  $text = $text -replace '^\s*\*\*.*?本試験では.*?\*\*\s*[:：]\s*', ''

  # `本試験では：...` のようなパターン
  $text = $text -replace '^\s*本試験では\s*[:：]\s*', ''

  return $text.Trim()
}
function Split-QuestionBody([string]$body) {
  $clean = Remove-HrLines $body
  $lines = $clean -split "`r?`n"
  $tipIndex = Find-FirstIndex $lines {
    param($line)
    ($line.Trim() -match '^(?:\*\*.*?本試験では.*?\*\*\s*[:：]|本試験では\s*[:：])')
  }
  $scoringIndex = Find-FirstIndex $lines { param($line) $line.Trim().StartsWith('### 採点基準') }
  $answerIndex = Find-FirstIndex $lines { param($line) ($line.Trim().StartsWith('### 解答') -or $line.Trim().StartsWith('### 解答・解説')) }

  $cutPoints = @($tipIndex, $scoringIndex, $answerIndex) | Where-Object { $_ -ge 0 }
  $statementEnd = if ($cutPoints.Count -gt 0) { ($cutPoints | Measure-Object -Minimum).Minimum } else { $lines.Count }

  $statementLines = if ($statementEnd -gt 0) { $lines[0..($statementEnd - 1)] } else { @() }
  $statement = ($statementLines -join "`n").Trim()

  $tip = ''
  if ($tipIndex -ge 0) {
    $tipEndCandidates = @($scoringIndex, $answerIndex) | Where-Object { $_ -ge 0 -and $_ -gt $tipIndex }
    $tipEnd = if ($tipEndCandidates.Count -gt 0) { ($tipEndCandidates | Measure-Object -Minimum).Minimum } else { $lines.Count }

    $tipLines = $lines[$tipIndex..($tipEnd - 1)]
    $tipText = ($tipLines -join "`n").Trim()
    $tip = Normalize-TipText $tipText
  }

  $scoringTitle = ''
  $scoringBody = ''
  if ($scoringIndex -ge 0) {
    $scoringEnd = if ($answerIndex -ge 0 -and $answerIndex -gt $scoringIndex) { $answerIndex } else { $lines.Count }
    $scoringTitle = ($lines[$scoringIndex].Trim() -replace '^###\s+', '').Trim()

    $start = $scoringIndex + 1
    $end = $scoringEnd - 1
    $scoringLines = if ($start -le $end) { $lines[$start..$end] } else { @() }
    $scoringBody = ($scoringLines -join "`n").Trim()
  }

  $answerBody = ''
  if ($answerIndex -ge 0) {
    $answerBody = ($lines[$answerIndex..($lines.Count - 1)] -join "`n").Trim()
  }

  return [pscustomobject]@{
    Statement    = $statement
    Tip          = $tip
    ScoringTitle = $scoringTitle
    ScoringBody  = $scoringBody
    AnswerBody   = $answerBody
  }
}

function Escape-Html([string]$value) {
  $result = $value.Replace('&', '&amp;')
  $result = $result.Replace('<', '&lt;')
  $result = $result.Replace('>', '&gt;')
  $result = $result.Replace('"', '&quot;')
  $result = $result.Replace("'", '&#39;')
  return $result
}

function Escape-HtmlText([string]$value) {
  return (Escape-Html $value) -replace "`r?`n", '<br>'
}

function Convert-MdToHtml([string]$markdown) {
  if ([string]::IsNullOrWhiteSpace($markdown)) { return '' }
  return (ConvertFrom-Markdown -InputObject $markdown).Html.Trim()
}

function Normalize-CodeLanguages([string]$html) {
  $html = $html -replace 'language-js\b', 'language-javascript'
  $html = $html -replace 'language-html\b', 'language-markup'
  $html = $html -replace 'language-xml\b', 'language-markup'
  return $html
}

function Wrap-CodeBlocks([string]$html, [string]$wrapperClass) {
  $pattern = '(?s)<pre><code( class="[^"]+")?>(.*?)</code></pre>'
  return [regex]::Replace($html, $pattern, {
      param($m)
      $cls = $m.Groups[1].Value
      $code = $m.Groups[2].Value
      return ('<div class="{0}"><pre><code{1}>{2}</code></pre></div>' -f $wrapperClass, $cls, $code)
    })
}

function Replace-Blanks([string]$html) {
  return [regex]::Replace($html, '\$\{[^}]*\}', '__BLANK__')
}

function Strongify-Labels([string]$html) {
  $html = $html -replace '<p>HTML:</p>', '<p><strong>HTML:</strong></p>'
  $html = $html -replace '<p>CSS:</p>', '<p><strong>CSS:</strong></p>'
  $html = $html -replace '<p>JavaScript:</p>', '<p><strong>JavaScript:</strong></p>'
  return $html
}

function Adjust-AnswerHeadings([string]$html) {
  $html = $html -replace '<h3>解答</h3>', '<h4>解答：</h4>'
  $html = $html -replace '<h3>解説</h3>', '<h4>解説</h4>'
  return $html
}

function Build-NavItems([int]$count) {
  if ($count -le 0) { return '' }
  $items = for ($i = 1; $i -le $count; $i++) {
    $active = if ($i -eq 1) { ' active' } else { '' }
    ('<div class="nav-item{0}">{1}</div>' -f $active, $i)
  }
  return ($items -join "`n")
}

function Build-QuestionCards($questions) {
  $cards = @()

  for ($i = 0; $i -lt $questions.Count; $i++) {
    $q = $questions[$i]
    $parts = Split-QuestionBody $q.Body

    $statementHtml = Convert-MdToHtml $parts.Statement
    $statementHtml = Normalize-CodeLanguages $statementHtml
    $statementHtml = Wrap-CodeBlocks $statementHtml 'code-block'
    $statementHtml = Replace-Blanks $statementHtml
    $statementHtml = Strongify-Labels $statementHtml

    $tipHtml = ''
    if (-not [string]::IsNullOrWhiteSpace($parts.Tip)) {
      $tipInnerHtml = Convert-MdToHtml $parts.Tip
      $tipInnerHtml = Normalize-CodeLanguages $tipInnerHtml
      $tipInnerHtml = Wrap-CodeBlocks $tipInnerHtml 'code-block'
      $tipInnerHtml = Replace-Blanks $tipInnerHtml
      $tipHtml = ('<div class="highlight-tip"><h4>本試験では</h4>{0}</div>' -f $tipInnerHtml)
    }

    $scoringListHtml = Convert-MdToHtml $parts.ScoringBody
    $scoringListHtml = Normalize-CodeLanguages $scoringListHtml
    $scoringListHtml = Wrap-CodeBlocks $scoringListHtml 'code-block'
    $scoringListHtml = Replace-Blanks $scoringListHtml

    $scoringTitle = if ([string]::IsNullOrWhiteSpace($parts.ScoringTitle)) { '採点基準・配点' } else { $parts.ScoringTitle }
    $scoringHtml = ('<div class="scoring-criteria"><h4>{0}</h4>{1}</div>' -f (Escape-Html $scoringTitle), $scoringListHtml)

    $answerInnerHtml = Convert-MdToHtml $parts.AnswerBody
    $answerInnerHtml = Normalize-CodeLanguages $answerInnerHtml
    $answerInnerHtml = Wrap-CodeBlocks $answerInnerHtml 'code-example'
    $answerInnerHtml = Replace-Blanks $answerInnerHtml
    $answerInnerHtml = Strongify-Labels $answerInnerHtml
    $answerInnerHtml = Adjust-AnswerHeadings $answerInnerHtml

    $answerHtml = @"
<div class="answer-section">
  <input type="checkbox" id="answer$($i + 1)" class="answer-toggle">
  <label for="answer$($i + 1)" class="answer-label">解答・解説を見る</label>
  <div class="answer-content">
$answerInnerHtml
  </div>
</div>
"@

    $cards += @"
<div class="question-card" id="question$($i + 1)">
  <h2><span class="question-number">$($i + 1)</span>$(Escape-Html $q.Meta.Title)</h2>
$statementHtml
$tipHtml
$scoringHtml
$answerHtml
</div>
"@
  }

  return ($cards -join "`n`n")
}

$inputPath = (Resolve-Path -Path $InputMd).Path
if (-not (Test-Path -Path $inputPath)) { throw "入力ファイルが見つかりません: $InputMd" }

if ([string]::IsNullOrWhiteSpace($OutputHtml)) {
  $OutputHtml = [System.IO.Path]::ChangeExtension($inputPath, '.html')
}

$templatePath = if ([string]::IsNullOrWhiteSpace($TemplateHtml)) {
  Join-Path $PSScriptRoot 'template.html'
}
else {
  (Resolve-Path -Path $TemplateHtml).Path
}
if (-not (Test-Path $templatePath)) { throw "テンプレートが見つかりません: $templatePath" }
$template = Get-Content -Raw -Path $templatePath -Encoding UTF8
$md = Get-Content -Raw -Path $inputPath -Encoding UTF8

$titleFallback = [System.IO.Path]::GetFileNameWithoutExtension($inputPath)
$title = Get-TitleFromMarkdown $md $titleFallback

$sections = Split-ByH2 $md
$questions = @()
foreach ($section in $sections) {
  $meta = Get-QuestionMeta $section.Heading
  if ($null -ne $meta) {
    $questions += [pscustomobject]@{ Meta = $meta; Body = $section.Body }
  }
}

if ($questions.Count -eq 0) {
  throw "'## 問題N：...' の形式の見出しが見つかりませんでした。"
}

$nav = Build-NavItems $questions.Count
$cards = Build-QuestionCards $questions

$subtitleBlock = if ([string]::IsNullOrWhiteSpace($Subtitle)) { '' } else { ('<p class="subtitle">{0}</p>' -f (Escape-Html $Subtitle)) }

$html = $template.Replace('{{TITLE}}', (Escape-Html $title))
$html = $html.Replace('{{SUBTITLE_BLOCK}}', $subtitleBlock)
$html = $html.Replace('{{NAV_ITEMS}}', $nav)
$html = $html.Replace('{{QUESTION_CARDS}}', $cards)

$outDir = Split-Path -Parent $OutputHtml
if (-not [string]::IsNullOrWhiteSpace($outDir)) {
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

Set-Content -Path $OutputHtml -Value $html -Encoding UTF8
Write-Host "出力しました: $OutputHtml"
