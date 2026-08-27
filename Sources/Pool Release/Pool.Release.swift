public import Effect
internal import Ownership

extension Pool {

    public struct Release<Resource: ~Copyable>: Effect.`Protocol` {

        public typealias Arguments = Pool.ID

        public typealias Value = Void

        public typealias Failure = Never

        public let id: Pool.ID

        public var arguments: Pool.ID { id }

        @inlinable
        public init(id: Pool.ID) {
            self.id = id
        }
    }
}
