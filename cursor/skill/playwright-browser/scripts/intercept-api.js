// SPA APIレスポンスキャプチャ用インターセプタ
// browser_evaluate の function 引数として実行する
//
// デフォルトで /api/, /v{N}/, /graphql/ を含むURLをキャプチャ。
// 静的アセット（.js, .css, .png等）は除外。
// パターンが合わない場合は isApiRequest() を調整すること。

window.__captured = window.__captured || [];

function isApiRequest(url) {
  if (/\.(js|css|png|jpg|jpeg|gif|svg|woff2?|ttf|ico|map)(\?|$)/.test(url)) return false;
  return /\/(api|v[0-9]+|graphql)\//.test(url);
}

// --- fetch interceptor (modern SPA, Nuxt 3) ---
(function installFetchInterceptor() {
  var origFetch = window.fetch;
  window.fetch = async function () {
    var res = await origFetch.apply(this, arguments);
    var url =
      typeof arguments[0] === "string"
        ? arguments[0]
        : arguments[0] && arguments[0].url
          ? arguments[0].url
          : "";
    if (isApiRequest(url)) {
      var clone = res.clone();
      try {
        var body = await clone.json();
        window.__captured.push({ url: url, status: res.status, body: body });
      } catch (e) {
        window.__captured.push({ url: url, status: res.status, body: "parse error" });
      }
    }
    return res;
  };
})();

// --- XHR interceptor (axios-based SPA, Nuxt 2) ---
(function installXHRInterceptor() {
  var origOpen = XMLHttpRequest.prototype.open;
  var origSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (method, url) {
    this._url = url;
    return origOpen.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function () {
    var self = this;
    this.addEventListener("load", function () {
      if (self._url && isApiRequest(self._url)) {
        try {
          window.__captured.push({ url: self._url, status: self.status, body: JSON.parse(self.responseText) });
        } catch (e) {
          window.__captured.push({ url: self._url, status: self.status, body: "parse error" });
        }
      }
    });
    return origSend.apply(this, arguments);
  };
})();
