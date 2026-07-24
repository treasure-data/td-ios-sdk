// TDJSBridge — injected at document start, before page scripts run.
// Defines window.TDJSBridge, then signals readiness via a TDJSBridgeReady event.
// Native resolves callbacks by calling window.__tdBridgeResolve(id, result).
(function () {
  var cbs = {}, seq = 0;

  function call(method, args, cb) {
    var id = null;
    if (cb) { id = ++seq; cbs[id] = cb; }
    window.webkit.messageHandlers.TDJSBridge.postMessage(
      { method: method, args: args || null, callbackId: id });
  }

  window.__tdBridgeResolve = function (id, result) {
    var cb = cbs[id];
    if (cb) { delete cbs[id]; cb(result); }
  };

  window.TDJSBridge = {
    getCampaignPayload: function (cb) { call('getCampaignPayload', null, cb); },
    closeMessage:       function ()   { call('closeMessage', null, null); },
    // Custom extensions are appended here by native per registered method name.
    __invoke: call
  };

  document.dispatchEvent(new Event('TDJSBridgeReady'));
})();
