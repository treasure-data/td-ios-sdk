// TDBridge — injected at document start, before page scripts run.
// Defines window.TDBridge (the WebView→SDK channel) and signals readiness via a
// TDBridgeReady event. The four methods are the bridge contract.
//
// NOTE: calls are fire-and-forget (no result returned to JS). If invoke/track
// ever need to resolve a result, re-add a callback-resolution shim (callbackId
// + window.__tdBridgeResolve).
(function () {
  function post(method, payload) {
    var msg = { method: method };
    if (payload) { for (var k in payload) { msg[k] = payload[k]; } }
    window.webkit.messageHandlers.TDBridge.postMessage(msg);
  }

  window.TDBridge = {
    close:   function ()             { post('close', null); },
    openUrl: function (url)          { post('openUrl', { url: url }); },
    track:   function (event, values){ post('track', { event: event, values: values || {} }); },
    invoke:  function (name, params) { post('invoke', { name: name, params: params || {} }); }
  };

  document.dispatchEvent(new Event('TDBridgeReady'));
})();
