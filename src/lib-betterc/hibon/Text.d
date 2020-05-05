module hibon.Text;

extern(C):
import std.traits : isIntegral, isSigned;
import hibon.Memory;

struct Text {
    protected {
        char[] str;
        size_t index;
    }
    this(const size_t size) {
        if (size > 0) {
            str=create!(char[])(size);
        }
    }
    /**
       This takes over the overship of the data
     */
    this(ref Text surender) {
        this.str=surrender.str;
        this.index=surender.index;
        sureneder.str=null;
        sureneder.index=0;
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
    string opSlice() {
        return this[0..index];
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
    // void opOpAssign(string op, T)(T num) if(op == "~" && isIntegral!T) {
    //     append(num, 10);
    // }
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
                str[index]="-";
                num=-num;
                index++;
            }
        }
        const(char[]) fill_numbers(T n, char[] s) {
            uint i;
            do {
                s[i++] = numbers[base % base];
                n/=base;
            } while (n  > 0);
            return s[0..i];
        }
        char[max_size] buf;
        auto reverse_numbers=fill_numbers(num, buf);
        foreach_reverse(i, c; reverse_numbers) {
            str[index+i]=c;
        }
        index+=reverse_numbers.length;
        return this;
    }
    ~this() {
        str.dispose;
    }
}
