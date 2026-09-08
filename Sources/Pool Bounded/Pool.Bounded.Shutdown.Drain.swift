#if POOL_CONCURRENCY

    public import Array_Primitive
    public import Async_Waiter
    internal import Buffer_Linear_Bounded_Primitive
    public import Buffer_Linear_Primitive
    internal import Buffer
    internal import Column
    internal import Fixed
    internal import Memory_Allocator_Primitive
    internal import Memory
    internal import Ownership_Shared_Primitive
    internal import Storage_Contiguous

    extension Pool.Bounded.Shutdown where Resource: ~Copyable {

        @usableFromInline
        enum Drain: ~Copyable {

            case drain(
                [(Pool.Bounded<Resource>.Slot.Index, Pool.ID)],
                resumptions: Array<Async.Waiter.Resumption>
            )
            case alreadyShuttingDown
        }
    }
#endif
