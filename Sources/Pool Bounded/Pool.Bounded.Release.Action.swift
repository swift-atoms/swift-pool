#if POOL_CONCURRENCY

    public import Array_Primitive
    public import Async_Waiter
    internal import Buffer_Linear_Bounded_Primitive
    internal import Buffer_Linear_Primitive
    internal import Buffer
    internal import Column
    internal import Fixed
    internal import Memory_Allocator_Primitive
    internal import Memory
    internal import Ownership_Shared_Primitive
    internal import Storage_Contiguous

    extension Pool.Bounded.Release where Resource: ~Copyable {

        @usableFromInline
        enum Action: ~Copyable {

            case handOff(
                Async.Waiter.Resumption,
                skipped: Array<Async.Waiter.Resumption>
            )

            case returnToPool(skipped: Array<Async.Waiter.Resumption>)

            case dispose(skipped: Array<Async.Waiter.Resumption>)
        }
    }
#endif
