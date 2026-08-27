extension Pool {

    public struct Capacity: Sendable, Hashable {

        @_spi(Internal)
        public let value: Int

        public init(_ value: Int) throws(Pool.Error) {
            guard value > 0 else { throw .capacity(value) }
            self.value = value
        }

        init(unchecked value: Int) {
            self.value = value
        }
    }
}
