import AppKit
import TwitcherCore

@MainActor
private final class KeyCapturePanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) != true {
            super.keyDown(with: event)
        }
    }
}

@MainActor
final class ChooserWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    private let service: WindowService
    private let store: AssignmentStore
    private let onAssignmentsChanged: () -> Void
    private let tableView = NSTableView()
    private let emptyLabel = NSTextField(labelWithString: "")
    private var rows: [ManagedProgram] = []
    private var book: AssignmentBook

    init(service: WindowService, store: AssignmentStore, onAssignmentsChanged: @escaping () -> Void) {
        self.service = service
        self.store = store
        self.onAssignmentsChanged = onAssignmentsChanged
        self.book = store.load()

        let panel = KeyCapturePanel(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Twitcher"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        super.init(window: panel)
        panel.delegate = self
        panel.onKeyDown = { [weak self] event in self?.handleKey(event) ?? false }
        buildUI(in: panel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        refresh()
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        if !rows.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < rows.count, let identifier = tableColumn?.identifier else { return nil }
        let program = rows[row]
        let cell = NSTableCellView()
        let text = NSTextField(labelWithString: "")
        text.lineBreakMode = .byTruncatingTail
        text.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(text)
        cell.textField = text
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        switch identifier.rawValue {
        case "key":
            text.stringValue = book.letter(for: program.identity).map { "⌥\(String($0).uppercased())" } ?? "—"
            text.alignment = .center
            text.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        case "app":
            text.stringValue = program.identity.name
        default:
            let count = program.windows.count
            let suffix = count == 1 ? "window" : "windows"
            text.stringValue = "\(count) \(suffix): " + program.windows.map(\.title).joined(separator: ", ")
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        window?.makeFirstResponder(window)
    }

    private func buildUI(in panel: NSPanel) {
        let content = NSVisualEffectView()
        content.material = .hudWindow
        content.blendingMode = .behindWindow
        content.state = .active
        content.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = content

        let title = NSTextField(labelWithString: "Choose a program")
        title.font = .systemFont(ofSize: 24, weight: .bold)
        let instructions = NSTextField(labelWithString: "Select a program and type A–Z to assign it. Return opens it. Delete clears its assignment.")
        instructions.textColor = .secondaryLabelColor

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        tableView.backgroundColor = .clear
        tableView.headerView = nil
        tableView.rowHeight = 38
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.selectionHighlightStyle = .regular
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(openSelectedProgram)

        let keyColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("key"))
        keyColumn.width = 72
        let appColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        appColumn.width = 180
        let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        titleColumn.width = 410
        tableView.addTableColumn(keyColumn)
        tableView.addTableColumn(appColumn)
        tableView.addTableColumn(titleColumn)
        scrollView.documentView = tableView

        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.font = .systemFont(ofSize: 15)

        [title, instructions, scrollView, emptyLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview($0)
        }
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: content.topAnchor, constant: 34),
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            instructions.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            instructions.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            instructions.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            scrollView.topAnchor.constraint(equalTo: instructions.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
    }

    private func refresh() {
        book = store.load()
        rows = service.programs()
        emptyLabel.stringValue = service.isAccessibilityGranted()
            ? "No programs with standard windows are currently open."
            : "Accessibility access is required. Use the Twitcher menu to grant it."
        emptyLabel.isHidden = !rows.isEmpty
        tableView.reloadData()
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        if event.keyCode == 51, event.modifierFlags.contains(.option) {
            close()
            return true
        }

        switch event.keyCode {
        case 53: // Escape
            close()
            return true
        case 36, 76: // Return or keypad Enter
            openSelectedProgram()
            return true
        case 51, 117: // Delete or forward delete
            guard let selected = selectedProgram else { return true }
            book.remove(program: selected.identity)
            persistChanges()
            return true
        case 125: // Down arrow
            moveSelection(by: 1)
            return true
        case 126: // Up arrow
            moveSelection(by: -1)
            return true
        default:
            guard event.modifierFlags.intersection([.command, .control]).isEmpty,
                  let character = event.charactersIgnoringModifiers?.lowercased().first,
                  character.isASCII,
                  character.isLetter,
                  let selected = selectedProgram
            else { return false }
            book.assign(character, to: selected.identity)
            persistChanges()
            return true
        }
    }

    private var selectedProgram: ManagedProgram? {
        let row = tableView.selectedRow
        return rows.indices.contains(row) ? rows[row] : nil
    }

    private func moveSelection(by offset: Int) {
        guard !rows.isEmpty else { return }
        let current = max(tableView.selectedRow, 0)
        let next = min(max(current + offset, 0), rows.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    @objc private func openSelectedProgram() {
        guard let selectedProgram else { return }
        close()
        service.cycleWindows(in: selectedProgram)
    }

    private func persistChanges() {
        store.save(book)
        tableView.reloadData()
        onAssignmentsChanged()
    }
}
