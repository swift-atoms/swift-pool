#if Concurrency

    internal import Array_Primitive
    internal import Async_Mutex
    internal import Async
    internal import Async_Waiter

    extension Pool.Bounded where Resource: ~Copyable {

        @usableFromInline
        enum Effect: ~Copyable {

            case none

            case gate(Gate)

            case waiter(Waiter)
        }
    }
#endif
