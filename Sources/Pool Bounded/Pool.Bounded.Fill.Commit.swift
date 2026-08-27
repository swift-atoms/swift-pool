#if POOL_CONCURRENCY

    public import Array_Primitive
    public import Async_Waiter
    internal import Buffer_Linear_Bounded_Primitive
    internal import Buffer_Linear_Primitive
    internal import Buffer_Primitive
    internal import Column
    internal import Fixed
    internal import Memory_Allocator_Primitive
    internal import Memory_Heap
    internal import Ownership_Shared_Primitive
    internal import Storage_Contiguous

    extension Pool.Bounded.Fill where Resource: ~Copyable {

        @usableFromInline

        enum Commit: ~Copyable {

            case addToPool(
                effect: Pool.Bounded<Resource>.Effect,
                skipped: Array<Async.Waiter.Resumption>
            )

            case handOff(
                Async.Waiter.Resumption,
                skipped: Array<Async.Waiter.Resumption>
            )

            case dispose
        }
    }
#endif
