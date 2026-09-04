#if POOL_CONCURRENCY

    public import Array_Primitive
    public import Async_Waiter
    internal import Buffer_Linear_Bounded_Primitive
    internal import Buffer_Linear_Primitive
    internal import Buffer_Primitive
    internal import Column
    internal import Fixed
    internal import Memory_Allocator_Primitive
    internal import Memory
    internal import Ownership_Shared_Primitive
    internal import Storage_Contiguous

    extension Pool.Bounded.Effect where Resource: ~Copyable {

        @usableFromInline
        enum Waiter: ~Copyable {

            case resume(Async.Waiter.Resumption)

            case batch(Array<Async.Waiter.Resumption>)
        }
    }
#endif
