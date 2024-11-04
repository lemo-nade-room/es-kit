import Foundation

/// イベント
///
/// ``Aggregate``（集約）に対するイベント
public protocol Event: Hashable, Codable, Sendable {
    /// イベントに対応する集約
    associatedtype Aggregate: ESKit.Aggregate
    /// イベントのペイロードデータ
    associatedtype Data: Hashable, Codable, Sendable
    
    /// イベント型の識別子
    static var type: String { get }
    
    /// 集約ID
    var aggregateId: Aggregate.Id { get }
    /// イベントのペイロードデータ
    var data: Data { get }
    /// イベント発生時刻
    var createdAt: Date { get }
    
    /// 集約に対してイベントを適用する
    func apply(to aggregate: Aggregate?) -> Aggregate?
    
    /// イベントを初期化する
    init(aggregateId: Aggregate.Id, data: Data, createdAt: Date)
}
