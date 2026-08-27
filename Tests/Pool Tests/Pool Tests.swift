import Pool
import Testing

@Suite
struct `Pool Tests` {

    @Test
    func `Pool namespace exists`() {
        _ = Pool.self
    }
}
