/// Pseudo random range
module tagion.utils.Random;

@safe @nogc
struct Random(T = uint) {
    private T m_z;
    private T m_w;
    this(const T seed_value) pure nothrow {
        seed(seed_value);
    }

    private this(T m_z, T m_w) pure nothrow {
        this.m_z = m_z;
        this.m_w = m_w;
    }

    void seed(const T seed_value) pure nothrow {
        m_z = 13 * seed_value;
        m_w = 7 * seed_value;
    }

    T value() {
        popFront;
        return front;
    }

    T value(const(T) range) {
        return value % range;
    }

    T value(const(T) from, const(T) to)
    in {
        assert(to > from);
    }
    do {
        immutable range = to - from;
        return (value % range) + from;
    }

    void popFront() pure nothrow {
        m_z = 36_969 * (m_z & T.max) + (m_z >> 16);
        m_w = 18_000 * (m_w & T.max) + (m_w >> 16);
    }

    T front() const pure nothrow {
        return (m_z << 16) + m_w;
    }

    enum bool empty = false;

    Random save() pure nothrow {
        return Random(m_z, m_w);
    }

    import std.range.primitives : isInputRange, isForwardRange, isInfinite;

    static assert(isInputRange!(Random));
    static assert(isForwardRange!(Random));
    static assert(isInfinite!(Random));

}

@safe
unittest {
    import std.range : take;
    import std.algorithm.comparison : equal;

    auto r = Random!uint(1234);
    auto r_forward = r.save;
    assert(equal(r.take(5), r_forward.take(5)));

    r.take(7);
    r_forward = r.save;
    assert(equal(r.take(4), r_forward.take(4)));
}
