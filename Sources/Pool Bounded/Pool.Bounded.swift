#if Concurrency
    internal import Array_Primitive
    internal import Array
    public import Async_Mutex
    internal import Async
    public import Async_Promise
    internal import Async_Waiter
    internal import Ownership
    @_spi(Internal) internal import Pool_Capacity
    @_spi(Internal) internal import Pool_Scope
    internal import Collection

    internal import Synchronization
    internal import Buffer
    internal import Buffer_Linear_Primitive
    internal import Buffer_Linear_Bounded_Primitive
    internal import Buffer_Ring_Primitive
    internal import Memory_Allocator_Pool
    internal import Memory_Pool
    internal import Memory_Allocator
    internal import Memory
    internal import Ownership_Shared_Primitive
    internal import Storage
    internal import Store
    internal import Fixed

    extension Pool {

        public final class Bounded<Resource: ~Copyable>: Sendable {

            @usableFromInline
            let _state: Async.Mutex<State>

            @usableFromInline
            let shutdownGate: Async.Gate

            @usableFromInline
            let scope: Pool.Scope

            @usableFromInline
            let policy: Policy

            @usableFromInline
            let _check: (@Sendable (inout Resource) -> Bool)?

            let entries: Tagged<Slot, Fixed<Entry>>

            #if DEBUG

                let enqueue = Mutex<(@Sendable () -> Void)?>(nil)
            #endif

            public init(
                capacity: Pool.Capacity,
                check: (@Sendable (inout Resource) -> Bool)? = nil,
                destroy: @escaping @Sendable (consuming Resource) async -> Void
            ) {
                self._state = Async.Mutex(State(capacity: capacity.value))
                self.shutdownGate = Async.Gate()
                self.scope = Pool.Scope()
                self.policy = .eager(destroy)
                self._check = check

                do {
                    self.entries = Tagged<Slot, Fixed<Entry>>(
                        try Fixed<Entry>(
                            count: Index<Entry>.Count(capacity.value),
                            initializingWith: { _ in Entry() }
                        )
                    )
                } catch {
                    preconditionFailure(
                        """
                        Pool.Bounded entry storage could not be sized \
                        for capacity \(capacity.value): \(error)
                        """
                    )
                }
            }

            public init(
                capacity: Pool.Capacity,
                check: (@Sendable (inout Resource) -> Bool)? = nil,
                create:
                    @escaping @Sendable () async throws(Pool.Lifecycle.Error) -> sending Resource,
                destroy: @escaping @Sendable (consuming Resource) async -> Void
            ) {
                self._state = Async.Mutex(State(capacity: capacity.value))
                self.shutdownGate = Async.Gate()
                self.scope = Pool.Scope()
                self.policy = .lazy(Creation(create: create, destroy: destroy))
                self._check = check

                do {
                    self.entries = Tagged<Slot, Fixed<Entry>>(
                        try Fixed<Entry>(
                            count: Index<Entry>.Count(capacity.value),
                            initializingWith: { _ in Entry() }
                        )
                    )
                } catch {
                    preconditionFailure(
                        """
                        Pool.Bounded entry storage could not be sized \
                        for capacity \(capacity.value): \(error)
                        """
                    )
                }
            }

            deinit {
                let isSafeToDeinitialize = _state.withLock { state in
                    state.lifecycle == .closed
                        || (state.lifecycle == .open
                            && state.metrics.available == 0
                            && state.outstanding == 0
                            && state.creating == 0
                            && state.disposing == 0)
                }
                precondition(
                    isSafeToDeinitialize,
                    "Pool.Bounded with live resources must complete shutdown before deinitialization"
                )
            }
        }
    }

    extension Pool.Bounded where Resource: ~Copyable {

        public var metrics: Pool.Metrics {
            _state.withLock { $0.metrics }
        }
    }

    extension Pool.Bounded where Resource: ~Copyable {

        @inline(always)
        func perform(_ effect: consuming Effect) {
            switch effect {
            case .none:
                return

            case .gate(.open):
                _ = shutdownGate.open()

            case .waiter(.resume(let resumption)):
                resumption.resume()

            case .waiter(.batch(var resumptions)):
                resumptions.drain { $0.resume() }
            }
        }
    }

#endif
