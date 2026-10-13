import SafariServices
import UIKit
import WebKit

/// Full-screen Pokémon Showdown: the real site, minus the browser, the ads and the zooming.
final class ShowdownViewController: UIViewController {
    static let home = URL(string: "https://play.pokemonshowdown.com/")!

    /// Hosts that stay inside the app; everything else opens in Safari.
    static let appHosts = ["play.pokemonshowdown.com", "psim.us"]

    private var webView: WKWebView!
    private let topFill = UIView()
    private let errorView = OfflineView()
    private var darkPage = false
    private var downloads: [ObjectIdentifier: URL] = [:]

    override var preferredStatusBarStyle: UIStatusBarStyle {
        darkPage ? .lightContent : .darkContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.95, alpha: 1)
        topFill.backgroundColor = Self.lightHeader
        topFill.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topFill)

        AdBlocker.load { [weak self] rules in
            self?.setUpWebView(rules: rules)
        }
    }

    private func setUpWebView(rules: WKContentRuleList?) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.applicationNameForUserAgent = "Version/26.0 Mobile/15E148 Safari/604.1"
        config.ignoresViewportScaleLimits = false

        let content = config.userContentController
        if let rules { content.add(rules) }
        content.addUserScript(WKUserScript(source: Self.pageScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        content.add(WeakMessageHandler(self), name: "showdown")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsLinkPreview = false
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.minimumZoomScale = 1
        webView.scrollView.maximumZoomScale = 1
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif
        view.addSubview(webView)
        self.webView = webView

        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.isHidden = true
        errorView.onRetry = { [weak self] in self?.reload() }
        view.addSubview(errorView)

        NSLayoutConstraint.activate([
            topFill.topAnchor.constraint(equalTo: view.topAnchor),
            topFill.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topFill.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topFill.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),

            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            errorView.topAnchor.constraint(equalTo: view.topAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        webView.load(URLRequest(url: Self.home))
    }

    private func reload() {
        errorView.isHidden = true
        if webView.url == nil {
            webView.load(URLRequest(url: Self.home))
        } else {
            webView.reload()
        }
    }

    // MARK: Page script

    static let lightHeader = UIColor(red: 0.93, green: 0.94, blue: 0.95, alpha: 1)
    static let darkHeader = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)

    /// Locks the viewport at the device width with zoom disabled (Showdown rewrites the tag on resize,
    /// so it's re-applied whenever it changes), turns off double-tap zoom and long-press callouts on
    /// buttons and images, and reports dark mode so the status bar can match.
    static let pageScript = #"""
    (function () {
      var VIEWPORT = 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no';
      function lockViewport() {
        var meta = document.getElementById('viewport') || document.querySelector('meta[name=viewport]');
        if (!meta) {
          meta = document.createElement('meta');
          meta.name = 'viewport';
          document.head.appendChild(meta);
        }
        if (meta.getAttribute('content') !== VIEWPORT) meta.setAttribute('content', VIEWPORT);
      }
      lockViewport();
      new MutationObserver(lockViewport).observe(document.head, { subtree: true, childList: true, attributes: true, attributeFilter: ['content'] });

      var style = document.createElement('style');
      style.textContent =
        'html { -webkit-text-size-adjust: 100%; touch-action: manipulation; }' +
        'button, .button, a.button, img, .picon, .trainersprite, .tabbar a { -webkit-touch-callout: none; -webkit-user-select: none; user-select: none; }' +
        '* { -webkit-tap-highlight-color: transparent; }';
      document.head.appendChild(style);

      function reportTheme() {
        var dark = document.documentElement.classList.contains('dark') || document.body.classList.contains('dark');
        window.webkit.messageHandlers.showdown.postMessage({ dark: dark });
      }
      reportTheme();
      var themeObserver = new MutationObserver(reportTheme);
      themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });
      themeObserver.observe(document.body, { attributes: true, attributeFilter: ['class'] });
    })();
    """#

    fileprivate func receive(_ message: Any) {
        guard let body = message as? [String: Any], let dark = body["dark"] as? Bool, dark != darkPage else { return }
        darkPage = dark
        topFill.backgroundColor = dark ? Self.darkHeader : Self.lightHeader
        view.backgroundColor = dark ? .black : UIColor(white: 0.95, alpha: 1)
        setNeedsStatusBarAppearanceUpdate()
    }

    private func isAppURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return Self.appHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    private func openOutside(_ url: URL) {
        guard url.scheme == "http" || url.scheme == "https" else {
            UIApplication.shared.open(url)
            return
        }
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = UIColor(red: 0.13, green: 0.47, blue: 1, alpha: 1)
        present(safari, animated: true)
    }
}

// MARK: - Navigation

extension ShowdownViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        if action.shouldPerformDownload {
            decisionHandler(.download, preferences)
            return
        }
        guard let url = action.request.url else {
            decisionHandler(.allow, preferences)
            return
        }
        let isMainFrame = action.targetFrame?.isMainFrame ?? true
        if isMainFrame, action.navigationType == .linkActivated || action.targetFrame == nil, !isAppURL(url) {
            openOutside(url)
            decisionHandler(.cancel, preferences)
            return
        }
        if isMainFrame, url.scheme != "http", url.scheme != "https", url.scheme != "about", url.scheme != "blob", url.scheme != "data" {
            UIApplication.shared.open(url)
            decisionHandler(.cancel, preferences)
            return
        }
        decisionHandler(.allow, preferences)
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(response.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        errorView.isHidden = true
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        errorView.show(message: error.localizedDescription)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

// MARK: - Downloads (team backups, replays)

extension ShowdownViewController: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping @MainActor @Sendable (URL?) -> Void) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedFilename)
        try? FileManager.default.removeItem(at: url)
        completionHandler(url)
        downloads[ObjectIdentifier(download)] = url
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let url = downloads.removeValue(forKey: ObjectIdentifier(download)) else { return }
        let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = view
        present(share, animated: true)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloads.removeValue(forKey: ObjectIdentifier(download))
    }
}

// MARK: - JavaScript dialogs and new windows

extension ShowdownViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Showdown opens replays, the forums and help pages in new tabs.
        if let url = action.request.url {
            if isAppURL(url) {
                webView.load(action.request)
            } else {
                openOutside(url)
            }
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        presentDialog(alert, otherwise: completionHandler)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        presentDialog(alert) { completionHandler(false) }
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable (String?) -> Void) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(alert.textFields?.first?.text) })
        presentDialog(alert) { completionHandler(nil) }
    }

    private func presentDialog(_ alert: UIAlertController, otherwise fallback: () -> Void) {
        guard presentedViewController == nil else {
            fallback()
            return
        }
        present(alert, animated: true)
    }
}

/// Avoids the retain cycle between the content controller and its message handler.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: ShowdownViewController?

    init(_ target: ShowdownViewController) {
        self.target = target
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.receive(message.body)
    }
}

/// Shown when the site can't be reached at all.
private final class OfflineView: UIView {
    var onRetry: (() -> Void)?
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.33, green: 0.42, blue: 0.67, alpha: 1)
        let title = UILabel()
        title.text = "Can't reach Pokémon Showdown"
        title.font = UIFont(name: "Verdana-Bold", size: 17)
        title.textColor = .white
        label.font = UIFont(name: "Verdana", size: 13)
        label.textColor = UIColor(white: 1, alpha: 0.8)
        label.numberOfLines = 0
        label.textAlignment = .center
        var config = UIButton.Configuration.filled()
        config.title = "Try again"
        config.baseBackgroundColor = .white
        config.baseForegroundColor = UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1)
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in self?.onRetry?() })
        let stack = UIStackView(arrangedSubviews: [title, label, button])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(message: String) {
        label.text = message
        isHidden = false
    }
}
