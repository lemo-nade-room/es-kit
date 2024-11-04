struct CleanUp: Sendable {
    var run: @Sendable () async throws -> Void = {}
    
    mutating func `defer`(_ callback: @Sendable @escaping () async throws -> Void) {
        let run = self.run
        self.run = { () async throws -> Void in
            try await callback()
            try await run()
        }
    }
}
