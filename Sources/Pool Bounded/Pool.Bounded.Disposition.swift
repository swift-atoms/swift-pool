#if Concurrency
    extension Pool.Bounded where Resource: ~Copyable {

        public enum Disposition<Value: ~Copyable>: ~Copyable {

            case reusable(Value)

            case invalid(Value)
        }
    }
#endif
