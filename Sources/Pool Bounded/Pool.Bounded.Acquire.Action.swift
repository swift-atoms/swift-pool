#if Concurrency

    extension Pool.Bounded.Acquire where Resource: ~Copyable {

        @usableFromInline
        enum Action {

            case immediate(Pool.Bounded<Resource>.Slot.Index, Pool.ID)

            #if Concurrency

                case create(Pool.Bounded<Resource>.Slot.Index, Pool.ID)
            #endif

            case suspend

            case shutdown
        }
    }
#endif
