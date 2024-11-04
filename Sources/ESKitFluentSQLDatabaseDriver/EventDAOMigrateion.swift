import Fluent
import SQLKit

struct EventDAOMigrateion: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("es_kit_events")
            .id()
            .field("type", .string, .required)
            .field("step", .int, .required)
            .field("aggregate_key", .string, .required)
            .field("aggregate_id", .string, .required)
            .field("data", .string, .required)
            .field("created_at", .datetime, .required)
            .unique(on: "aggregate_id", "aggregate_id", "step")
            .create()
        if let sql = database as? SQLDatabase {
            try await sql.create(index: "es_kit_events_aggregate_key_aggregate_id_index")
                .on("es_kit_events")
                .column("type")
                .column("step")
                .run()
        }
    }
    func revert(on database: any Database) async throws {
        try await database.schema("es_kit_events").delete()
    }
}
