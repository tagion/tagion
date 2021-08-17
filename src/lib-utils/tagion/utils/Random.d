module tagion.utils.Random;

@safe
struct Random(T = uint) {
    private T m_z;
    private T m_w;
    this(const T seed_value) {
        seed(seed_value);
    }

    void seed(const T seed_value) {
        m_z = 13 * seed_value;
        m_w = 7 * seed_value;
    }

    T value() {
        m_z = 36969 * (m_z & T.max) + (m_z >> 16);
        m_w = 18000 * (m_w & T.max) + (m_w >> 16);
        return (m_z << 16) + m_w;
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

}
