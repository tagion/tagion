module tagion.utils.Random;

@safe
struct Random {
    private uint m_z;
    private uint m_w;
    this(const uint seed_value) {
        seed(seed_value);
    }
    void seed(const uint seed_value) {
        m_z=13*seed_value;
        m_w=7*seed_value;
    }

    uint value() {
        m_z = 36969 * (m_z & 65535) + (m_z >> 16);
        m_w = 18000 * (m_w & 65535) + (m_w >> 16);
        return (m_z << 16) + m_w;
    }

    uint value(const(uint) range) {
        return value % range;
    }

    uint value(const(uint) from, const(uint) to)
        in {
            assert(to>from);
        }
    do {
        immutable range=to-from;
        return (value % range)+from;
    }

}