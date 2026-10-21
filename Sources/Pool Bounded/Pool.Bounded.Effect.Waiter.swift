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

    extension Pool.Bounded.Effect where Resource: ~Copyable {

        @usableFromInline
        enum Waiter: ~Copyable {

            case resume(Async.Waiter.Resumption)

            case batch(Array<Async.Waiter.Resumption>)
        }
    }
#endif
