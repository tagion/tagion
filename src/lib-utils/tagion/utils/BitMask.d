module tagion.util.BitMask;

//import std.stdio;

enum WORD_SIZE=size_t(size_t.sizeof*8);

size_t bitsize(const size_t[] mask) pure nothrow @nogc @safe {
    return mask.length*WORD_SIZE;
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
    import std.algorithm : filter, each, max;
    import std.range : enumerate;
    import std.range.primitives : isInputRange;
    import std.traits : isSomeString;
    enum absolute_mask=0x1000;
    private size_t[] mask;

    // this(const BitMask bits) pure nothrow {
    //     mask=bits.mask;
    // }

    void opAssign(const BitMask rhs) pure nothrow {
        mask=rhs.mask.dup;
    }

    // void opAssign(const BitMask rhs) pure nothrow {
    //     mask=rhs.mask.dup;
    // }
    /++
     This set the mask as bit stream with LSB first
     +/
    this(T)(T bitstring) if(isSomeString!T) {
        //mask.length=wordindex(bitsting)+1;
        auto bitrange=bitstring.filter!((c) => (c == '0' || c == '1')).enumerate;
        foreach(i, c; bitrange) {
            if (c == '1') {
                this[i]=true;
            }
        }
    }

    this(R)(R range) pure nothrow if ((isInputRange!R) && !isSomeString!R) {
        range.each!((n) => this[n]=true);
    }

    BitMask dup() const pure nothrow {
        BitMask result;
        result.mask=mask.dup;
        return result;
    }

    void clear() pure nothrow {
        mask=null;
    }

    version(none)
    @nogc
    bool opEquals(const BitMask rhs) const pure nothrow {
        return mask == rhs.mask;
    }

    @trusted
    void toString(scope void delegate(scope const(char)[]) @trusted sink,
        const FormatSpec!char fmt) const {
        enum separator='_';
        import std.stdio;
        @nogc @safe struct BitRange {
            size_t index;
            const size_t width;
            const(size_t[]) mask;
            this(const BitMask bitmask, const size_t width) {
                mask=bitmask.mask;
                this.width=(width is 0)?mask.bitsize:width;
            }
            pure nothrow {
                char front() const {
                    const word_index=index.wordindex;
                    if (word_index < mask.length) {
                        return (mask[word_index] & (size_t(1) << (index.word_bitindex)))?'1':'0';
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
        // case 'j':
        //     // Normal stringefied JSON
        //     sink(doc.toJSON.toString);
        //     break;
        // case 'J':
        //     // Normal stringefied JSON
        //     sink(doc.toJSON.toPrettyString);
        //     break;

        case 's':
            auto bit_range=BitRange(this, fmt.width);
            scope char[] str;
            //auto max_size=mask.length*(8*size_t.sizeof+((fmt.precision is )?0:(size_t.sizeof/fmt.precision+1)));
            auto max_size=bit_range.width+(bit_range.width)/fmt.precision + 1;
            str.length=max_size;
            size_t index;
            size_t sep_count;
            while(!bit_range.empty) {
                str[index++]=bit_range.front;
                bit_range.popFront;
                if (fmt.precision !is 0 && !bit_range.empty) {
                    sep_count++;
                    if ((sep_count % fmt.precision) is 0 ) {
                        str[index++]=separator;
                    }
                }
            }
            sink(str[0..index]);
            break;
        default:
            assert(0, "Unknown format specifier: %" ~ fmt.spec);
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
            mask.length=i.wordindex+1;
        }
        if (b) {
            mask[i.wordindex]|=size_t(1) << i.word_bitindex;
        }
        else {
            mask[i.wordindex]&= ~(size_t(1) << i.word_bitindex);
        }
        return b;
    }

    BitMask opOpAssign(string op)(scope const BitMask rhs) pure nothrow
        if (op == "-" || op == "&" || op == "|" || op == "^")
        {
            if (mask.length > rhs.mask.length) {
                static if (op == "&") {
                    mask[rhs.mask.length..$]=0;
                }
            }
            else if (mask.length < rhs.mask.length) {
                mask.length = rhs.mask.length;
            }
//            foreach(i, ref m; mask[0..rhs.mask.length]) {
            static if (op == "-") {
                mask[0..rhs.mask.length] &= ~rhs.mask[0..rhs.mask.length];
            }
            else {
                enum code=format(q{mask[0..rhs.mask.length] %s= rhs.mask[0..rhs.mask.length];}, op);
                mixin(code);
            }
            return this;
        }

    BitMask opBinary(string op)(scope const BitMask rhs) const pure nothrow
        if (op == "-" || op == "&" || op == "|" || op == "^")
        {
            import std.algorithm.comparison : max, min;

            BitMask result;
            const max_length=max(mask.length, rhs.mask.length);
            result.mask.length=max_length;
            const min_length=min(mask.length, rhs.mask.length);
            static if (op == "-") {
                result.mask[0..min_length] = mask[0..min_length] &~ rhs.mask[0..min_length];
            }
            else {
                {
                    enum code=format(q{result.mask[0..min_length] = mask[0..min_length] %s rhs.mask[0..min_length];}, op);
                    mixin(code);
                }
            }
            if (mask.length !is rhs.mask.length) {
                auto rest=(mask.length > rhs.mask.length)?mask:rhs.mask;
                static if (op == "|" || op == "^") {
                    enum code=format(q{result.mask[min_length..$] %s= rest[min_length..$];}, op);
                    pragma(msg, code);
                    mixin(code);
                }
            }
            return result;
        }

    BitMask opBinary(string op)(const size_t index) const pure nothrow
        if ((op == "-" || op == "+")) {
            BitMask result=dup;
            result[index]=(op == "+");
            return result;
        }

    BitMask opUnary(string op)() const pure nothrow
        if (op == "~")
        {
            BitMask result;
            result.mask.length = mask.length;
            result.mask[]=~mask[];
            return result;
        }

    void chunk(size_t bit_len) nothrow {
        const new_size=bit_len.wordindex+1;
        if (new_size < mask.length) {
            mask.length = new_size;
        }
        mask[$-1] &= (1 << bit_len.word_bitindex) - 1;
    }

    size_t count() const pure nothrow @nogc {
        static size_t local_count(size_t BIT_SIZE)(const size_t x) pure nothrow {
            static if (BIT_SIZE is 1) {
                return x & 1;
            }
            else {
                if (x is 0) {
                    return 0;
                }
                enum HALF_SIZE=BIT_SIZE >> 1;
                enum MASK = (size_t(1) << HALF_SIZE) - 1;
                return local_count!HALF_SIZE(x & MASK) + local_count!HALF_SIZE((x >> HALF_SIZE) &  MASK);
            }
        }
        size_t result;
        foreach(m; mask) {
            result += local_count!(WORD_SIZE)(m);
        }
        return result;
    }

    Range opSlice() const pure nothrow {
        return Range(mask);
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
            this.mask=mask;
            this.index=index;
            this.bit_pos=bit_pos;
        }

        this(const size_t[] mask) pure nothrow {
            this.mask = mask;
            if (mask.length && (mask[0] & 0x1) is 0) {
                popFront;
            }
        }

        static size_t pos(size_t BIT_SIZE=WORD_SIZE)(const size_t x, const size_t index=0) pure nothrow {
            static if (BIT_SIZE is 1) {
                return (x)?index:WORD_SIZE;
            }
            else {
                enum HALF_SIZE = BIT_SIZE >> 1;
                enum MASK = (size_t(1) << HALF_SIZE) - size_t(1);
                if (x & MASK) {
                    return pos!HALF_SIZE(x & MASK, index);
                }
                else {
                    return pos!HALF_SIZE(x >> HALF_SIZE, index+HALF_SIZE);
                }
            }
        }

        static unittest {
            assert(pos(0b1) is 0);
            assert(pos(0b10) is 1);
            assert(pos(0b1000_0000_0000) is 11);
            assert(pos(0) is WORD_SIZE);
            enum small_pos=(WORD_SIZE >> 1)+5;
            enum larger_pos=small_pos+7;
            enum small_val=size_t(1) << small_pos;
            enum larger_val=size_t(1) << larger_pos;
            assert(pos(small_val | larger_val) is  small_pos);
        }

        pure nothrow {
            const {
                size_t rest() {
                    return (bit_pos<WORD_SIZE-1)?(mask[index] &~ ((size_t(1) << (bit_pos+1))-1)):0;
                }

                bool empty() {
                    return index >= mask.length;
                }

                size_t front() {
                    return index*WORD_SIZE+bit_pos;
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
        //}
    }

    @trusted
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
            a[42]=true;
            assert(a[42]);
            assert(!a[17]);
            assert(!a[0]);
            a[0]=true;
            assert(a[42]);
            assert(!a[17]);
            assert(a[0]);
            a[17]=true;
            assert(a[42]);
            assert(a[17]);
            assert(a[0]);

        }

        { // Range
            const bit_list=[17, 52, 53, 54, 75, 28, 101];
            { // Empty Range
                BitMask a;
                assert(a[].empty);
                size_t[] a_empty;
                assert(equal(a[], a_empty));
            }

            { // First element
                BitMask a;
                a[0]=true;
                auto range=a[];
                assert(range.front is 0);
                assert(!range.empty);
                range.popFront;
                assert(range.empty);
                assert(equal(a[], [0]));
            }

            { // One element
                BitMask a;
                a[2]=true;
                assert(equal(a[], [2]));
            }

            { // One element at the end of a word
                BitMask a;
                a[63]=true;
                assert(equal(a[], [63]));
            }

            { // One element at the begin of the next word
                BitMask a;
                a[64]=true;
                assert(equal(a[], [64]));
            }

            { //  elements at the end and begin of a word
                BitMask a;
                a[63]=true;
                a[64]=true;
                writefln("a[]=%s", a[]);
                assert(equal(a[], [63, 64]));
            }

            { // Simple range test
                auto a=BitMask(bit_list);
                writefln("a[]=%s", a[]);
                assert(equal(a[], bit_list.dup.sort));
            }
        }

        {
            auto bits=BitMask("0101_1");
            assert(format("%16.8s", bits) == "01011000_00000000");
            assert(format("%16.4s", bits) == "0101_1000_0000_0000");
            assert(format("%7.3s", bits) == "010_110_0");
        }

        {
            BitMask bits;
            bits[64]=true;
            assert(format("%.16s", bits) ==
                "0000000000000000_0000000000000000_0000000000000000_0000000000000000_1000000000000000_0000000000000000_0000000000000000_0000000000000000");
            bits[17]=true;
            bits[78]=true;
            bits[64]=false;
            assert(format("%.16s", bits) ==
                "0000000000000000_0100000000000000_0000000000000000_0000000000000000_0000000000000010_0000000000000000_0000000000000000_0000000000000000");
        }

        {
            const a=BitMask("1000_1100_1100");
            const b=BitMask("0010_1001_0101");
            { // bit or
                const y=a | b;
                assert(format("%16.4s", y) == "1010_1101_1101_0000");
                assert(y.count is 8);
            }

            { // bit and
                const y=a & b;
                assert(format("%16.4s", y) == "0000_1000_0100_0000");
                assert(y.count is 2);
            }

            { // bit xor
                const y=a ^ b;
                assert(format("%16.4s", y) == "1010_0101_1001_0000");
                assert(y.count is 6);
            }

            { // bit and not
                const y=a - b;
                assert(format("%16.4s", y) == "1000_0100_1000_0000");
                assert(y.count is 3);
            }

            {
                auto y=a.dup;
                y |=b;
                assert(format("%16.4s", y) == "1010_1101_1101_0000");
                assert(y.count is 8);

            }

            { // bit and
                auto y=a.dup;
                y &= b;
                assert(format("%16.4s", y) == "0000_1000_0100_0000");
                assert(y.count is 2);

            }

            { // bit xor
                auto y=a.dup;
                y ^= b;
                assert(format("%16.4s", y) == "1010_0101_1001_0000");
                assert(y.count is 6);
            }

            { // bit and not
                auto y=a.dup;
                y -= b;
                assert(format("%16.4s", y) == "1000_0100_1000_0000");
                assert(y.count is 3);
            }

            { // Not and chunk
                auto y=~a;
                assert(format("%32.4s", y) == "0111_0011_0011_1111_1111_1111_1111_1111");
                y.chunk(16);
                assert(format("%32.4s", y) == "0111_0011_0011_1111_0000_0000_0000_0000");
                assert(y.count is 11);
            }
        }

        void and_filter(ref BitMask result, Range a, Range b) {
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
                result[b.front]=true;
                a.popFront;
                b.popFront;
            }
            and_filter(result, a, b);
        }

        void xor_filter(ref BitMask result, Range a, Range b) {
            if (a.front < b.front) {
                result[a.front]=true;
                a.popFront;
            }
            else if (a.front > b.front) {
                result[b.front]=true;
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
            const a_list=[17, 52, 53, 54, 75, 28, 101];
            const a=BitMask(a_list);
            const b_list=[17, 52, 54, 76, 28, 101, 102, 103];
            const b=BitMask(b_list);

            { // Or
                const y= a | b;
                auto y_list=(a_list~b_list).dup.sort.uniq; //uniq;//.dup.sort;
                assert(equal(y[], y_list));
                assert(y.count is 10);
            }

            { // And
                const y= a & b;
                BitMask result;
                and_filter(result, a[], b[]);
                assert(result == y);
                assert(y.count is 5);
            }

            { // Xor
                const y= a ^ b;
                const result=~a & b | a & ~b;
                assert(result == y);
                assert(y.count is 5);
            }

            { // and not
                const y= a - b;
                const result= a & ~b;
                assert(result == y);
                assert(y.count is 2);
            }

            { // Empty Or=
                BitMask y;
                y |= a;
                writefln("%.16s", y);
                assert(y == a);
                assert(a.count is y.count);
            }

            { // Or
                auto y = a.dup;
                y |= b;
                auto y_list=(a_list~b_list).dup.sort.uniq; //uniq;//.dup.sort;
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
                const result=~a & b | a & ~b;
                assert(result == y);
                assert(y.count is 5);
            }

            { // and not
                auto y = a.dup;
                y -= b;

                //const y= a - b;
                const result= a & ~b;
                assert(result == y);
                assert(y.count is 2);
            }
        }

        { // Duplicate on assign
            BitMask z;
            auto y=z;
            z[3]=true;
            assert(equal(z[], [3]));
            assert(y[].empty);
            y=z;
            z[5]=true;
            assert(equal(z[], [3, 5]));
            assert(equal(y[], [3]));
        }


    }
}
