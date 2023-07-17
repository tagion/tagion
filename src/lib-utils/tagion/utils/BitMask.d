module tagion.utils.BitMask;

enum WORD_SIZE = size_t(size_t.sizeof * 8);

size_t bitsize(const size_t[] mask) pure nothrow @nogc @safe {
    return mask.length * WORD_SIZE;
}

size_t wordindex(const size_t i) pure nothrow @nogc @safe {
    return i / WORD_SIZE;
}

size_t word_bitindex(const size_t i) pure nothrow @nogc @safe {
    return i % WORD_SIZE;
}

@safe
struct BitMask {
    import std.format;
    import std.algorithm;
    import std.range;
    import std.traits;

    enum absolute_mask = 0x1000;
    private size_t[] mask;

    void opAssign(const BitMask rhs) pure nothrow {
        mask = rhs.mask.dup;
    }

    /++
     This set the mask as bit stream with LSB first
     +/
    this(T)(T bitstring) if (isSomeString!T) {
        auto bitrange = bitstring.filter!((c) => (c == '0' || c == '1')).enumerate;
        foreach (i, c; bitrange) {
            if (c == '1') {
                this[i] = true;
            }
        }
    }

    this(R)(R range) pure nothrow if ((isInputRange!R) && !isSomeString!R) {
        range.each!((n) => this[n] = true);
    }

    BitMask dup() const pure nothrow {
        BitMask result;
        result.mask = mask.dup;
        return result;
    }

    void clear() pure nothrow {
        mask[] = 0;
    }

    @nogc
    bool opEquals(const BitMask rhs) const pure nothrow {
        import std.algorithm;

        if (mask == rhs.mask) {
            return true;
        }
        const min_length = min(mask.length, rhs.mask.length);
        if (mask[0 .. min_length] == rhs.mask[0 .. min_length]) {
            return mask.all!(q{a==0}) && rhs.mask.all!(q{a==0});

        }
        return false;
    }

    unittest {
        BitMask bits_a, bits_b;
        assert(bits_a == bits_b);
        bits_b.mask.length = 1;
        assert(bits_a == bits_b);
        bits_a[17] = true;
        assert(bits_a != bits_b);
        bits_b[17] = true;
        assert(bits_a == bits_b);
        bits_b[100] = true;
        assert(bits_a != bits_b);
        bits_a[100] = true;
        assert(bits_a == bits_b);
        BitMask all_null_bits;
        all_null_bits.mask.length = 3; // long sequency of bits of value
        assert(all_null_bits == BitMask.init);
        assert(BitMask.init == all_null_bits);
    }

    Range opSlice() const pure nothrow {
        return Range(mask);
    }

    unittest {
        BitMask bits;
        assert(bits[].empty);
        bits[17] = true;
        assert(equal(bits[], [17]));
        bits[0] = true;
        assert(equal(bits[], [0, 17]));
        enum first_bit_in_the_next_word = 8 * size_t.sizeof;
        enum last_bit_in_a_word = first_bit_in_the_next_word - 1;
        bits[last_bit_in_a_word] = true;
        assert(equal(bits[], [0, 17, last_bit_in_a_word]));
        bits[first_bit_in_the_next_word] = true;
        assert(equal(bits[], [0, 17, last_bit_in_a_word, first_bit_in_the_next_word]));
    }

    @nogc
    struct Range {
        private {
            const(size_t[]) mask;
            size_t index;
            size_t bit_pos;
        }

        private this(
                const(size_t[]) mask,
                size_t index,
                size_t bit_pos) pure nothrow {
            this.mask = mask;
            this.index = index;
            this.bit_pos = bit_pos;
        }

        this(const size_t[] mask) pure nothrow {
            this.mask = mask;
            if (mask.length && (mask[0] & 0x1) is 0) {
                popFront;
            }
        }

        static size_t pos(size_t BIT_SIZE = WORD_SIZE)(const size_t x, const size_t index = 0) pure nothrow {
            static if (BIT_SIZE is 1) {
                return (x) ? index : WORD_SIZE;
            }
            else {
                enum HALF_SIZE = BIT_SIZE >> 1;
                enum MASK = (size_t(1) << HALF_SIZE) - size_t(1);
                if (x & MASK) {
                    return pos!HALF_SIZE(x & MASK, index);
                }
                else {
                    return pos!HALF_SIZE(x >> HALF_SIZE, index + HALF_SIZE);
                }
            }
        }

        static unittest {
            assert(pos(0b1) is 0);
            assert(pos(0b10) is 1);
            assert(pos(0b1000_0000_0000) is 11);
            assert(pos(0) is WORD_SIZE);
            enum small_pos = (WORD_SIZE >> 1) + 5;
            enum larger_pos = small_pos + 7;
            enum small_val = size_t(1) << small_pos;
            enum larger_val = size_t(1) << larger_pos;
            assert(pos(small_val | larger_val) is small_pos);
        }

        pure nothrow {
            const {
                size_t rest() {
                    return (bit_pos < WORD_SIZE - 1) ? (
                            mask[index] & ~((size_t(1) << (bit_pos + 1)) - 1)) : 0;
                }

                bool empty() {
                    return index >= mask.length;
                }

                size_t front() {
                    return index * WORD_SIZE + bit_pos;
                }
            }
            void popFront() {
                if (!empty) {
                    bit_pos = pos(rest);
                    if (bit_pos >= WORD_SIZE) {
                        bit_pos = 0;
                        index++;
                        if (index < mask.length && ((mask[index] & 0x1) is 0)) {
                            popFront;
                        }
                    }
                }
            }

            Range save() {
                return Range(mask, index, bit_pos);
            }
        }
    }

    bool opIndex(size_t i) const pure nothrow @nogc
    in {
        assert(i < absolute_mask);
    }
    do {
        if (i < mask.bitsize) {
            return (mask[i.wordindex] & (size_t(1) << i.word_bitindex)) != 0;
        }
        return false;
    }

    bool opIndexAssign(bool b, size_t i) pure nothrow
    in {
        assert(i < absolute_mask);
    }
    do {
        if (i >= mask.bitsize) {
            mask.length = i.wordindex + 1;
        }
        if (b) {
            mask[i.wordindex] |= size_t(1) << i.word_bitindex;
        }
        else {
            mask[i.wordindex] &= ~(size_t(1) << i.word_bitindex);
        }
        return b;
    }

    unittest {
        BitMask bits;
        assert(!bits[100]);
        bits[100] = true;
        assert(bits[100]);
        bits[100] = false;
        assert(!bits[100]);
    }

    BitMask opUnary(string op)() const pure nothrow
    if (op == "~") {
        BitMask result;
        result.mask = new size_t[mask.length];
        result.mask[] = ~mask[];
        return result;
    }

    @trusted
    unittest {
        BitMask bits;
        assert(~bits == BitMask.init);
        bits.mask.length = 1;
        const all_bits = BitMask('1'.repeat(8 * size_t.sizeof).array);
        assert(~bits == all_bits);
        BitMask expected = all_bits.dup;
        expected[7] = false;
        assert(~bits != expected);
        bits[7] = true;
        assert(~bits == expected);

    }

    BitMask opBinary(string op)(scope const BitMask rhs) const pure nothrow
    if (op == "-" || op == "&" || op == "|" || op == "^") {
        import std.algorithm.comparison : max, min;

        BitMask result;
        result.mask = mask.dup;
        result.opOpAssign!op(rhs);
        return result;
    }

    version (unittest) {
        import std.stdio;
        import std.array;
        import tagion.basic.Debug;

        /// Result table
        /// 
    }

    unittest { // opBinary and opOpAssign

        BitMask bits_a, bits_b;
        enum op_list = ["|", "&", "^", "-"];
        //enum righ
        static struct Expected {
            BitMask Y, A, B; /// y = a OP b
        }

        const left_one_right_none = [
            "|": Expected(BitMask("010101"), BitMask("010101"), BitMask.init),
            "&": Expected(BitMask("000000"), BitMask("010101"), BitMask.init),
            "^": Expected(BitMask("010101"), BitMask("010101"), BitMask.init),
            "-": Expected(BitMask("010101"), BitMask("010101"), BitMask.init),
        ];
        const left_one_right_one = [
            "|": Expected(BitMask("010111001"), BitMask("010101001"), BitMask("0101110")),
            "&": Expected(BitMask("010001"), BitMask("010101"), BitMask("0100010")),
            "^": Expected(BitMask("00110001"), BitMask("000101"), BitMask("00100101")),
            "-": Expected(BitMask("0000101"), BitMask("000010111"), BitMask("01010101111")),
        ];

        const left_more_right_more = [
            "|": Expected(BitMask([1, 57, 100]), BitMask([57]), BitMask([100, 1])),
            "&": Expected(BitMask([57, 101]), BitMask([1, 57, 101, 65]), BitMask([101, 57, 22])),
            "^": Expected(BitMask([1, 2, 57, 100]), BitMask([2, 57, 100, 65]), BitMask([1, 65])),
            "-": Expected(BitMask([2, 100]), BitMask([2, 57, 100, 65]), BitMask([67, 57, 65])),
        ];

        static foreach (OP; op_list) {
            assert(bits_a.opBinary!OP(bits_b) == BitMask.init);
            {
                foreach (test; only(left_one_right_none, left_one_right_one, left_more_right_more)) {
                    const expected = test[OP];
                    with (expected) {
                        const result = A.opBinary!OP(B);
                        assert(result == Y,
                                __format("%.16s == %.16s %s %.16s result %.16s", Y, A, OP, B, result));
                    }
                    with (expected) {
                        auto result = A.dup;
                        result.opOpAssign!OP(B);

                        assert(result == Y,
                                __format("%.16s == (%.16s %s= %.16s) result %.16s", Y, A, OP, B, result));

                    }

                }
            }
        }
    }

    BitMask opOpAssign(string op)(scope const BitMask rhs) pure nothrow
    if (op == "-" || op == "&" || op == "|" || op == "^") {
        if (mask.length > rhs.mask.length) {
            switch (op) {
            case "&":
                mask[rhs.mask.length .. $] = 0;
                break;
            default:
            }
        }
        else if (mask.length < rhs.mask.length) {
            mask.length = rhs.mask.length;
        }

        static if (op == "-") {
            mask[0 .. rhs.mask.length] &= ~rhs.mask[0 .. rhs.mask.length];
        }
        else {
            enum code = format(q{mask[0..rhs.mask.length] %s= rhs.mask[0..rhs.mask.length];}, op);
            mixin(code);
        }
        return this;
    }

    BitMask opBinary(string op, Index)(const Index index) const pure nothrow
    if ((op == "-" || op == "+") && isIntegral!Index) {
        BitMask result = dup;
        result[index] = (op == "+");
        return result;
    }

    unittest {
        BitMask bits;
        assert(bits + 17 == BitMask([17]));
        bits = BitMask([42, 17]);
        assert(bits + 100 == BitMask([17, 100, 42]));
        assert(bits - 17 == BitMask([42]));
    }

    void chunk(size_t bit_len) pure nothrow {
        const new_size = bit_len.wordindex + 1;
        if (new_size < mask.length) {
            mask.length = new_size;
        }
        const chunk_mask = ((size_t(1) << (bit_len.word_bitindex)) - 1);
        mask[$ - 1] &= chunk_mask;
    }

    unittest {
        BitMask bits = BitMask([17, 42, 99, 101]);
        bits.chunk(100);
        assert(equal(bits[], [17, 42, 99]));
        bits.chunk(99);
        assert(equal(bits[], [17, 42]));
    }

    size_t count() const pure nothrow @nogc {
        import core.bitop : popcnt;

        return mask.map!(m => m.popcnt).sum;
    }

    unittest {
        BitMask bits;
        assert(bits.count == 0);
        bits[17] = true;
        assert(bits.count == 1);
        bits = ~bits;
        assert(bits.count == WORD_SIZE - 1);
        bits[WORD_SIZE * 3 / 2] = true;
        assert(bits.count == WORD_SIZE);
        bits[WORD_SIZE / 2] = false;
        bits = ~bits;
        assert(bits.count == WORD_SIZE + 1);
    }

    void toString(scope void delegate(scope const(char)[]) @safe sink,
            const FormatSpec!char fmt) const {
        enum separator = '_';
        import std.stdio;

        @nogc @safe struct BitRange {
            size_t index;
            const size_t width;
            const(size_t[]) mask;
            this(const BitMask bitmask, const size_t width) {
                mask = bitmask.mask;
                this.width = (width is 0) ? mask.bitsize : width;
            }

            pure nothrow {
                char front() const {
                    const word_index = index.wordindex;
                    if (word_index < mask.length) {
                        return (mask[word_index] & (size_t(1) << (index.word_bitindex))) ? '1' : '0';
                    }
                    return '0';
                }

                bool empty() const {
                    return index >= width;
                }

                void popFront() {
                    index++;
                }
            }
        }

        switch (fmt.spec) {
        case 's':
            auto bit_range = BitRange(this, fmt.width);
            scope char[] str;
            auto max_size = bit_range.width + (bit_range.width) / fmt.precision + 1;
            str.length = max_size;
            size_t index;
            size_t sep_count;
            while (!bit_range.empty) {
                str[index++] = bit_range.front;
                bit_range.popFront;
                if (fmt.precision !is 0 && !bit_range.empty) {
                    sep_count++;
                    if ((sep_count % fmt.precision) is 0) {
                        str[index++] = separator;
                    }
                }
            }
            sink(str[0 .. index]);
            break;
        default:
            assert(0, "Unknown format specifier: %" ~ fmt.spec);
        }
    }

    @trusted
    unittest {
        {
            auto bits = BitMask("0101_1");
            assert(format("%16.8s", bits) == "01011000_00000000");
            assert(format("%16.4s", bits) == "0101_1000_0000_0000");
            assert(format("%7.3s", bits) == "010_110_0");
        }

        {
            BitMask bits;
            bits[64] = true;
            assert(format("%.16s", bits) ==
                    "0000000000000000_0000000000000000_0000000000000000_0000000000000000_1000000000000000_0000000000000000_0000000000000000_0000000000000000");
            bits[17] = true;
            bits[78] = true;
            bits[64] = false;
            assert(format("%.16s", bits) ==
                    "0000000000000000_0100000000000000_0000000000000000_0000000000000000_0000000000000010_0000000000000000_0000000000000000_0000000000000000");
        }

        {
            const a = BitMask("1000_1100_1100");
            const b = BitMask("0010_1001_0101");
            { // bit or
                const y = a | b;
                assert(format("%16.4s", y) == "1010_1101_1101_0000");
                assert(y.count is 8);
            }

            { // bit and
                const y = a & b;
                assert(format("%16.4s", y) == "0000_1000_0100_0000");
                assert(y.count is 2);
            }

            { // bit xor
                const y = a ^ b;
                assert(format("%16.4s", y) == "1010_0101_1001_0000");
                assert(y.count is 6);
            }

            { // bit and not
                const y = a - b;
                assert(format("%16.4s", y) == "1000_0100_1000_0000");
                assert(y.count is 3);
            }

            version (BITMASK) {
                BitMask null_mask;
                const y = a - null_mask;
                assert(y == a);
            }

            {
                auto y = a.dup;
                y |= b;
                assert(format("%16.4s", y) == "1010_1101_1101_0000");
                assert(y.count is 8);

            }

            { // bit and
                auto y = a.dup;
                y &= b;
                assert(format("%16.4s", y) == "0000_1000_0100_0000");
                assert(y.count is 2);

            }

            { // bit xor
                auto y = a.dup;
                y ^= b;
                assert(format("%16.4s", y) == "1010_0101_1001_0000");
                assert(y.count is 6);
            }

            { // bit and not
                auto y = a.dup;
                y -= b;
                assert(format("%16.4s", y) == "1000_0100_1000_0000");
                assert(y.count is 3);
            }

            { // Not and chunk
                auto y = ~a;
                assert(format("%32.4s", y) == "0111_0011_0011_1111_1111_1111_1111_1111");
                y.chunk(16);
                assert(format("%32.4s", y) == "0111_0011_0011_1111_0000_0000_0000_0000");
                assert(y.count is 11);
            }
        }

    }

    unittest {
        import std.algorithm : equal;
        import std.algorithm.sorting : merge, sort;
        import std.algorithm.iteration : uniq, fold;
        import std.stdio;

        { // Bit assign
            BitMask a;
            assert(!a[42]);
            assert(!a[17]);
            assert(!a[0]);
            a[42] = true;
            assert(a[42]);
            assert(!a[17]);
            assert(!a[0]);
            a[0] = true;
            assert(a[42]);
            assert(!a[17]);
            assert(a[0]);
            a[17] = true;
            assert(a[42]);
            assert(a[17]);
            assert(a[0]);

        }

        { // Range
            const bit_list = [17, 52, 53, 54, 75, 28, 101];
            { // Empty Range
                BitMask a;
                assert(a[].empty);
                size_t[] a_empty;
                assert(equal(a[], a_empty));
            }

            { // First element
                BitMask a;
                a[0] = true;
                auto range = a[];
                assert(range.front is 0);
                assert(!range.empty);
                range.popFront;
                assert(range.empty);
                assert(equal(a[], [0]));
            }

            { // One element
                BitMask a;
                a[2] = true;
                assert(equal(a[], [2]));
            }

            { // One element at the end of a word
                BitMask a;
                a[63] = true;
                assert(equal(a[], [63]));
            }

            { // One element at the begin of the next word
                BitMask a;
                a[64] = true;
                assert(equal(a[], [64]));
            }

            { //  elements at the end and begin of a word
                BitMask a;
                a[63] = true;
                a[64] = true;
                assert(equal(a[], [63, 64]));
            }

            { // Simple range test
                auto a = BitMask(bit_list);
                assert(equal(a[], bit_list.dup.sort));
            }
        }

        void and_filter(ref BitMask result, Range a, Range b) @safe {
            if (a.front < b.front) {
                a.popFront;
            }
            else if (a.front > b.front) {
                b.popFront;
            }
            else {
                if (a.empty) {
                    return;
                }
                result[b.front] = true;
                a.popFront;
                b.popFront;
            }
            and_filter(result, a, b);
        }

        void xor_filter(ref BitMask result, Range a, Range b) @safe {
            if (a.front < b.front) {
                result[a.front] = true;
                a.popFront;
            }
            else if (a.front > b.front) {
                result[b.front] = true;
                b.popFront;
            }
            else {
                if (a.empty) {
                    return;
                }
                //result[b.front]=true;
                a.popFront;
                b.popFront;
            }
            and_filter(result, a, b);
        }

        { // Check BitMask with mask.length > 1
            const a_list = [17, 52, 53, 54, 75, 28, 101];
            const a = BitMask(a_list);
            const b_list = [17, 52, 54, 76, 28, 101, 102, 103];
            const b = BitMask(b_list);

            { // Or
                const y = a | b;
                auto y_list = (a_list ~ b_list).dup.sort.uniq; //uniq;//.dup.sort;
                assert(equal(y[], y_list));
                assert(y.count is 10);
            }

            { // And
                const y = a & b;
                BitMask result;
                and_filter(result, a[], b[]);
                assert(result == y);
                assert(y.count is 5);
            }

            { // Xor
                const y = a ^ b;
                const result = ~a & b | a & ~b;
                assert(result == y);
                assert(y.count is 5);
            }

            { // and not
                const y = a - b;
                const result = a & ~b;
                assert(result == y);
                assert(y.count is 2);
            }

            { // Empty Or=
                BitMask y;
                y |= a;
                assert(y == a);
                assert(a.count is y.count);
            }

            { // Or
                auto y = a.dup;
                y |= b;
                auto y_list = (a_list ~ b_list).dup.sort.uniq;
                assert(equal(y[], y_list));
                assert(y.count is 10);
            }

            { // And
                auto y = a.dup;
                y &= b;
                BitMask result;
                and_filter(result, a[], b[]);
                assert(result == y);
                assert(y.count is 5);
            }

            { // Xor
                auto y = a.dup;
                y ^= b;
                //const y= a ^ b;
                const result = ~a & b | a & ~b;
                assert(result == y);
                assert(y.count is 5);
            }

            { // and not
                auto y = a.dup;
                y -= b;

                //const y= a - b;
                const result = a & ~b;
                assert(result == y);
                assert(y.count is 2);
            }
        }

        { // Duplicate on assign
            BitMask z;
            auto y = z;
            z[3] = true;
            assert(equal(z[], [3]));
            assert(y[].empty);
            y = z;
            z[5] = true;
            assert(equal(z[], [3, 5]));
            assert(equal(y[], [3]));
        }

    }
}
