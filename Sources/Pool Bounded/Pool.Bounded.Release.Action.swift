#if Concurrency

    public import Array_Primitive
    public import Async_Waiter
    internal import Buffer_Linear_Bounded_Primitive
    internal import Buffer_Linear_Primitive
    internal import Buffer
    internal import Buffer_Ring_Primitive
    internal import Memory_Allocator_Pool
    internal import Memory_Pool
    internal import Memory_Allocator
    internal import Memory
    internal import Ownership_Shared_Primitive
    internal import Storage
    internal import Store
    internal import Fixed

    extension Pool.Bounded.Release where Resource: ~Copyable {

        @usableFromInline
        enum Action: ~Copyable {

            case handOff(
                Async.Waiter.Resumption,
                skipped: [Async.Waiter.Resumption]
            )

            case returnToPool(skipped: [Async.Waiter.Resumption])

            case dispose(skipped: [Async.Waiter.Resumption])
        }
    }
#endif
