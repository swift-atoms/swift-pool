#if Concurrency

    public import Either
    internal import Fixed
    internal import Ownership
    internal import Collection

    extension Pool.Bounded where Resource: ~Copyable {

        public var acquire: Acquire {
            Acquire(pool: self)
        }
    }

    extension Pool.Bounded where Resource: ~Copyable {

        public struct Acquire: Sendable {
            @usableFromInline
            let pool: Pool.Bounded<Resource>

            @usableFromInline
            init(pool: Pool.Bounded<Resource>) {
                self.pool = pool
            }
        }
    }

    extension Pool.Bounded.Acquire where Resource: ~Copyable {

        nonisolated(nonsending) public func callAsFunction<T: ~Copyable, E: Swift::Error>(
            _ body:
                nonisolated(nonsending) (inout sending Resource) async throws(E)
                -> sending Pool.Bounded<Resource>.Disposition<T>
        ) async throws(Either<Pool.Lifecycle.Error, E>) -> sending T {
            while true {
                let slot: (Pool.Bounded<Resource>.Slot.Index, Pool.ID)
                do throws(Pool.Lifecycle.Error) {
                    slot = try await pool.acquireSlot()
                } catch {
                    throw .left(error == .cancelled ? pool.cancellation() : error)
                }
                let (slotIndex, id) = slot
                var resource = pool.entries.underlying[
                    slotIndex.retag(Pool.Bounded<Resource>.Entry.self)
                ].move.out

                if let check = pool._check, !check(&resource) {
                    if let error = await pool.release(
                        resource,
                        from: slotIndex,
                        id: id,
                        as: .invalid
                    ) {
                        throw .left(error)
                    }
                    continue
                }

                let isShutdown = pool._state.withLock { state in
                    state.lifecycle.shutdown.isActive
                }
                if isShutdown {
                    _ = await pool.release(resource, from: slotIndex, id: id, as: .invalid)
                    throw .left(.shutdown)
                }
                if Task.isCancelled {
                    if let error = await pool.release(
                        resource,
                        from: slotIndex,
                        id: id,
                        as: .reusable
                    ) {
                        throw .left(error)
                    }
                    throw .left(pool.cancellation())
                }

                let disposition: Pool.Bounded<Resource>.Disposition<T>
                do throws(E) {
                    disposition = try await body(&resource)
                } catch {
                    let releaseError = await pool.release(
                        resource,
                        from: slotIndex,
                        id: id,
                        as: .invalid
                    )
                    if let releaseError {
                        throw .left(releaseError)
                    }
                    if Task.isCancelled {
                        throw .left(pool.cancellation())
                    }
                    throw .right(error)
                }

                let cancelled = Task.isCancelled
                let value: T
                let release: Pool.Bounded<Resource>.Release.Disposition
                switch consume disposition {
                case .reusable(let returned):
                    value = returned
                    release = .reusable

                case .invalid(let returned):
                    value = returned
                    release = .invalid
                }

                if let error = await pool.release(
                    resource,
                    from: slotIndex,
                    id: id,
                    as: release
                ) {
                    throw .left(error)
                }
                if cancelled {
                    throw .left(pool.cancellation())
                }
                return value
            }
        }
    }

    extension Pool.Bounded where Resource: ~Copyable {

        @usableFromInline
        func cancellation() -> Pool.Lifecycle.Error {
            _state.withLock { state in state.metrics.cancellations += 1 }
            return .cancelled
        }
    }
#endif
