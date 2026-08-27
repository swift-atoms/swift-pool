public import Pool

extension Pool.Capacity: ExpressibleByIntegerLiteral {

    public init(integerLiteral value: Int) {
        precondition(value > 0, "Capacity literal must be > 0")
        self = try! Pool.Capacity(value)
    }
}
