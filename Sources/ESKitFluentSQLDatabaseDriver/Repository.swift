import ESKit
import Fluent
import Foundation

/// SQLを使用したイベントのリポジトリ
public struct Repository: ESKit.Repository {
    
    public typealias EventQueryBuilder = ESKitFluentSQLDatabaseDriver.EventQueryBuilder<any Sendable>
    
    /// 集約へイベントを適用する関数の型
    private typealias ApplyFunc = @Sendable (EventDAO, (any Aggregate)?) throws -> (any Aggregate)?
    
    /// Event型識別子に対する、イベントを集約へ適用する関数のディクショナリ
    private var applies: [String: ApplyFunc] = [:]
    /// FluentのDatabase
    public var db: Fluent.Database
    /// JSONエンコーダー
    public var encoder: JSONEncoder
    /// JSONデコーダー
    public var decoder: JSONDecoder
    
    /// イベントリポジトリを初期化する
    /// - Parameters:
    ///   - db: Fluentのデータベース
    ///   - encoder: JSONエンコーダー
    ///   - decoder: JSONデコーダー
    public init(on db: Fluent.Database, encoder: JSONEncoder, decoder: JSONDecoder) {
        self.db = db
        self.encoder = encoder
        self.decoder = decoder
    }
    
    public mutating func subscribe<Event: ESKit.Event>(_ type: Event.Type) {
        applies[Event.type] = { (dao, aggregate) in
            let event = try dao.toEvent(Event.self)
            guard let aggregate else {
                return event.apply(to: nil)
            }
            guard let aggregate = aggregate as? Event.Aggregate else {
                throw CommandError.aggregateTypeCast
            }
            return event.apply(to: aggregate)
        }
    }
    
    public func command<Event: ESKit.Event>(
        for aggregateId: Event.Aggregate.Id,
        _ operation: @Sendable (Event.Aggregate?) async throws -> Event?
    ) async throws -> Event? {
        let result = try await fullReplay(of: Event.Aggregate.self, id: aggregateId)
        guard let event = try await operation(result.aggregate) else {
            return nil
        }
        let dao = try EventDAO(event, step: result.lastStep + 1, encoder: encoder)
        try await dao.create(on: db)
        return event
    }
    
    public func query<Result: Sendable>(_ initial: Result) -> ESKitFluentSQLDatabaseDriver.EventQueryBuilder<Result> {
        .init(repository: self, initial: initial)
    }
    
    public func findAggregate<Aggregate: ESKit.Aggregate>(of type: Aggregate.Type, id: Aggregate.Id) async throws -> Aggregate? {
        try await fullReplay(of: Aggregate.self, id: id).aggregate
    }
    
    /// ``command(for:_:)``実行時に投げるエラー
    public enum CommandError: Error, Hashable, Codable, Sendable {
        case aggregateTypeCast
        case unkonownEventType(type: String)
    }
    
    /// それぞれのfilterのどれかに当てはまったDAOをすべて検索する
    /// - Parameter filters: イベントの検索条件。filter間はORで検索する
    /// - Returns: 検索結果
    internal func findEventDAOList(_ filters: Set<EventFilter>) async throws -> [EventDAO] {
        try await EventDAO.query(on: db).group(.or) { orGroup in
            for filter in filters {
                guard let aggregateId = filter.aggregateId else {
                    orGroup.filter(\.$type == filter.type)
                    continue
                }
                orGroup.group(.and) { andGroup in
                    andGroup
                        .filter(\.$type == filter.type)
                        .filter(\.$aggregateId == aggregateId)
                }
            }
        }.all().sorted()
    }
    
    /// イベント詳細検索時のフィルター
    internal struct EventFilter: Sendable, Hashable {
        /// イベントの型識別子
        var type: String
        /// 集約ID。存在しない場合は全て
        var aggregateId: String?
    }
    
    /// イベントとスナップショットをDBから取得し、集約をリプレイして取得する
    ///
    /// その際、Snapshotのアップデートも実施する
    /// - Parameters:
    ///   - of: 集約型
    ///   - id: 集約ID
    /// - Returns: リプレイされた集約とイベント、スナップショット
    private func fullReplay<Aggregate: ESKit.Aggregate>(of: Aggregate.Type, id: Aggregate.Id) async throws -> ReplayResult<Aggregate> {
        var result = ReplayResult<Aggregate>()
        
        result.snapshotDAO = try await findSnapshot(of: Aggregate.self, id: id)
        result.eventDAOList = try await findAllEventDAOList(of: Aggregate.self, id, over: result.lastStep)
        let snapshotAggregate = try result.snapshotDAO?.toAggregate(Aggregate.self, decoder: decoder)
        result.aggregate = try replay(from: snapshotAggregate, eventDAOList: result.eventDAOList)
         
        try detacheUpdateSnapshot(result)
        
        return result
    }
    
    /// イベントとスナップショットをリプレイして集約を取得する
    /// - Parameters:
    ///   - snapshot: スナップショット
    ///   - eventDAOList: スナップショット以降のイベントリスト
    /// - Returns: リプレイして作成した集約
    private func replay<Aggregate: ESKit.Aggregate>(from snapshot: Aggregate?, eventDAOList: [EventDAO]) throws -> Aggregate? {
        var aggregate = snapshot
        for dao in eventDAOList {
            aggregate = try apply(dao: dao, aggregate: aggregate)
        }
        return aggregate
    }
    
    private struct ReplayResult<Aggregate: ESKit.Aggregate>: Sendable {
        var snapshotDAO: SnapshotDAO? = nil
        var eventDAOList: [EventDAO] = []
        var aggregate: Aggregate? = nil
        
        var lastStep: Int {
            eventDAOList.last?.step ?? snapshotDAO?.lastStep ?? 0
        }
    }
    
    /// イベントのDAOを集約に適用する
    /// - Parameters:
    ///   - dao: イベントのDAO
    ///   - aggregate: 元の集約
    /// - Returns: 適用後の集約
    private func apply<Aggregate: ESKit.Aggregate>(dao: EventDAO, aggregate: Aggregate?) throws -> Aggregate? {
        guard let apply = applies[dao.type] else {
            throw CommandError.unkonownEventType(type: dao.type)
        }
        let applied = try apply(dao, aggregate)
        guard let casted = applied as? Aggregate else {
            throw CommandError.aggregateTypeCast
        }
        return casted
    }
    
    /// 集約のスナップショットを取得する
    /// - Parameters:
    ///   - type: 集約型
    ///   - id: 集約ID
    /// - Returns: 発見された集約のスナップショット
    private func findSnapshot<Aggregate: ESKit.Aggregate>(of type: Aggregate.Type, id: Aggregate.Id) async throws -> SnapshotDAO? {
        try await SnapshotDAO.query(on: db)
            .filter(\.$aggregateKey == Aggregate.key)
            .filter(\.$aggregateId == id.description)
            .first()
    }
    
    /// 指定stepよりstepが大きい、集約IDに対応するイベントDAOを検索する
    /// - Parameters:
    ///   - type: 集約型
    ///   - aggregateId: 集約ID
    ///   - step: step番号。このstep番号よりも大きいもののみにフィルタリングされる
    /// - Returns: 検索結果
    private func findAllEventDAOList<Aggregate: ESKit.Aggregate>(of type: Aggregate.Type, _ aggregateId: Aggregate.Id, over step: Int) async throws -> [EventDAO] {
        try await EventDAO.query(on: db)
            .filter(\.$aggregateKey == Aggregate.key)
            .filter(\.$aggregateId == aggregateId.description)
            .filter(\.$step > step)
            .all()
            .sorted()
    }
    
    /// 別タスクで、スナップショットの更新を実施する
    /// - Parameter result: リプレイを実施した結果
    private func detacheUpdateSnapshot(_ result: ReplayResult<some Aggregate>) throws {
        guard let aggregate = result.aggregate else { return }
        let next = try SnapshotDAO(aggregate, lastStep: result.lastStep, encoder: encoder)
        let db = db
        Task.detached {
            try await db.transaction { transaction in
                try await result.snapshotDAO?.delete(on: transaction)
                try await next.create(on: transaction)
            }
        }
    }
}
