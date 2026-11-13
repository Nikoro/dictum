struct TimeLimitExceeded: Error {}

func withTimeLimit<Value: Sendable>(
    _ limit: Duration,
    operation: @escaping @Sendable () async throws -> Value
) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: limit)
            throw TimeLimitExceeded()
        }
        defer { group.cancelAll() }
        guard let first = try await group.next() else { throw TimeLimitExceeded() }
        return first
    }
}
