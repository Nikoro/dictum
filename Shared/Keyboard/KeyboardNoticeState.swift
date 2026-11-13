struct KeyboardNoticeState: Equatable {
    private(set) var message: String?
    private var dismissed = false

    var visibleMessage: String? {
        dismissed ? nil : message
    }

    mutating func update(_ message: String?) {
        guard self.message != message else { return }
        self.message = message
        dismissed = false
    }

    mutating func dismiss() {
        dismissed = true
    }
}
