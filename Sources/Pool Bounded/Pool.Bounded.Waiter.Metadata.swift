#if Concurrency

    extension Pool.Bounded.Waiter where Resource: ~Copyable {

        @usableFromInline
        struct Metadata: Sendable {}
    }
#endif
