import Fluent

public var migrations: [Migration] {
    var migrations = [Migration]()
    migrations.append(EventDAOMigrateion())
    migrations.append(SnapshotDAOMigrateion())
    return migrations
}
