#if Concurrency
    public import Async
    public import Async_Waiter
    internal import Space

    extension Pool.Bounded where Resource: ~Copyable {

        @usableFromInline
        typealias Outcome = Result<(Slot.Index, Pool.ID), Pool.Lifecycle.Error>

        @usableFromInline
        enum Waiter {}
    }
    extension Pool.Bounded.Waiter where Resource: ~Copyable {

        @usableFromInline
        typealias Entry = Async.Waiter.Entry<Pool.Bounded<Resource>.Outcome, Metadata>

        @usableFromInline
        typealias Flagged = Async.Waiter.Queue.Flagged<Pool.Bounded<Resource>.Outcome, Metadata>
    }
#endif
