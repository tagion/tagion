/// \file Text.d

module tagion.betterC.utils.Text;

@nogc:

import std.traits : Unqual, isIntegral, isSigned;
import tagion.betterC.utils.Memory;
import tagion.betterC.utils.platform : calloc;

//import core.stdc.stdio;

struct Text {
@nogc:
    protected {
        char[] str;
        size_t index;
    }

    this(const size_t size) {
        if (size > 0) {
            str.create(size);
        }
    }

    this(const(char[]) _str) {
        this(_str.length + 1);
        str[0 .. _str.length] = _str[0 .. $];
        index = _str.length;
        str[$ - 1] = '\0';
    }
    /**
       This takes over the overship of the data
     */
    this(ref Text _surrender) {
        this.str = _surrender.str;
        this.index = _surrender.index;
        _surrender.str = null;
        _surrender.index = 0;
    }

    char[] expropriate() {
        scope (exit) {
            str = null;
            index = 0;
        }
        return str[0 .. index];
    }

    @property size_t length() const pure {
        return index;
    }

    char opIndex(const size_t i) pure const {
        if (i < index) {
            return str[i];
        }
        return '\0';
    }

    string opSlice(const size_t from, const size_t to) const
    in {
        assert(from <= to);
        assert(to <= index);
    }
    do {
        return cast(string)(str[from .. to]);
    }

    string opSlice() const pure {
        return cast(immutable) str[0 .. index];
    }

    alias serialize = opSlice;
    void opOpAssign(string op)(const(char[]) cat) if (op == "~") {
        const new_index = index + cat.length;
        scope (exit) {
            index = new_index;
        }
        if (index + cat.length + 1 > str.length) {
            resize(str, index + cat.length + 1);
        }
        str[index .. new_index] = cat;
        str[new_index] = '\0';
    }

    ref Text opCall(const(char[]) cat) return {
        opOpAssign!"~"(cat);
        return this;
    }

    ref Text opCall(T)(T num, const size_t base = 10) if (isIntegral!T) {
        //const negative=(num < 0);
        enum numbers = "0123456789abcdef";
        static if (isSigned!T) {
            enum max_size = T.min.stringof.length + 1;
        }
        else {
            enum max_size = T.max.stringof.length + 1;
        }

        if (index + max_size > str.length) {
            resize(str, index + max_size);
        }
        static if (isSigned!T) {
            if (num < 0) {
                str[index] = '-';
                num = -num;
                index++;
            }
        }
        const(char[]) fill_numbers(T num, char[] s) {
            alias Mutable = Unqual!T;
            Mutable n = num;
            uint i;
            do {
                const n_index = cast(uint)(n % cast(T) base);
                s[i++] = numbers[n_index];
                n /= base;
            }
            while (n > 0);
            return s[0 .. i];
        }

        char[max_size] buf;
        const reverse_numbers = fill_numbers(num, buf);
        foreach_reverse (i, c; reverse_numbers) {
            str[index] = c;
            index++;
        }
        str[index] = '\0';
        return this;
    }

    void dispose() {
        str.dispose;
        index = 0;
    }

    ~this() {
        str.dispose;
    }
}

unittest {
    //    import core.stdc.stdio;
    Text text;
    immutable(char[12]) check = "Some text 42";
    size_t size = 4;
    text ~= check[0 .. size];
    assert(text.serialize == check[0 .. size]);
    text ~= check[size .. size + 6];
    size += 6;
    assert(text.serialize == check[0 .. size]);
    text(42);
    assert(text.serialize == check);
}
