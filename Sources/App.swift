import SwiftUI
import WebKit
import Network

/// The site this shell shows. Navigation stays on this host; every other link opens in Safari.
let siteURL = URL(string: "https://krishlodha12.github.io/cyber-intel-scraper/")!
let background = Color(red: 0x0e / 255, green: 0x0e / 255, blue: 0x0c / 255)

@main
struct ShellApp: App {
    @StateObject private var model = ShellModel()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ZStack {
                background.ignoresSafeArea()
                WebView(model: model)
                if model.showOffline {
                    OfflineView { model.reload() }
                }
            }
            .preferredColorScheme(.dark)
            .onChange(of: phase) { _, newPhase in
                if newPhase == .active { model.reloadIfStale() }
            }
        }
    }
}

@MainActor
final class ShellModel: ObservableObject {
    @Published var showOffline = false
    weak var webView: WKWebView?
    private var lastLoad = Date.distantPast
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in
                if self?.showOffline == true { self?.reload() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "shell.network"))
    }

    func loaded() {
        lastLoad = Date()
        showOffline = false
    }

    /// Only shown when nothing could be loaded at all: the site's own service worker
    /// serves the last copy offline once it has been opened online one time.
    func failed() {
        if webView?.url == nil || webView?.url?.host != siteURL.host {
            showOffline = true
        }
    }

    func reload() {
        guard let webView else { return }
        if webView.url?.host == siteURL.host {
            webView.reload()
        } else {
            webView.load(URLRequest(url: siteURL))
        }
    }

    /// Coming back after a while shows fresh incidents without a manual pull.
    func reloadIfStale() {
        if Date().timeIntervalSince(lastLoad) > 30 * 60 { reload() }
    }
}

struct WebView: UIViewRepresentable {
    let model: ShellModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // App-bound domains (Info.plist WKAppBoundDomains) switch on service workers,
        // which is how the site keeps its last copy for offline reading.
        config.limitsNavigationsToAppBoundDomains = true
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor(background)
        webView.scrollView.backgroundColor = UIColor(background)

        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.pulled(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        model.webView = webView
        webView.load(URLRequest(url: siteURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    /// WebKit calls its delegates on the main thread, so the coordinator is main-actor bound.
    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let model: ShellModel
        init(model: ShellModel) { self.model = model }

        @objc func pulled(_ sender: UIRefreshControl) {
            model.reload()
            sender.endRefreshing()
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = action.request.url else { return .cancel }
            if url.host == siteURL.host || url.scheme == "about" {
                return .allow
            }
            if ["http", "https", "mailto"].contains(url.scheme ?? "") {
                UIApplication.shared.open(url)
            }
            return .cancel
        }

        /// target="_blank" links: open outside instead of in a new web view.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url { UIApplication.shared.open(url) }
            return nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            model.loaded()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            model.failed()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            model.failed()
        }
    }
}

struct OfflineView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Threat Ledger")
                .font(.system(.title, design: .serif).weight(.semibold))
            Text("You're offline and there is no saved copy yet. Open the app once while online and it will keep the last edition for offline reading.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.95, green: 0.55, blue: 0.25))
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }
}
