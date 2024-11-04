import Foundation

/// イベントのリポジトリ
public protocol Repository: Sendable {
    /// イベントからのクエリビルダ
    associatedtype EventQueryBuilder: ESKit.EventQueryBuilder
    
    /// イベントを登録する
    /// - Parameter type: 登録するイベント型
    mutating func subscribe<Event: ESKit.Event>(_ type: Event.Type)
    
    /// 集約を呼び出し、コマンドからイベントを生成・記録する
    /// - Parameters:
    ///   - aggregateId: 集約ID
    ///   - createEvent: イベントを作成
    /// - Returns: 作成されたイベント
    func command<Event: ESKit.Event>(
        for aggregateId: Event.Aggregate.Id,
        _ createEvent: @Sendable (Event.Aggregate?) async throws -> Event?
    ) async throws -> Event?
    
    /// イベントを呼び出して集計するためのクエリビルダを生成する
    /// - Parameter initial: 初期値
    /// - Returns: クエリビルダ
    func query<Result: Sendable>(_ initial: Result) -> EventQueryBuilder where EventQueryBuilder.Result == Result
    
    /// 集約を検索する
    /// - Parameters:
    ///   - type: 集約型
    ///   - id: 集約ID
    /// - Returns: 検索結果
    func findAggregate<Aggregate: ESKit.Aggregate>(of type: Aggregate.Type, id: Aggregate.Id) async throws -> Aggregate?
}
