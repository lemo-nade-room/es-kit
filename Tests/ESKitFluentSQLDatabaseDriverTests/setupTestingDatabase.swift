import NIOPosix
import NIOCore
import Fluent
import FluentSQLiteDriver
import ESKitFluentSQLDatabaseDriver

func setUpTestingDatabase() async throws -> (Database, CleanUp) {
    var cleanUp = CleanUp()
    
    let eventLoopGroup = MultiThreadedEventLoopGroup.singleton
    let threadPool = NIOThreadPool(numberOfThreads: System.coreCount)
    try await threadPool.shutdownGracefully()
    threadPool.start()
    cleanUp.defer { try await threadPool.shutdownGracefully() }
    
    let databases = Databases(threadPool: threadPool, on: eventLoopGroup)
    cleanUp.defer { await databases.shutdownAsync() }
    databases.use(.sqlite(.memory), as: .sqlite)
    
    let migrations = Migrations()
    migrations.add(ESKitFluentSQLDatabaseDriver.migrations)
    
    let logger = Logger(label: "How to use Fluent")
    
    let migrator = Migrator(
        databases: databases,
        migrations: migrations,
        logger: logger,
        on: eventLoopGroup.any(),
        migrationLogLevel: .debug
    )
    
    try await withCheckedThrowingContinuation { continuation in
        let future = migrator
            .setupIfNeeded()
            .flatMap { migrator.prepareBatch() }
        future.whenSuccess { continuation.resume(returning: ()) }
        future.whenFailure { continuation.resume(throwing: $0) }
    }
    
    let db = databases.database(logger: logger, on: eventLoopGroup.any(), history: .init())!
    
    return (db, cleanUp)
}
