# swift-pool

Use this package when tasks need exclusive, temporary use of a limited number of costly resources, such as connections or handles, including `~Copyable` and non-`Sendable` ones. Start from `Pool.Bounded<Resource>`: build it without `create` to fill it yourself through `Pool.Bounded<Resource>.Fill`, or with `create` to have it create resources on demand. `Pool.Acquire<Resource>` and `Pool.Release<Resource>` only describe pool access as effects for an effect handler; this package does not handle them. For reusable fixed-size memory blocks, use the `Memory Pool` library of swift-memory-allocation instead.

## Laws

- Capacity counts every resource the pool owns: idle, lent out, being created and being destroyed.
- A pool built without `create` never creates or replaces a resource. Every destroyed resource leaves a slot that only `fill` can occupy again, and `acquire` waits until one is available.
- A pool built with `create` creates a resource inside `acquire`, on the acquiring task, when no idle resource exists and a slot is free. When a resource is destroyed while acquisitions are waiting, the task that caused the destruction creates the replacement and hands it to the waiter before its own `acquire` returns.
- When `create` throws, every acquisition then waiting fails with that error, and so does the acquisition that called `create`, unless it was creating a replacement after a destruction: that `acquire` still returns normally. The slot becomes free, so a later `acquire` tries `create` again.
- `check` runs on every resource before it enters the pool (`fill`, lazy creation), before it is lent to a body, and when a body returns it as `.reusable`. A resource that fails `check` is destroyed. Failing before the body, `acquire` destroys it and tries again with another resource; failing right after lazy creation, `acquire` fails with `.creationFailed`.
- A released resource goes directly to the longest-waiting acquisition that is not cancelled. With no waiter it becomes idle; the most recently returned idle resource is lent next.
- `.invalid` from the body destroys the resource and still returns the body's value. `acquire` returns only after the destruction has finished.
- A body that throws loses its resource: it is destroyed, and the error surfaces as the body's own error unless shutdown or cancellation has priority.
- Cancellation is terminal. It is checked before acquiring, while waiting, after the resource is obtained and after the body returns. Once a resource is obtained, cancellation destroys it, even when the body returned `.reusable`, and the body's value is lost.
- Failure priority, from `Pool.Lifecycle.Precedence`: shutdown, then cancellation, then the outcome itself.
- Every resource that `fill` does not install is destroyed before `fill` throws. A ready waiter receives a filled resource directly. `fill.batch` stops without an error at the first full pool and returns how many it installed; the resource that found the pool full is destroyed.
- `shutdown()` destroys every idle resource and fails every waiting acquisition with `.shutdown`. Lent resources are destroyed when their body finishes, and that `acquire` fails with `.shutdown` even when the body succeeded. Resources created or filled during shutdown are destroyed. `shutdown()` returns only after every resource is destroyed; repeated and concurrent calls all return at that same point.
- A pool that still owns a resource traps on deinitialization unless `shutdown()` has completed.
- Each `Pool.Bounded<Resource>` has its own `Pool.Scope`. Every resource it creates or receives through `fill` gets a fresh `Pool.ID` in that scope, and the ID stays with the resource while it is reused.
- `Pool.Metrics` is a snapshot. `acquisitions` counts each time a resource is lent, including one that then fails `check`; `releases` counts each return, so the two are equal whenever nothing is lent out. `created` counts lazy creations, `fills` counts installed fills, `closed` counts destructions of resources that held a slot, and `outstanding.peak` is the high-water mark of `outstanding.current`.
