import ESKit

public struct EventQueryBuilder<Result: Sendable>: ESKit.EventQueryBuilder {
    
    private var repository: Repository
    private var initial: Result
    private var builders = [String: Builder]()
    
    public init(repository: Repository, initial: Result) {
        self.repository = repository
        self.initial = initial
    }
    
    public func subscribe<Event: ESKit.Event>(on: Event.Type, aggregateId: Event.Aggregate.Id? = nil, build: @Sendable @escaping (Result, Event) async throws -> Result) -> Self {
        var builder = self
        builder.builders[Event.type] = .init(aggregateId: aggregateId?.description) { result, eventDAO in
            let event = try eventDAO.toEvent(Event.self)
            return try await build(result, event)
        }
        return builder
    }
    
    public func build() async throws -> Result {
        let eventDAOList = try await repository.findEventDAOList(Set(builders.map { (key, value) in
                .init(type: key, aggregateId: value.aggregateId)
        }))
        var result = self.initial
        for eventDAO in eventDAOList {
            guard let builder = builders[eventDAO.type] else {
                continue
            }
            result = try await builder.build(result, eventDAO)
        }
        return result
    }
    
    private struct Builder: Sendable {
        var aggregateId: String?
        var build: @Sendable (Result, EventDAO) async throws -> Result
    }
}
