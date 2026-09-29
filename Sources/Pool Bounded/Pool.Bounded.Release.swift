#if Concurrency

    extension Pool.Bounded where Resource: ~Copyable {

        @usableFromInline
        enum Release {}
    }
#endif
