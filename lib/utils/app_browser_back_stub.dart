typedef BrowserBackHandler = bool Function();

void installAppBrowserBackHandling() {}

void registerBrowserBackHandler(BrowserBackHandler handler) {}

void unregisterBrowserBackHandler(BrowserBackHandler handler) {}

void markBrowserHistoryForward() {}
