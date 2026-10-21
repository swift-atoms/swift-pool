#if Concurrency

    public import Array_Primitive
    public import Async_Waiter
    internal import Buffer_Linear_Bounded_Primitive
    public import Buffer_Linear_Primitive
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
