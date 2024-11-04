/// イベントを集計するためのクエリビルダ
public protocol EventQueryBuilder: Sendable {
    associatedtype Result: Sendable
    /// 特定のイベントを購読する
    /// - Parameters:
    ///   - on: 購読するイベント型
    ///   - aggregateId: 購読する集約ID。nilの場合は全てのイベントを取得する
    ///   - build: 購読した際の処理
    /// - Returns: 購読を追加したクエリビルダ
    func subscribe<Event: ESKit.Event>(on: Event.Type, aggregateId: Event.Aggregate.Id?, build: @Sendable @escaping (Result, Event) async throws -> Result) -> Self
    
    /// 集計値を生成する
    /// - Returns: 集計結果
    func build() async throws -> Result
}
extension EventQueryBuilder {
    /// 特定のイベントを購読する
    /// - Parameters:
    ///   - on: 購読するイベント型
    ///   - build: 購読した際の処理
    /// - Returns: 購読を追加したクエリビルダ
    public func pipe<Event: ESKit.Event>(on: Event.Type, build: @Sendable @escaping (Result, Event) async throws -> Result) -> Self {
        self.subscribe(on: on, aggregateId: nil, build: build)
    }
}
