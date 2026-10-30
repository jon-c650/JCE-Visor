(function (root) {
  function install(term, handlers, documentObject) {
    term.onData(data => handlers.sendText(data));
    term.onBinary(data => {
      let binary = '';
      for (let index = 0; index < data.length; index++) {
        binary += String.fromCharCode(data.charCodeAt(index) & 0xff);
      }
      handlers.sendBinary(btoa(binary));
    });

    // Command-key shortcuts belong to macOS, not the remote terminal. Handling
    // them here also makes them reliable while WKWebView's hidden textarea has focus.
    term.attachCustomKeyEventHandler(event => !event.metaKey);
    documentObject.addEventListener('keydown', event => {
      if (!event.metaKey) return;
      const key = event.key.toLowerCase();
      if (key === 'c') {
        if (term.hasSelection()) handlers.copy(term.getSelection());
      } else if (key === 'v') {
        handlers.requestPaste();
      } else if (key === 'a') {
        term.selectAll();
      } else if (key === 'k') {
        term.clear();
      } else {
        return;
      }
      event.preventDefault();
      event.stopImmediatePropagation();
    }, true);
  }

  root.VisorInput = { install };
})(globalThis);
