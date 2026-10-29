/* html-one-pager: タブの切り替え（#558）。帯・パネル・件数の最初の値は build.py が静的に描く。ここが足すのは、
   パネルの hidden とタブとパネルの印の付け外し・URL の #・キーと、隠れたタブを指すリンクで切り替えることだけである。
   タブを選ぶ処理は select の1つの入口にまとめ、押す・キー・開いたときの #・hashchange・ページの中のリンクのどれもそこを通す。
   要素は id で引き、リンクやパネルの持ち主は parentNode をたどって探す。画面の文字は書かない。
   JS が動かない表示では、すべてのパネルが縦に並び、帯のリンクがそのまま目次になる。 */
(function () {
  "use strict";
  function $(id) { return document.getElementById(id); }
  var dataEl = $("hp-tabs-data");
  if (!dataEl) { return; }
  var D;
  try { D = JSON.parse(dataEl.textContent); } catch (e) { return; }
  var tabs = (D && D.tabs) || [];
  var bar = $("hp-tabbar");
  var set = $("hp-tabset");
  if (!tabs.length || !bar || !set) { return; }
  var box = bar.parentNode;               // 上に貼り付く箱（.hp-bar）
  var root = box ? box.parentNode : null; // ページの根（.hp）。貼り付く箱の高さを CSS の変数で渡す
  var keys = tabs.map(function (t) { return t.key; });
  var isKey = Object.create(null);
  keys.forEach(function (k) { isKey[k] = true; });
  var current = null;

  // 意味の上ではタブの並びを1つにする。段は見た目と横送りの単位で、段の名前は各タブの説明として伝える。
  bar.setAttribute("data-on", "");
  set.setAttribute("role", "tablist");
  set.setAttribute("aria-label", bar.getAttribute("aria-label") || "");
  tabs.forEach(function (t) {
    var a = $("hp-tab-" + t.key);
    var p = $(t.key);
    if (!a || !p) { return; }
    a.setAttribute("role", "tab");
    a.setAttribute("aria-controls", t.key);
    var scroller = a.parentNode;
    var row = scroller ? scroller.parentNode : null;
    if (scroller) { scroller.setAttribute("role", "none"); }
    if (row) { row.setAttribute("role", "none"); }
    if (t.row !== null && t.row !== undefined) {
      a.setAttribute("aria-describedby", "hp-tabrow-" + t.row);
      var name = $("hp-tabrow-" + t.row);
      if (name) { name.setAttribute("aria-hidden", "true"); }
    }
    p.setAttribute("role", "tabpanel");
    p.setAttribute("aria-labelledby", "hp-tab-" + t.key);
    p.setAttribute("tabindex", "0");
  });

  function rect(el) {
    return el && typeof el.getBoundingClientRect === "function" ? el.getBoundingClientRect() : null;
  }
  // 貼り付く箱の高さを測り、ページの中のリンクで飛ぶ先の scroll-margin-top（page.css）に渡す。
  function measure() {
    if (root && root.style && typeof root.style.setProperty === "function" && box) {
      root.style.setProperty("--hp-bar-h", (box.offsetHeight || 0) + "px");
    }
  }
  // 選んだタブが段の外にはみ出していたら、その段だけを横に送る（ページは動かさない）。
  function reveal(a) {
    var sc = a ? a.parentNode : null;
    var r = rect(a);
    var s = rect(sc);
    if (!r || !s) { return; }
    if (r.left < s.left) { sc.scrollLeft += r.left - s.left; } else if (r.right > s.right) { sc.scrollLeft += r.right - s.right; }
  }
  function show(key) {
    current = key;
    tabs.forEach(function (t) {
      var on = t.key === key;
      var a = $("hp-tab-" + t.key);
      var p = $(t.key);
      if (a) {
        a.setAttribute("aria-selected", on ? "true" : "false");
        a.setAttribute("tabindex", on ? "0" : "-1");
      }
      if (p) { p.hidden = !on; }
    });
    reveal($("hp-tab-" + key));
  }
  // 要素がどのタブのパネルの中にあるか（パネル自身を含む）。パネルの外なら null。
  function panelOf(el) {
    for (var n = el; n; n = n.parentNode) {
      if (n.id && isKey[n.id] && $(n.id) === n) { return n.id; }
    }
    return null;
  }
  function decode(h) {
    try { return decodeURIComponent(h); } catch (e) { return h; }
  }
  function setHash(key) {
    // 履歴を積まずに書き換える（戻るボタンでタブを1つずつ戻らない・ページも飛ばない）。使えない表示では書き換えない。
    try {
      if (window.history && typeof window.history.replaceState === "function") { window.history.replaceState(null, "", "#" + key); }
    } catch (e) { /* # を書き換えられない表示でも、タブは切り替える */ }
  }

  // 見せた要素と時刻。見せたあと3秒のあいだに貼り付く箱が高くなって要素が隠れたら、その差だけ送り直す。
  var shown = null;
  var shownAt = 0;
  function goTo(el) {
    if (!el || typeof el.scrollIntoView !== "function") { return; }
    shown = el;
    shownAt = Date.now();
    el.scrollIntoView();
  }
  function realign() {
    if (!shown || Date.now() - shownAt > 3000) { return; }
    var r = rect(shown);
    var b = rect(box);
    if (r && b && r.top < b.bottom && typeof window.scrollBy === "function") { window.scrollBy(0, r.top - b.bottom - 16); }
  }

  // 1つの入口。how は "init"（開いたとき）・"hash"（hashchange）・"click"（タブを押す）・"key"（キー）・"link"（ページの中のリンク）。
  // "link" では既定の移動を止めないので、パネルが見えたあとにブラウザが自分で移り、:target の枠も付く。
  function select(key, how, el) {
    show(key);
    if (how === "click" || how === "key") {
      setHash(key);
      if (how === "key") {
        var a = $("hp-tab-" + key);
        if (a && typeof a.focus === "function") { a.focus(); }
      }
      // 帯が貼り付いている（パネルの上端が箱の下端より上にある）ときだけ、パネルの上端を帯のすぐ下へ送る。
      var r = rect($(key));
      var b = rect(box);
      if (r && b && r.top < b.bottom) { goTo($(key)); }
    } else if ((how === "init" || how === "hash") && el) {
      goTo(el);
    }
  }
  function fromHash() {
    var h = window.location && window.location.hash ? decode(window.location.hash.slice(1)) : "";
    if (!h) { return null; }
    // タブの key ならそのパネルを見せる先にする（隠れたパネルへはブラウザが移れないので、切り替えてから移る）
    if (isKey[h]) { return { key: h, el: $(h) }; }
    var el = $(h);
    var k = el ? panelOf(el) : null;
    return k ? { key: k, el: el } : null;
  }

  // ページの中のリンク（タブのリンクを含む）は、取り込みの段階で1か所で受ける。同じ # をもう一度押したとき
  // （hashchange が出ない）も、ここで切り替わる。修飾キー付きや左以外の押し方、別の画面で開くリンク（target）と
  // 保存のリンク（download）は、いまのページを動かさないので、ブラウザに任せる。
  document.addEventListener("click", function (e) {
    if (e.defaultPrevented || (e.button !== undefined && e.button !== 0) || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) { return; }
    var a = e.target;
    while (a && !(a.tagName === "A" && typeof a.getAttribute === "function" && (a.getAttribute("href") || "").charAt(0) === "#")) {
      a = a.parentNode;
    }
    if (!a) { return; }
    var target = a.getAttribute("target");
    if ((target && target !== "_self") || a.getAttribute("download") !== null) { return; }
    var id = decode(a.getAttribute("href").slice(1));
    if (isKey[id]) {
      e.preventDefault();
      select(id, "click");
      return;
    }
    var k = id ? panelOf($(id)) : null;
    if (k && k !== current) { select(k, "link"); }
  }, true);
  window.addEventListener("hashchange", function () {
    var t = fromHash();
    if (t) { select(t.key, "hash", t.el); }
  });
  tabs.forEach(function (t, i) {
    var a = $("hp-tab-" + t.key);
    if (!a) { return; }
    a.addEventListener("keydown", function (e) {
      var n = keys.length;
      var next = null;
      if (e.key === "ArrowRight") { next = keys[(i + 1) % n]; }
      else if (e.key === "ArrowLeft") { next = keys[(i + n - 1) % n]; }
      else if (e.key === "Home") { next = keys[0]; }
      else if (e.key === "End") { next = keys[n - 1]; }
      else if (e.key === " " || e.key === "Spacebar") { next = t.key; }
      if (next === null) { return; }
      e.preventDefault();
      select(next, "key");
    });
  });
  // 読む人が自分でページを送ったら、送り直さない。
  ["wheel", "touchstart"].forEach(function (type) {
    window.addEventListener(type, function () { shown = null; }, { passive: true });
  });
  function onResize() {
    measure();
    realign();
  }
  if (typeof window.ResizeObserver === "function" && box) {
    new window.ResizeObserver(onResize).observe(box);
  } else {
    window.addEventListener("resize", onResize);
  }

  measure();
  var start = fromHash();
  if (start) { select(start.key, "init", start.el); } else { show(keys[0]); }
  // ページを開いたときの # がタブの key だと、ブラウザがそのパネル（Tab キーで入れるよう tabindex を持つ）にフォーカスを当て、
  // パネル全体にフォーカスの枠が出る。開いたときのこのフォーカスだけを外す（あとで Tab キーで入ったときの枠は出る）。
  if (start && start.el === $(start.key)) {
    var dropped = false;
    var drop = function () {
      var p = $(start.key);
      if (!dropped && p && document.activeElement === p && typeof p.blur === "function") { dropped = true; p.blur(); }
    };
    setTimeout(drop, 0);
    window.addEventListener("load", drop);
  }
})();
