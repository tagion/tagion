module tagion.utils.Statistic;

import std.typecons : Tuple;

struct Statistic(T) {
//    enum Limits : double { MEAN=10, SUM=100 }
    protected {
        double sum2=0.0;
        double sum=0.0;
        T _min=T.max, _max=T.min;
        uint N;
    }


    ref Statistic opCall(const T value) {
        import std.algorithm.comparison : min, max;
        _min=min(_min, value);
        _max=max(_max, value);
        immutable double x=value;
        sum+=x;
        sum2+=x*x;
        N++;
        return this;
    }

    alias Result=Tuple!(double, "sigma", double, "mean", uint , "N", T, "min", T, "max" );
    const(Result) result() const pure nothrow {
        immutable mx=sum/N;
        immutable mx2=mx*mx;
        immutable M=sum2+N*mx2-2*mx*sum;
        import std.math : sqrt;
        return Result(sqrt(M/(N-1)), mx, N, _min, _max);
    }
}

unittest {
    Statistic!uint s;
    foreach(size; [10, 15, 17, 6, 8, 12, 18]) {
        s(size);
    }
    auto r=s.result;
    // Mean
    assert(cast(int)(r.mean*1_0000) == 12_2857);
    // Sum
    assert(r.N == 7);
    // Sigma
    assert(cast(int)(r.sigma*1_0000) == 4_5721);
}
