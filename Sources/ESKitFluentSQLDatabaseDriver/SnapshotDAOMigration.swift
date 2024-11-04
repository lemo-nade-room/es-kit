import Fluent
import SQLKit

struct SnapshotDAOMigrateion: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("es_kit_snapshots")
            .id()
            .field("last_step", .int, .required)
            .field("aggregate_key", .string, .required)
            .field("aggregate_id", .string, .required)
            .field("data", .string, .required)
            .unique(on: "aggregate_key", "aggregate_id")
            .create()
    }
    func revert(on database: any Database) async throws {
        try await database.schema("es_kit_snapshots").delete()
    }
}
