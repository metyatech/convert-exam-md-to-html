# サンプル問題集

このファイルは `convert-exam-md-to-html` の動作確認用サンプルです。

---

## 問題1：クリックでテキストを変更

次のHTMLに対して、要件を満たすような JavaScript を作成せよ。

HTML:

```html
<button id="btn1">クリック</button>
<p id="msg">未実行</p>
```

要件：
ボタンをクリックすると、`#msg` のテキストが「実行済み」になる。

本試験では：セレクタや表示文字が変わります（例：`#msg` や `innerText`）。

### 採点基準・配点（16点）

- ボタン要素を取得できている：3点
- テキスト要素を取得できている：3点
- クリックイベントを設定する記述がある：5点
- テキストを変更する記述がある：3点
- 要件通り動作する：2点

### 解答

JavaScript:

```js
let btn1Yoso = document.querySelector('#btn1');
let msgYoso = document.querySelector('#msg');

btn1Yoso.addEventListener('click', function() {
  msgYoso.innerText = '実行済み';
});
```

### 解説

- `querySelector` で要素を取得する
- `addEventListener('click', ...)` でクリック時の処理を書く
- `innerText` で文字を変更する

---

## 問題2：CSS穴埋め（空欄表示の例）

次のCSSの空欄を埋めよ。

```css
.box {
  opacity: ${0};
}
```

本試験では：空欄の数や、埋めるプロパティが変わります（例：`opacity`）。

### 採点基準・配点（4点）

- 正答：4点

### 解答

- `${0}` は `0`

### 解説

`opacity` は透明度です。`0` は完全に透明、`1` は完全に不透明です。
