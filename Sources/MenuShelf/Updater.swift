import AppKit
import Combine

struct ReleaseInfo: Equatable {
    let version: String
    let notes: String
    let pageURL: URL
    let assetURL: URL?
}

/// 基于 GitHub Releases 的检查更新 + 一键安装
final class Updater: ObservableObject {
    static let shared = Updater()
    static let repo = "245678000000/MenuShelf"
    static var releasesPage: URL { URL(string: "https://github.com/\(repo)/releases")! }

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(ReleaseInfo)
        case downloading(Double)
        case installing
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastChecked: Date?
    /// 最近一次发现的新版本（下载过程中也保留）
    @Published private(set) var latest: ReleaseInfo?

    /// 自动检查发现新版本时回调（用于弹出提示）
    var onUpdateFound: ((ReleaseInfo) -> Void)?

    private var timer: Timer?
    private var progressObservation: NSKeyValueObservation?
    private let d = UserDefaults.standard

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    var isBusy: Bool {
        switch state {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }

    private init() {
        lastChecked = d.object(forKey: "lastUpdateCheck") as? Date
    }

    // MARK: - 自动检查

    func startAutomaticChecks() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.autoCheckIfDue()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.autoCheckIfDue() }
    }

    private func autoCheckIfDue() {
        guard Prefs.shared.autoCheckUpdates, !isBusy else { return }
        if let last = lastChecked, Date().timeIntervalSince(last) < 24 * 3600 { return }
        check(userInitiated: false)
    }

    // MARK: - 检查

    func check(userInitiated: Bool = true) {
        guard !isBusy else { return }
        state = .checking
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("MenuShelf-Updater", forHTTPHeaderField: "User-Agent")
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 20
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, err in
            DispatchQueue.main.async { self?.handle(data: data, response: resp, error: err, userInitiated: userInitiated) }
        }.resume()
    }

    private func handle(data: Data?, response: URLResponse?, error: Error?, userInitiated: Bool) {
        if let error {
            state = .failed("网络错误：\(error.localizedDescription)")
            return
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 { state = .failed("还没有发布任何版本"); return }
        if code == 403 { state = .failed("请求过于频繁，请稍后再试"); return }
        guard (200..<300).contains(code), let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String
        else {
            state = .failed("无法解析更新信息")
            return
        }

        lastChecked = Date()
        d.set(lastChecked, forKey: "lastUpdateCheck")

        let version = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
        let assets = json["assets"] as? [[String: Any]] ?? []
        let zip = assets.first { ($0["name"] as? String)?.lowercased().hasSuffix(".zip") == true }
        let info = ReleaseInfo(
            version: version,
            notes: json["body"] as? String ?? "",
            pageURL: (json["html_url"] as? String).flatMap(URL.init(string:)) ?? Self.releasesPage,
            assetURL: (zip?["browser_download_url"] as? String).flatMap(URL.init(string:))
        )

        guard Self.isVersion(version, newerThan: currentVersion) else {
            latest = nil
            state = .upToDate
            return
        }
        latest = info
        state = .available(info)
        if !userInitiated, Prefs.shared.skippedVersion != version {
            onUpdateFound?(info)
        }
    }

    func skip(_ info: ReleaseInfo) {
        Prefs.shared.skippedVersion = info.version
        state = .idle
    }

    // MARK: - 下载与安装

    func downloadAndInstall() {
        guard let info = latest else { return }
        guard let url = info.assetURL else {
            NSWorkspace.shared.open(info.pageURL)
            return
        }
        let appURL = Bundle.main.bundleURL
        guard FileManager.default.isWritableFile(atPath: appURL.deletingLastPathComponent().path) else {
            state = .failed("没有权限替换当前 App，已打开下载页面，请手动安装")
            NSWorkspace.shared.open(info.pageURL)
            return
        }

        state = .downloading(0)
        let task = URLSession.shared.downloadTask(with: url) { [weak self] tmp, resp, err in
            // 临时文件在回调结束后会被删除，必须立即移走
            var zipURL: URL?
            var message = err?.localizedDescription ?? "下载失败"
            if let tmp, ((resp as? HTTPURLResponse)?.statusCode ?? 0) < 400 {
                let work = FileManager.default.temporaryDirectory
                    .appendingPathComponent("MenuShelfUpdate-\(UUID().uuidString)")
                do {
                    try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
                    let dest = work.appendingPathComponent("update.zip")
                    try FileManager.default.moveItem(at: tmp, to: dest)
                    zipURL = dest
                } catch {
                    message = error.localizedDescription
                }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.progressObservation = nil
                if let zipURL {
                    self.install(zip: zipURL)
                } else {
                    self.state = .failed("下载失败：\(message)")
                }
            }
        }
        progressObservation = task.progress.observe(\.fractionCompleted) { [weak self] p, _ in
            DispatchQueue.main.async {
                guard let self, case .downloading = self.state else { return }
                self.state = .downloading(p.fractionCompleted)
            }
        }
        task.resume()
    }

    private func install(zip: URL) {
        state = .installing
        let bundleID = Bundle.main.bundleIdentifier
        let current = currentVersion
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let out = zip.deletingLastPathComponent().appendingPathComponent("extracted")
            let unzipped = Self.run("/usr/bin/ditto", ["-x", "-k", zip.path, out.path])
            let app = (try? FileManager.default.contentsOfDirectory(at: out, includingPropertiesForKeys: nil))?
                .first { $0.pathExtension == "app" }
            let plist = app.flatMap { NSDictionary(contentsOf: $0.appendingPathComponent("Contents/Info.plist")) }
            let newVersion = plist?["CFBundleShortVersionString"] as? String ?? ""

            DispatchQueue.main.async {
                guard let self else { return }
                guard unzipped, let app, plist?["CFBundleIdentifier"] as? String == bundleID,
                      Self.isVersion(newVersion, newerThan: current)
                else {
                    self.state = .failed("更新包无效，请手动下载")
                    return
                }
                self.relaunch(replacingWith: app)
            }
        }
    }

    /// 退出后由一个小脚本替换 App 并重新打开；替换失败会还原旧版本
    private func relaunch(replacingWith newApp: URL) {
        let script = """
        while kill -0 "$3" 2>/dev/null; do sleep 0.2; done
        if mv "$1" "$1.old"; then
          if mv "$2" "$1"; then
            rm -rf "$1.old"
            xattr -dr com.apple.quarantine "$1" 2>/dev/null
          else
            mv "$1.old" "$1"
          fi
        fi
        open "$1"
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script, "sh", Bundle.main.bundleURL.path, newApp.path,
                       String(ProcessInfo.processInfo.processIdentifier)]
        do {
            try p.run()
        } catch {
            state = .failed("无法启动安装：\(error.localizedDescription)")
            return
        }
        NSApp.terminate(nil)
    }

    // MARK: - 工具

    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    private static func run(_ path: String, _ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }
}
