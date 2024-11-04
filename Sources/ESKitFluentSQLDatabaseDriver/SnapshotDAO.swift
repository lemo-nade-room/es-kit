import Fluent
import ESKit
import Foundation

final class SnapshotDAO: Fluent.Model, @unchecked Sendable {
    static let schema = "es_kit_snapshots"
    
    @ID
    var id: UUID?
    
    @Field(key: "last_step")
    var lastStep: Int
    
    @Field(key: "aggregate_key")
    var aggregateKey: String
    
    @Field(key: "aggregate_id")
    var aggregateId: String
    
    @Field(key: "data")
    var aggregateJSON: String
    
    init() { }
    
    init<Aggregate: ESKit.Aggregate>(_ aggregate: Aggregate, lastStep: Int, encoder: JSONEncoder) throws {
        self.id = UUID()
        self.lastStep = lastStep
        self.aggregateKey = Aggregate.key
        self.aggregateId = aggregate.id.description
        self.aggregateJSON = String(data: try encoder.encode(aggregate), encoding: .utf8)!
    }
    
    /// DAOを集約に変換する
    /// - Parameters:
    ///   - type: 変換先の集約型
    ///   - decoder: JSONデコーダー
    /// - Returns: 変換された集約
    func toAggregate<Aggregate: ESKit.Aggregate>(_ type: Aggregate.Type, decoder: JSONDecoder) throws -> Aggregate {
        try decoder.decode(Aggregate.self, from: aggregateJSON.data(using: .utf8)!)
    }
}
