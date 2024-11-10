import Testing
import ESKitFluentSQLDatabaseDriver
import NIOPosix
import NIOCore
import Fluent
import FluentSQLiteDriver
import ESKit
import Foundation

fileprivate struct Todos: Aggregate {
    static let key = "todos"
    /// ユーザーID
    var id: String
    var todos: [Todo]
    
    struct Todo: Hashable, Codable, Sendable {
        var title: String
        var state: State
        enum State: Hashable, Codable, Sendable {
            case todo, doing, done
        }
    }
}

fileprivate struct TodoCreated: ESKit.Event {
    typealias Aggregate = Todos
    static let type = "todoCreated"
    
    struct Data: Hashable, Codable, Sendable {
        var title: String
    }
    
    var aggregateId: String
    var data: Data
    var createdAt: Date
    
    func apply(to aggregate: Todos?) -> Todos? {
        let newTodo = Todos.Todo(title: data.title, state: .todo)
        if var aggregate {
            aggregate.todos.append(newTodo)
            return aggregate
        } else {
            return .init(id: aggregateId, todos: [newTodo])
        }
    }
}

fileprivate struct TodoStateChanged: ESKit.Event {
    typealias Aggregate = Todos
    static let type = "todoStateChanged"
    
    struct Data: Hashable, Codable, Sendable {
        var index: Int
        var state: Todos.Todo.State
    }
    
    var aggregateId: String
    var data: Data
    var createdAt: Date
    
    func apply(to aggregate: Todos?) -> Todos? {
        guard var aggregate else {
            fatalError()
        }
        aggregate.todos[data.index].state = data.state
        return aggregate
    }
}

extension Todos? {
    fileprivate func create(userId: String, title: String, at: Date) throws -> TodoCreated {
        .init(aggregateId: userId, data: .init(title: title), createdAt: at)
    }
    fileprivate func changeState(index: Int, state: Todos.Todo.State, at: Date) throws -> TodoStateChanged {
        guard let self else { throw NotFoundError() }
        if self.todos[index].state == state {
            throw AlreadyStateChangedError()
        }
        return .init(aggregateId: self.id, data: .init(index: index, state: state), createdAt: at)
    }
    
    struct NotFoundError: Error {}
    struct AlreadyStateChangedError: Error {}
}


@Suite struct EventRepositoryTests {
    @Test func イベントを作成しクエリする() async throws {
        // Arrange
        let (db, cleanUp) = try await setUpTestingDatabase()
        defer { Task { try await cleanUp.run() } }
        var sut = EventRepository(on: db, encoder: .init(), decoder: .init())
        sut.subscribe(TodoCreated.self)
        sut.subscribe(TodoStateChanged.self)

        // Act & Assert
        _ = try await sut.command(for: "user1") { aggregate -> TodoCreated in
            #expect(aggregate == nil)
            return try aggregate.create(userId: "user1", title: "初めてのTodo", at: Date(timeIntervalSince1970: 1000))
        }
        
        _ = try await sut.command(for: "user2") { aggregate -> TodoCreated in
            #expect(aggregate == nil)
            return try aggregate.create(userId: "user2", title: "初めてのTodo by: user2", at: Date(timeIntervalSince1970: 1500))
        }
        
        _ = try await sut.command(for: "user1") { aggregate -> TodoCreated in
            #expect(aggregate == .init(id: "user1", todos: [.init(title: "初めてのTodo", state: .todo)]))
            return try aggregate.create(userId: "user1", title: "2回目のTodo", at: Date(timeIntervalSince1970: 2000))
        }
        
        _ = try await sut.command(for: "user1") { aggregate -> TodoStateChanged in
            #expect(aggregate == .init(id: "user1", todos: [
                .init(title: "初めてのTodo", state: .todo),
                .init(title: "2回目のTodo", state: .todo),
            ]))
            return try aggregate.changeState(index: 1, state: .doing, at: Date(timeIntervalSince1970: 3000))
        }
        
        _ = try await sut.command(for: "user2") { aggregate -> TodoStateChanged in
            #expect(aggregate == .init(id: "user2", todos: [
                .init(title: "初めてのTodo by: user2", state: .todo),
            ]))
            return try aggregate.changeState(index: 0, state: .done, at: Date(timeIntervalSince1970: 3500))
        }

        _ = try await sut.command(for: "user1") { aggregate -> TodoStateChanged in
            #expect(aggregate == .init(id: "user1", todos: [
                .init(title: "初めてのTodo", state: .todo),
                .init(title: "2回目のTodo", state: .doing),
            ]))
            return try aggregate.changeState(index: 1, state: .done, at: Date(timeIntervalSince1970: 4000))
        }
        
        _ = try await sut.command(for: "user2") { aggregate -> TodoStateChanged in
            #expect(aggregate == .init(id: "user2", todos: [
                .init(title: "初めてのTodo by: user2", state: .done),
            ]))
            return try aggregate.changeState(index: 0, state: .doing, at: Date(timeIntervalSince1970: 4500))
        }
        
        #expect(try await sut.findAggregate(of: Todos.self, id: "user1") == .init(id: "user1", todos: [
            .init(title: "初めてのTodo", state: .todo),
            .init(title: "2回目のTodo", state: .done),
        ]))
        #expect(try await sut.findAggregate(of: Todos.self, id: "user2") == .init(id: "user2", todos: [
            .init(title: "初めてのTodo by: user2", state: .doing),
        ]))
        
        // detachedしたタスクが、DBコネクション閉じるまでに発動させるため
        try await Task.sleep(nanoseconds: 1_000_000)
    }
}
