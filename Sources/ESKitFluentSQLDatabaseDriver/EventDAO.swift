import Fluent
import ESKit
import Foundation

/// イベントのDAO
final class EventDAO: Fluent.Model, @unchecked Sendable {
    static let schema = "es_kit_events"
    
    @ID
    var id: UUID?
    
    @Field(key: "type")
    var type: String
    
    @Field(key: "step")
    var step: Int
    
    @Field(key: "aggregate_key")
    var aggregateKey: String
    
    @Field(key: "aggregate_id")
    var aggregateId: String
    
    @Field(key: "data")
    var dataJSON: String
    
    @Field(key: "created_at")
    var createdAt: Date
    
    init() { }
    
    init<Event: ESKit.Event>(_ event: Event, step: Int, encoder: JSONEncoder = .init()) throws {
        self.id = UUID()
        self.type = Event.type
        self.step = step
        self.aggregateKey = Event.Aggregate.key
        self.aggregateId = event.aggregateId.description
        self.dataJSON = String(data: try encoder.encode(event.data), encoding: .utf8)!
        self.createdAt = event.createdAt
    }
    
    /// イベント具象型に変換する
    /// - Parameters:
    ///   - type: イベント型
    ///   - decoder: JSONデコーダー
    /// - Returns: 変更されたイベント値
    func toEvent<Event: ESKit.Event>(_ type: Event.Type, decoder: JSONDecoder = .init()) throws -> Event {
        guard let aggregateId = Event.Aggregate.Id(self.aggregateId) else {
            throw ConvertAggregateIdError(
                aggregateId: aggregateId,
                aggregateKey: Event.Aggregate.key
            )
        }
        let data = try decoder.decode(Event.Data.self, from: dataJSON.data(using: .utf8)!)
        return .init(aggregateId: aggregateId, data: data, createdAt: createdAt)
    }
    
    /// 集約IDをキャストできない場合に発生するエラー
    ///
    /// データ不整合時のみ発生する
    struct ConvertAggregateIdError: Error {
        var aggregateId: String
        var aggregateKey: String
    }
}

extension EventDAO: Comparable {
    static func < (lhs: EventDAO, rhs: EventDAO) -> Bool {
        if lhs.type == rhs.type {
            return lhs.step < rhs.step
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        guard let rhsId = rhs.id else {
            return true
        }
        guard let lhsId = lhs.id else {
            return false
        }
        return lhsId < rhsId
    }
    
    static func == (lhs: EventDAO, rhs: EventDAO) -> Bool {
        lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.step == rhs.step &&
        lhs.aggregateKey == rhs.aggregateKey &&
        lhs.aggregateId == rhs.aggregateId &&
        lhs.dataJSON == rhs.dataJSON &&
        lhs.createdAt == rhs.createdAt
    }
}
