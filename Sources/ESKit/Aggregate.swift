/// 集約プロトコル
///
/// グローバルな同一性（識別子）を持つ、変更境界のルートとなるオブジェクト
public protocol Aggregate: Hashable, Codable, Sendable, Identifiable {
    /// 集約ID型
    associatedtype Id: Hashable, Codable, Sendable, LosslessStringConvertible
    
    /// 集約型の識別子
    static var key: String { get }
    
    /// 集約ID
    var id: Id { get }
}
