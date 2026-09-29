#if Concurrency
    extension Pool.Bounded where Resource: ~Copyable {

        @usableFromInline
        enum Policy: Sendable {

            case eager(Destructor)

            case lazy(Creation)
        }
    }
#endif
