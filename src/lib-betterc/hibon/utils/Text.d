module hibon.utils.Text;

extern(C):
@nogc:

import std.traits : isIntegral, isSigned, Unqual;
import hibon.utils.Memory;
import core.stdc.stdio;

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
        this(_str.length);
        str[0..$]=_str[0..$];
    }
    /**
       This takes over the overship of the data
     */
    this(ref Text _surrender) {
        this.str=_surrender.str;
        this.index=_surrender.index;
        _surrender.str=null;
        _surrender.index=0;
    }

    char opIndex(const size_t i) pure const {
        if (i < index) {
            return str[i];
        }
        return '\0';
    }

    string opSlice(const size_t from, const size_t to) const
        in {
            assert(from<=to);
            assert(to<=index);
        }
    do {
        return cast(string)(str[from..to]);
    }

    const(char[]) opSlice() const pure {
        return str[0..index];
    }

    alias serialize=opSlice;
    void opOpAssign(string op)(const(char[]) cat) if (op == "~") {
        const new_index=index+cat.length;
        scope(exit) {
            index=new_index;
        }
        if (index+cat.length > str.length) {
            resize(str, index+cat.length);
        }
        str[index..new_index]=cat;
    }

    //alias opCall=opOpAssign;

    ref Text opCall(T)(T num, const uint base=10) if(isIntegral!T) {
        //const negative=(num < 0);
        enum numbers="0123456789abcdef";
        static if (isSigned!T) {
            enum max_size=T.min.stringof.length;
        }
        else {
            enum max_size=T.max.stringof.length;
        }

        if (index+max_size > str.length) {
            resize(str, index+max_size);
        }
        static if (isSigned!T) {
            if (num<0) {
                str[index]='-';
                num=-num;
                index++;
            }
        }
        const(char[]) fill_numbers(T num, char[] s) {
            alias Mutable=Unqual!T;
            Mutable n=num;
            uint i;
            do {
                s[i++] = numbers[n % base];
                n/=base;
            } while (n  > 0);
            return s[0..i];
        }
        char[max_size] buf;
        const reverse_numbers=fill_numbers(num, buf);
        foreach_reverse(i, c; reverse_numbers) {
            str[index]=c;
            index++;
        }
        return this;
    }

    ~this() {
        str.dispose;
    }
}

unittest {
    import core.stdc.stdio;
    Text text;
    immutable(char[12]) check="Some text 42";
    size_t size=4;
    text~=check[0..size];
    assert(text.serialize == check[0..size]);
    text~=check[size..size+6];
    size+=6;
    assert(text.serialize == check[0..size]);
    text(42);
    assert(text.serialize == check);
}
