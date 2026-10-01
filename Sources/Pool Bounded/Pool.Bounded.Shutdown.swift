#if Concurrency

    internal import Array_Primitive
    internal import Array
    internal import Async_Mutex
    internal import Async
    internal import Async_Promise
    internal import Async_Waiter
    internal import Space
    internal import Ownership
    internal import Queue_Primitive
    internal import Queue
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

        public var shutdown: Shutdown {
            Shutdown(pool: self)
        }
    }

    extension Pool.Bounded where Resource: ~Copyable {

        public struct Shutdown: Sendable {
            @usableFromInline
            let pool: Pool.Bounded<Resource>

            @usableFromInline
            init(pool: Pool.Bounded<Resource>) {
                self.pool = pool
            }
        }
    }

    extension Pool.Bounded.Shutdown where Resource: ~Copyable {

        nonisolated(nonsending)
            public func callAsFunction() async
        {

            let action: Drain = pool._state.withLock { state in

                guard state.lifecycle.shutdown.begin() else {
                    return .alreadyShuttingDown
                }

                var slotsToDrain: [(Pool.Bounded<Resource>.Slot.Index, Pool.ID)] = []
                while let slotIndex = state.popAvailable() {
                    guard case .available(let id) = state.slots[slotIndex].state else {
                        continue
                    }

                    state.transition(slot: slotIndex, to: .disposing(id))
                    slotsToDrain.append((slotIndex, id))
                }

                var resumptions = Array<Async.Waiter.Resumption>(initialCapacity: 0)
                state.waiters.drain { entry in
                    resumptions.append(entry.resumption(with: .failure(.shutdown)))
                }
                state.metrics.waiters = 0

                return .drain(slotsToDrain, resumptions: resumptions)
            }

            switch consume action {
            case .alreadyShuttingDown:
                await pool.shutdownGate.wait()
                return

            case .drain(let slotsToDrain, var resumptions):

                resumptions.drain { $0.resume() }

                for (slotIndex, _) in slotsToDrain {

                    let entryIndex = slotIndex.retag(Pool.Bounded<Resource>.Entry.self)
                    let resource = pool.entries.underlying[entryIndex].move.out

                    await pool.destructor(resource)

                    let effect: Pool.Bounded<Resource>.Effect = pool._state.withLock { state in
                        state.transition(slot: slotIndex, to: .empty)
                        state.metrics.closed += 1
                        return state.checkShutdownComplete()
                    }
                    pool.perform(effect)
                }

                if slotsToDrain.isEmpty {
                    let effect: Pool.Bounded<Resource>.Effect = pool._state.withLock { state in
                        state.checkShutdownComplete()
                    }
                    pool.perform(effect)
                }

                await pool.shutdownGate.wait()
            }
        }
    }
#endif
