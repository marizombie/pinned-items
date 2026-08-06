import AppKit

enum PinKind: String, Codable {
    case application
    case file
    case folder
}

struct Pin: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var url: URL
    var kind: PinKind
    var ownerBundleIdentifier: String?
    var ownerName: String?
}

final class PinStore {
    private(set) var pins: [Pin] = []
    private let fileURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init() {
        let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("PinnedItems", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: supportDirectory,
            withIntermediateDirectories: true
        )

        fileURL = supportDirectory.appendingPathComponent("pins.json")
        load()
    }

    func add(_ pin: Pin) {
        guard pin.url.isFileURL else { return }

        guard pins.contains(where: { $0.url == pin.url && $0.ownerBundleIdentifier == pin.ownerBundleIdentifier }) == false else {
            return
        }

        pins.append(pin)
        save()
    }

    func remove(_ pin: Pin) {
        pins.removeAll { $0.id == pin.id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            pins = []
            return
        }

        pins = (try? decoder.decode([Pin].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? encoder.encode(pins) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = PinStore()
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var activeApplication: NSRunningApplication?
    private var iconCache: [String: NSImage] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        terminateDuplicateInstances()
        activeApplication = trackedApplication(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")
        statusItem.button?.imagePosition = .imageOnly

        menu.delegate = self
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    @objc private func applicationActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let trackedApp = trackedApplication(app) else {
            return
        }

        activeApplication = trackedApp
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let frontApp = activeApplication
        let ownerName = frontApp?.localizedName ?? "Current App"
        let ownerBundleIdentifier = frontApp?.bundleIdentifier
        let sortedPins = store.pins.sorted(by: pinTitleAscending)

        addAction("Pin File for \(ownerName)", action: #selector(pinFileForFrontApp))
        addAction("Pin Folder for \(ownerName)", action: #selector(pinFolderForFrontApp))
        // addAction("Pin \(ownerName)", action: #selector(pinFrontApp))

        if let ownerBundleIdentifier {
            let appPins = sortedPins.filter { $0.ownerBundleIdentifier == ownerBundleIdentifier }
            if appPins.isEmpty == false {
                menu.addItem(.separator())
                addSection("Pinned for \(ownerName)", pins: appPins)
            }
        }

        let globalPins = sortedPins.filter { $0.ownerBundleIdentifier == nil }
        if globalPins.isEmpty == false {
            menu.addItem(.separator())
            addSection("Always Pinned", pins: globalPins)
        }

        if store.pins.isEmpty == false {
            menu.addItem(.separator())
            addRemoveMenu(sortedPins)
        }

        menu.addItem(.separator())
        addAction("Pin File Globally", action: #selector(pinGlobalFile))
        addAction("Pin Folder Globally", action: #selector(pinGlobalFolder))
        menu.addItem(.separator())
        addAction("Quit Pinned", action: #selector(quit))
    }

    private func addSection(_ title: String, pins: [Pin]) {
        let section = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        section.isEnabled = false
        menu.addItem(section)

        for pin in pins {
            let item = NSMenuItem(title: pin.title, action: #selector(openPin(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pin.id
            item.image = icon(for: pin)
            menu.addItem(item)
        }
    }

    private func addRemoveMenu(_ pins: [Pin]) {
        let removeItem = NSMenuItem(title: "Remove Pin", action: nil, keyEquivalent: "")
        let removeMenu = NSMenu()

        for pin in pins {
            let title = pin.ownerName.map { "\(pin.title) - \($0)" } ?? pin.title
            let item = NSMenuItem(title: title, action: #selector(removePin(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pin.id
            item.image = icon(for: pin)
            removeMenu.addItem(item)
        }

        removeItem.submenu = removeMenu
        menu.addItem(removeItem)
    }

    private func addAction(_ title: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    private func icon(for pin: Pin) -> NSImage? {
        let cacheKey = pin.url.path
        if let image = iconCache[cacheKey] {
            return image
        }

        let image = NSWorkspace.shared.icon(forFile: pin.url.path)
        image.size = NSSize(width: 16, height: 16)
        iconCache[cacheKey] = image
        return image
    }

    @objc private func openPin(_ sender: NSMenuItem) {
        guard let pin = pin(from: sender) else { return }
        guard FileManager.default.fileExists(atPath: pin.url.path) else {
            showMissingItemAlert(pin)
            return
        }

        if pin.kind == .application {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: pin.url, configuration: configuration)
            return
        }

        if openPinWithOwnerApplication(pin) {
            return
        }

        NSWorkspace.shared.open(pin.url)
    }

    private func openPinWithOwnerApplication(_ pin: Pin) -> Bool {
        guard let ownerBundleIdentifier = pin.ownerBundleIdentifier,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ownerBundleIdentifier) else {
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([pin.url], withApplicationAt: appURL, configuration: configuration)
        return true
    }

    @objc private func removePin(_ sender: NSMenuItem) {
        guard let pin = pin(from: sender) else { return }
        store.remove(pin)
    }

    @objc private func pinFileForFrontApp() {
        pinChosenURL(kind: .file, canChooseFiles: true, canChooseDirectories: false, scopedToFrontApp: true)
    }

    @objc private func pinFolderForFrontApp() {
        pinChosenURL(kind: .folder, canChooseFiles: false, canChooseDirectories: true, scopedToFrontApp: true)
    }

    @objc private func pinGlobalFile() {
        pinChosenURL(kind: .file, canChooseFiles: true, canChooseDirectories: false, scopedToFrontApp: false)
    }

    @objc private func pinGlobalFolder() {
        pinChosenURL(kind: .folder, canChooseFiles: false, canChooseDirectories: true, scopedToFrontApp: false)
    }

    @objc private func pinFrontApp() {
        guard let app = activeApplication,
              let url = app.bundleURL else {
            return
        }

        store.add(Pin(
            id: UUID(),
            title: app.localizedName ?? url.deletingPathExtension().lastPathComponent,
            url: url,
            kind: .application,
            ownerBundleIdentifier: nil,
            ownerName: nil
        ))
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func pinChosenURL(
        kind: PinKind,
        canChooseFiles: Bool,
        canChooseDirectories: Bool,
        scopedToFrontApp: Bool
    ) {
        let frontApp = activeApplication
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = canChooseFiles
        panel.canChooseDirectories = canChooseDirectories
        panel.canCreateDirectories = false
        panel.prompt = "Pin"

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            store.add(Pin(
                id: UUID(),
                title: url.lastPathComponent,
                url: url,
                kind: kind,
                ownerBundleIdentifier: scopedToFrontApp ? frontApp?.bundleIdentifier : nil,
                ownerName: scopedToFrontApp ? frontApp?.localizedName : nil
            ))
        }
    }

    private func pin(from sender: NSMenuItem) -> Pin? {
        guard let id = sender.representedObject as? UUID else {
            return nil
        }

        return store.pins.first { $0.id == id }
    }

    private func showMissingItemAlert(_ pin: Pin) {
        let alert = NSAlert()
        alert.messageText = "Pinned item not found"
        alert.informativeText = "\"\(pin.title)\" no longer exists at its saved path. You can remove it from the Pinned menu."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func trackedApplication(_ app: NSRunningApplication?) -> NSRunningApplication? {
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return nil
        }

        return app
    }

    private func terminateDuplicateInstances() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier) {
            guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
                continue
            }

            app.terminate()
        }
    }

    private func pinTitleAscending(_ lhs: Pin, _ rhs: Pin) -> Bool {
        lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
