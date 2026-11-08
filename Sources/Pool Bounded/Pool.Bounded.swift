#if Concurrency
    internal import Array_Primitive
    internal import Array
    public import Async_Mutex
    public import Async_Promise
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

#if Concurrency

    internal import Array_Primitive
    internal import Array
    internal import Fixed
    internal import Ownership
    internal import Collection

    internal import Synchronization

    extension Pool.Bounded where Resource: ~Copyable {

        @usableFromInline
        func acquireSlot() async throws(Pool.Lifecycle.Error) -> (Slot.Index, Pool.ID) {
            guard !Task.isCancelled else {
                throw .cancelled
            }

            let action: Acquire.Action = _state.withLock { state in

                guard !state.lifecycle.shutdown.isActive else {
                    return .shutdown
                }

                if let slotIndex = state.popAvailable() {
                    guard case .available(let id) = state.slots[slotIndex].state else {
                        preconditionFailure("Available ring contains non-available slot")
                    }

                    state.transition(slot: slotIndex, to: .out(id))
                    state.metrics.acquisitions += 1
                    return .immediate(slotIndex, id)
                }

                if case .lazy = policy {
                    if let slotIndex = state.findEmptySlot() {
                        let id = state.nextID(scope: scope)
                        state.transition(slot: slotIndex, to: .creating(id))
                        return .create(slotIndex, id)
                    }
                }

                return .suspend
            }

            switch action {
            case .immediate(let slotIndex, let id):
                return (slotIndex, id)

            case .shutdown:
                throw .shutdown

            case .create(let slotIndex, let id):
                return try await createLazyResource(slotIndex: slotIndex, id: id)

            case .suspend:
                return try await suspendForSlot()
            }
        }

        @usableFromInline
        func createLazyResource(
            slotIndex: Slot.Index,
            id: Pool.ID
        ) async throws(Pool.Lifecycle.Error) -> (Slot.Index, Pool.ID) {

            guard case .lazy(let creation) = policy else {
                preconditionFailure("createLazyResource called with non-lazy policy")
            }

            let created: Resource
            do throws(Pool.Lifecycle.Error) {
                created = try await creation.create()
            } catch {
                var pending = _state.withLock { state in
                    state.transition(slot: slotIndex, to: .empty)
                    return state.fail(
                        waitersWith: state.lifecycle.shutdown.isActive ? .shutdown : error
                    )
                }
                pending.drain { $0.resume() }
                let effect = _state.withLock { state in state.checkShutdownComplete() }
                perform(effect)
                throw _state.withLock { state in
                    state.lifecycle.shutdown.isActive ? .shutdown : error
                }
            }

            var resource = created
            if let check = _check, !check(&resource) {
                _state.withLock { state in
                    state.transition(slot: slotIndex, to: .disposing(id))
                }
                await destructor(resource)
                await complete(disposalAt: slotIndex)
                throw _state.withLock { state in
                    state.lifecycle.shutdown.isActive ? .shutdown : .creationFailed
                }
            }

            entries.underlying[slotIndex.retag(Entry.self)].move.in(resource)

            let shouldDispose = _state.withLock { state in
                guard !state.lifecycle.shutdown.isActive else {
                    state.transition(slot: slotIndex, to: .disposing(id))
                    return true
                }
                state.transition(slot: slotIndex, to: .out(id))
                state.metrics.created += 1
                state.metrics.acquisitions += 1
                return false
            }

            if shouldDispose {
                let resource = entries.underlying[slotIndex.retag(Entry.self)].move.out
                await destructor(resource)
                await complete(disposalAt: slotIndex)
                throw .shutdown
            }

            return (slotIndex, id)
        }

        @usableFromInline
        func replace(slot slotIndex: Slot.Index, id: Pool.ID) async {
            guard case .lazy(let creation) = policy else {
                preconditionFailure("replace called with non-lazy policy")
            }

            let created: Resource
            do throws(Pool.Lifecycle.Error) {
                created = try await creation.create()
            } catch {
                var pending = _state.withLock { state in
                    state.transition(slot: slotIndex, to: .empty)
                    return state.fail(
                        waitersWith: state.lifecycle.shutdown.isActive ? .shutdown : error
                    )
                }
                pending.drain { $0.resume() }
                let effect = _state.withLock { state in state.checkShutdownComplete() }
                perform(effect)
                return
            }

            var resource = created
            if let check = _check, !check(&resource) {
                _state.withLock { state in
                    state.transition(slot: slotIndex, to: .disposing(id))
                }
                await destructor(resource)
                var pending = _state.withLock { state in
                    state.transition(slot: slotIndex, to: .empty)
                    state.metrics.closed += 1
                    return state.fail(
                        waitersWith: state.lifecycle.shutdown.isActive ? .shutdown : .creationFailed
                    )
                }
                pending.drain { $0.resume() }
                let effect = _state.withLock { state in state.checkShutdownComplete() }
                perform(effect)
                return
            }

            entries.underlying[slotIndex.retag(Entry.self)].move.in(resource)

            let commit: Fill.Commit = _state.withLock { state in
                guard !state.lifecycle.shutdown.isActive else {
                    state.transition(slot: slotIndex, to: .disposing(id))
                    return .dispose
                }

                var skipped = Array<Async.Waiter.Resumption>(initialCapacity: 0)
                guard let waiter = state.dequeueEligibleWaiter(skipped: &skipped) else {
                    state.transition(slot: slotIndex, to: .available(id))
                    state.pushAvailable(slotIndex)
                    state.metrics.created += 1
                    return .addToPool(effect: .none, skipped: skipped)
                }

                state.transition(slot: slotIndex, to: .out(id))
                state.metrics.created += 1
                state.metrics.acquisitions += 1
                return .handOff(
                    waiter.resumption(with: .success((slotIndex, id))),
                    skipped: skipped
                )
            }

            switch consume commit {
            case .addToPool(let effect, var skipped):
                skipped.drain { $0.resume() }
                perform(effect)

            case .handOff(let resumption, var skipped):
                skipped.drain { $0.resume() }
                perform(.waiter(.resume(resumption)))

            case .dispose:
                let resource = entries.underlying[slotIndex.retag(Entry.self)].move.out
                await destructor(resource)
                await complete(disposalAt: slotIndex)
            }
        }

        @usableFromInline
        func suspendForSlot() async throws(Pool.Lifecycle.Error) -> (Slot.Index, Pool.ID) {
            let flag = Flag()

            let outcome: Outcome = await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in

                    let immediate: Async.Waiter.Resumption? = _state.withLock { state in
                        let waiter = Waiter.Entry(
                            continuation: Async.Continuation(continuation),
                            flag: flag,
                            metadata: Waiter.Metadata()
                        )

                        guard !state.lifecycle.shutdown.isActive else {
                            return waiter.resumption(with: .failure(.shutdown))
                        }

                        guard !flag.isFlagged else {
                            return waiter.resumption(with: .failure(.cancelled))
                        }

                        if let slotIndex = state.popAvailable() {
                            guard case .available(let id) = state.slots[slotIndex].state else {
                                preconditionFailure("Available ring contains non-available slot")
                            }
                            state.transition(slot: slotIndex, to: .out(id))
                            state.metrics.acquisitions += 1
                            return waiter.resumption(with: .success((slotIndex, id)))
                        }

                        if case .lazy = policy, let slotIndex = state.findEmptySlot() {
                            let id = state.nextID(scope: scope)
                            state.transition(slot: slotIndex, to: .creating(id))
                            return waiter.resumption(with: .success((slotIndex, id)))
                        }

                        state.addWaiter(waiter)
                        return nil
                    }

                    switch consume immediate {
                    case .some(let resumption):
                        perform(.waiter(.resume(resumption)))

                    case .none:
                        #if DEBUG
                            let enqueue = self.enqueue.withLock { $0 }
                            enqueue?()
                        #endif
                    }
                }
            } onCancel: {

                if flag.cancel() {
                    self.pumpWaiters()
                }
            }

            switch outcome {
            case .success(let pair):

                if case .lazy = policy {
                    let mustCreate = _state.withLock { state in
                        if case .creating(let id) = state.slots[pair.0].state, id == pair.1 {
                            return true
                        }
                        return false
                    }
                    if mustCreate {
                        return try await createLazyResource(slotIndex: pair.0, id: pair.1)
                    }
                }
                return pair

            case .failure(let error):
                throw error
            }
        }
    }
#endif

#if Concurrency
    internal import Array_Primitive
    internal import Array
    internal import Ownership
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

    extension Pool.Bounded where Resource: ~Copyable {

        @usableFromInline
        func release(
            _ resource: consuming sending Resource,
            from slotIndex: Slot.Index,
            id: Pool.ID,
            as disposition: Release.Disposition
        ) async -> Pool.Lifecycle.Error? {
            var resource = resource
            let isReusable: Bool
            switch disposition {
            case .reusable:
                isReusable =
                    if let check = _check {
                        check(&resource)
                    } else {
                        true
                    }

            case .invalid:
                isReusable = false
            }

            guard isReusable else {
                _state.withLock { state in
                    guard case .out(let currentId) = state.slots[slotIndex].state,
                        currentId == id
                    else {
                        preconditionFailure("Release called with mismatched slot state or ID")
                    }
                    state.metrics.releases += 1
                    state.transition(slot: slotIndex, to: .disposing(id))
                }

                await destructor(resource)
                await complete(disposalAt: slotIndex)
                return _state.withLock { state in
                    state.lifecycle.shutdown.isActive ? .shutdown : nil
                }
            }

            entries.underlying[slotIndex.retag(Entry.self)].move.in(resource)

            let action: Release.Action = _state.withLock { state in

                guard case .out(let currentId) = state.slots[slotIndex].state,
                    currentId == id
                else {
                    preconditionFailure("Release called with mismatched slot state or ID")
                }

                state.metrics.releases += 1

                var skipped = Array<Async.Waiter.Resumption>(initialCapacity: 0)

                if let waiter = state.dequeueEligibleWaiter(skipped: &skipped) {

                    state.metrics.acquisitions += 1
                    let resumption = waiter.resumption(with: .success((slotIndex, id)))
                    return .handOff(resumption, skipped: skipped)
                } else if state.lifecycle.shutdown.isActive {
                    state.transition(slot: slotIndex, to: .disposing(id))
                    return .dispose(skipped: skipped)
                } else {
                    state.transition(slot: slotIndex, to: .available(id))
                    state.pushAvailable(slotIndex)
                    return .returnToPool(skipped: skipped)
                }
            }

            switch consume action {
            case .handOff(let resumption, var skipped):
                skipped.drain { $0.resume() }

                perform(.waiter(.resume(resumption)))

            case .returnToPool(var skipped):
                skipped.drain { $0.resume() }

                let effect: Effect = _state.withLock { state in
                    state.checkShutdownComplete()
                }
                perform(effect)

            case .dispose(var skipped):
                skipped.drain { $0.resume() }

                let resource = entries.underlying[slotIndex.retag(Entry.self)].move.out

                await destructor(resource)

                let effect: Effect = _state.withLock { state in
                    state.transition(slot: slotIndex, to: .empty)
                    state.metrics.closed += 1
                    return state.checkShutdownComplete()
                }
                perform(effect)
                return .shutdown
            }

            return nil
        }

        @usableFromInline
        func complete(disposalAt slotIndex: Slot.Index) async {
            let replacement: (Slot.Index, Pool.ID)? = _state.withLock { state in
                state.transition(slot: slotIndex, to: .empty)
                state.metrics.closed += 1

                guard !state.lifecycle.shutdown.isActive,
                    case .lazy = policy,
                    state.metrics.waiters > 0
                else {
                    return nil
                }

                let id = state.nextID(scope: scope)
                state.transition(slot: slotIndex, to: .creating(id))
                return (slotIndex, id)
            }

            let effect = _state.withLock { state in
                state.checkShutdownComplete()
            }
            perform(effect)

            if let (slotIndex, id) = replacement {
                await replace(slot: slotIndex, id: id)
            }
        }
    }

    extension Pool.Bounded where Resource: ~Copyable {

        @usableFromInline
        func pumpWaiters() {

            var pending: Array<Async.Waiter.Resumption> = _state.withLock { state in
                state.reapFlaggedWaiters()
            }

            pending.drain { $0.resume() }
        }
    }
#endif

#if Concurrency
    extension Pool.Bounded where Resource: ~Copyable {

        @usableFromInline
        typealias Destructor = @Sendable (consuming Resource) async -> Void
    }

    extension Pool.Bounded where Resource: ~Copyable {

        @usableFromInline
        var destructor: @Sendable (consuming Resource) async -> Void {
            switch policy {
            case .eager(let d): return d

            case .lazy(let c): return c.destroy
            }
        }
    }
#endif

#if Concurrency
    extension Pool.Bounded where Resource: ~Copyable {

        @usableFromInline
        typealias Entry = Ownership.Slot<Resource>
    }
#endif

#if Concurrency
    import Async
    public import Async_Waiter

    extension Pool.Bounded where Resource: ~Copyable {

        @usableFromInline
        typealias Flag = Async.Waiter.Flag
    }
#endif
