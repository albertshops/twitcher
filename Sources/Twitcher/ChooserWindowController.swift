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

private enum ChooserRow {
    case program(ManagedProgram)
    case window(ManagedWindow)

    var target: AssignmentTarget {
        switch self {
        case let .program(program):
            .program(program.identity)
        case let .window(window):
            .window(window.identity)
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
    private var rows: [ChooserRow] = []
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
        let chooserRow = rows[row]
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
            text.stringValue = book.letter(for: chooserRow.target).map { "⌥\(String($0).uppercased())" } ?? "—"
            text.alignment = .center
            text.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        case "app":
            switch chooserRow {
            case let .program(program):
                text.stringValue = program.identity.name
                text.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            case .window:
                text.stringValue = "    ↳ Window"
                text.textColor = .secondaryLabelColor
            }
        default:
            switch chooserRow {
            case let .program(program):
                let count = program.windows.count
                let suffix = count == 1 ? "window" : "windows"
                text.stringValue = count == 1 ? program.windows[0].title : "Cycles through \(count) \(suffix)"
                text.textColor = .secondaryLabelColor
            case let .window(window):
                text.stringValue = window.title + (window.isMinimized ? "  (minimized)" : "")
            }
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
        let instructions = NSTextField(labelWithString: "A–Z assigns; Return opens; Delete clears. Program shortcuts cycle unassigned windows.")
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
        tableView.doubleAction = #selector(openSelectedTarget)

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
        rows = service.programs().flatMap { program in
            var programRows: [ChooserRow] = [.program(program)]
            let hasAssignedWindow = program.windows.contains {
                book.letter(for: .window($0.identity)) != nil
            }
            if program.windows.count > 1 || hasAssignedWindow {
                programRows.append(contentsOf: program.windows.map(ChooserRow.window))
            }
            return programRows
        }
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
            openSelectedTarget()
            return true
        case 51, 117: // Delete or forward delete
            guard let selectedRow else { return true }
            book.remove(target: selectedRow.target)
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
                  let selectedRow
            else { return false }
            if case let .window(identity) = selectedRow.target,
               service.matchingWindow(for: identity) == nil {
                NSSound.beep()
                return true
            }
            book.assign(character, to: selectedRow.target)
            persistChanges()
            return true
        }
    }

    private var selectedRow: ChooserRow? {
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

    @objc private func openSelectedTarget() {
        guard let selectedRow else { return }
        close()
        switch selectedRow {
        case let .program(program):
            service.cycleWindows(in: program)
        case let .window(window):
            service.focus(window)
        }
    }

    private func persistChanges() {
        store.save(book)
        tableView.reloadData()
        onAssignmentsChanged()
    }
}
