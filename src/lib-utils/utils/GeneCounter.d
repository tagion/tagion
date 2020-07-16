


void count(ref ulong[] bit_count, ulong x) {
    foreach(ref res; bit_count) {
        if (x is 0) {
            break;
        }
        const carrier = res & x;
        res&=~carrier;
        res|=x;
        x=carrier;
    }
}


const(ulong) full_adder(scope ref ulong c_in, const ulong a, const ulong b) pure nothrow {
    const c_out=(a & b) | (a & c) | (b & c);
    scope(exit) {
        c_in=c_out;
    }
    return a ^ b ^ c_in;
}

ulong[] add(scope const(ulong[]) A, scope const(ulong[])B )
    in {
        assert(A.length == B.length);
    }
do {
    scope result=new ulong[a.length+1];
    scope ulong c_in;
    foreach(i, ref r, a, b; lockstep(result, A, B, SameSomthing)) {
        if ((a is 0) && (b is 0)) {
            r=c_in;
            result.length=i;
            break;
        }
        r=full_adder(c_in, a, b);
        // const c_out=a & b | a & c | b & c;
        // r=a ^ b ^ c_in;
        // c_in=c_out;
    }
    return result;
}
