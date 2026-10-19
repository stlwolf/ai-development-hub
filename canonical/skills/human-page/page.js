/* human-page: 答えの保存・保存できないときの返答の文・回答待ちの件数を受け持つ。
   画面の文字は textContent と value だけで書き、innerHTML を使わない。
   保存の形は collection "decisions" の、doc id がカードの key の文書 {key, choice, note, at}。 */
(function () {
  "use strict";
  var dataEl = document.getElementById("hp-data");
  if (!dataEl) { return; }
  var D;
  try { D = JSON.parse(dataEl.textContent); } catch (e) { return; }
  var L = D.labels || {};
  var cards = D.cards || [];
  if (!cards.length) { return; }

  // key はデータから来るので、constructor のような名前でもプロトタイプを拾わない表にする。
  function table() { return Object.create(null); }
  function own(obj, key) { return !!obj && Object.prototype.hasOwnProperty.call(obj, key); }
  var byKey = table();
  cards.forEach(function (c) { byKey[c.key] = c; });

  function $(id) { return document.getElementById(id); }
  function fill(template, values) {
    return String(template).replace(/\{([a-z_]+)\}/g, function (m, name) {
      return Object.prototype.hasOwnProperty.call(values, name) ? String(values[name]) : m;
    });
  }
  function isOption(key, choice) {
    var c = byKey[key];
    for (var i = 0; i < c.options.length; i += 1) {
      if (c.options[i].key === choice) { return true; }
    }
    return false;
  }

  var state = table();
  cards.forEach(function (c) {
    var a = own(D.answers, c.key) ? D.answers[c.key] : null;
    state[c.key] = {
      choice: a && typeof a.choice === "string" ? a.choice : null,
      note: a && typeof a.note === "string" ? a.note : ""
    };
  });

  var answered = D.status === "answered";
  var mode = answered ? "answered" : "connecting"; // connecting | ready | unavailable | answered
  var col = null;
  var rev = table();    // key -> {choice, note}: 手元で変えた回数
  var saved = table();  // key -> {choice, note}: 保存できた回数
  var chains = table(); // key -> Promise: 同じ文書への書き込みを1つずつ順に行う
  var noteTimers = table();

  function counters(map, key) {
    if (!map[key]) { map[key] = { choice: 0, note: 0 }; }
    return map[key];
  }
  function isDirty(key, field) {
    return counters(rev, key)[field] !== counters(saved, key)[field];
  }

  function setStore(text, bad) {
    var el = $("hp-store");
    if (!el) { return; }
    el.textContent = text;
    el.className = "hp-store" + (bad ? " is-bad" : "");
  }
  function setSaved(key, text, cls) {
    var el = $("hp-saved-" + key);
    if (!el) { return; }
    el.textContent = text;
    el.className = "hp-saved" + (cls ? " " + cls : "");
  }

  function replyText() {
    var lines = [fill(L["text.reply_heading"], { title: D.title, time: D.time })];
    cards.forEach(function (c) {
      var s = state[c.key];
      var label = L["text.unanswered"];
      c.options.forEach(function (o) { if (o.key === s.choice) { label = o.label; } });
      lines.push("- " + c.key + ": " + label);
      if (s.note && s.note.trim()) {
        lines.push("  " + fill(L["text.reply_note"], { note: s.note.replace(/\r?\n/g, "\n    ") }));
      }
    });
    return lines.join("\n");
  }
  function paintReply() {
    var box = $("hp-reply");
    var ta = $("hp-reply-text");
    if (!box || !ta || box.hidden) { return; }
    ta.value = replyText();
  }
  function showReply() {
    var box = $("hp-reply");
    if (box) { box.hidden = false; }
    paintReply();
  }

  function paint() {
    var open = 0;
    cards.forEach(function (c) {
      var s = state[c.key];
      c.options.forEach(function (o) {
        var b = $("hp-opt-" + c.key + "." + o.key);
        if (b) { b.setAttribute("aria-pressed", s.choice === o.key ? "true" : "false"); }
      });
      var ta = $("hp-note-" + c.key);
      if (ta && document.activeElement !== ta && !isDirty(c.key, "note") && ta.value !== s.note) {
        ta.value = s.note;
      }
      if (!s.choice) { open += 1; }
    });
    if (!answered && D.status === "awaiting") {
      var st = $("hp-status");
      if (st) { st.textContent = fill(L["status.awaiting"], { n: open }); }
    }
    if (!answered) {
      (D.groups || []).forEach(function (g) {
        var el = $("hp-group-status-" + g.id);
        if (!el) { return; }
        var n = 0;
        g.keys.forEach(function (k) { if (!state[k].choice) { n += 1; } });
        el.textContent = fill(L["status.awaiting"], { n: n });
      });
    }
    paintReply();
  }

  function write(key, field) {
    var s = state[key];
    var r = { choice: counters(rev, key).choice, note: counters(rev, key).note };
    var at = new Date().toISOString();
    var patch = { at: at };
    patch[field] = field === "choice" ? (s.choice || null) : (s.note || "");
    var ref = col.doc(key);
    var wroteAll = false;
    setSaved(key, L["text.store_saving"], "");
    return Promise.resolve().then(function () {
      return ref.update(patch);
    }).catch(function (e) {
      if (e && e.code === "invalid_argument") {
        wroteAll = true;
        return ref.set({ key: key, choice: s.choice || null, note: s.note || "", at: at });
      }
      throw e;
    }).then(function () {
      var sv = counters(saved, key);
      var fields = wroteAll ? ["choice", "note"] : [field];
      fields.forEach(function (f) { if (sv[f] < r[f]) { sv[f] = r[f]; } });
      setSaved(key, L["text.store_saved"], "is-ok");
    }, function () {
      setSaved(key, L["text.store_failed"], "is-bad");
      showReply();
    });
  }
  function queue(key, field) {
    var target = counters(rev, key)[field];
    chains[key] = (chains[key] || Promise.resolve()).then(function () {
      if (counters(saved, key)[field] >= target) { return null; }
      return write(key, field);
    });
  }
  function flush() {
    cards.forEach(function (c) {
      if (isDirty(c.key, "choice")) { queue(c.key, "choice"); }
      if (isDirty(c.key, "note")) { queue(c.key, "note"); }
    });
  }

  function change(key, value) {
    state[key].choice = value;
    counters(rev, key).choice += 1;
    paint();
    if (mode === "ready") { queue(key, "choice"); } else if (mode === "unavailable") { showReply(); }
  }
  function noteInput(key, ta) {
    state[key].note = ta.value;
    counters(rev, key).note += 1;
    paint();
    clearTimeout(noteTimers[key]);
    noteTimers[key] = setTimeout(function () {
      if (mode === "ready") { queue(key, "note"); }
    }, 900);
  }

  function onSnapshot(snap) {
    (snap && snap.docs ? snap.docs : []).forEach(function (d) {
      var v = d && typeof d.data === "function" ? d.data() : null;
      if (!v) { return; }
      var key = typeof v.key === "string" ? v.key : d.id;
      if (!own(byKey, key)) { return; }
      var s = state[key];
      if (!isDirty(key, "choice") && (v.choice === null || (typeof v.choice === "string" && isOption(key, v.choice)))) {
        s.choice = v.choice;
      }
      var ta = $("hp-note-" + key);
      if (!isDirty(key, "note") && typeof v.note === "string" && !(ta && document.activeElement === ta)) {
        s.note = v.note;
      }
    });
    paint();
  }

  function unavailable() {
    if (mode === "unavailable") { return; }
    mode = "unavailable";
    setStore(L["text.store_unavailable"], true);
    showReply();
  }
  function connect() {
    var claude = window.claude;
    if (!claude || typeof claude.use !== "function") { unavailable(); return; }
    setStore(L["text.store_connecting"], false);
    var done = false;
    var guard = setTimeout(function () {
      if (!done) { done = true; unavailable(); }
    }, 12000);
    var p;
    try { p = claude.use("db"); } catch (e) { done = true; clearTimeout(guard); unavailable(); return; }
    Promise.resolve(p).then(function (db) {
      if (done) { return; }
      done = true;
      clearTimeout(guard);
      if (!db) { unavailable(); return; }
      try { col = db.collection("decisions"); } catch (e) { unavailable(); return; }
      mode = "ready";
      setStore("", false);
      try {
        col.onSnapshot(onSnapshot, function () {
          setStore(L["text.store_failed"], true);
          showReply();
        });
      } catch (e) {
        setStore(L["text.store_failed"], true);
        showReply();
      }
      flush();
    }, function () {
      if (done) { return; }
      done = true;
      clearTimeout(guard);
      unavailable();
    });
  }

  function onCopy() {
    var ta = $("hp-reply-text");
    var msg = $("hp-copy-msg");
    var text = replyText();
    if (ta) { ta.value = text; }
    function done(ok) {
      if (!ok && ta) { ta.focus(); ta.select(); }
      if (msg) {
        msg.textContent = ok ? L["text.copied"] : L["text.copy_failed"];
        msg.className = "hp-copy-msg" + (ok ? "" : " is-bad");
      }
    }
    try {
      if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
        navigator.clipboard.writeText(text).then(function () { done(true); }, function () { done(false); });
      } else {
        done(false);
      }
    } catch (e) {
      done(false);
    }
  }

  cards.forEach(function (c) {
    c.options.forEach(function (o) {
      var b = $("hp-opt-" + c.key + "." + o.key);
      if (b) { b.addEventListener("click", function () { if (!answered) { change(c.key, o.key); } }); }
    });
    var ta = $("hp-note-" + c.key);
    if (ta) { ta.addEventListener("input", function () { if (!answered) { noteInput(c.key, ta); } }); }
  });
  var copy = $("hp-copy");
  if (copy) { copy.addEventListener("click", onCopy); }

  paint();
  if (!answered) { connect(); }
})();
