#if POOL_CONCURRENCY
    public import Async
    public import Async_Waiter

    extension Pool.Bounded where Resource: ~Copyable {

        @usableFromInline
        typealias Flag = Async.Waiter.Flag
    }
#endif
