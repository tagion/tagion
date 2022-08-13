module tagion.logger.Statistic;

import std.typecons : Tuple, Flag, Yes, No;
import std.meta : AliasSeq;
import std.format;

import tagion.hibon.HiBONRecord;

@safe
struct Statistic(T, Flag!"histogram" flag=No.histogram) {
    protected {
        double sum2 = 0.0;
        double sum = 0.0;
        T _min = T.max, _max = T.min;
        uint N;
        static if (flag) {
            uint[T] _histogram;
        }
    }

    void opCall(const T value) pure nothrow {
        import std.algorithm.comparison : min, max;

        _min = min(_min, value);
        _max = max(_max, value);
        immutable double x = value;
        sum += x;
        sum2 += x * x;
        N++;
        static if (flag) {
            _histogram.update(
                value,
                () => 1,
                (ref uint a) => a+=1);
        }
    }


    alias Result = Tuple!(double, "sigma", double, "mean", uint, "N", T, "min", T, "max");
    mixin HiBONRecord;

    const pure nothrow @nogc {
    const(Result) result() {
        immutable mx = sum / N;
        immutable mx2 = mx * mx;
        immutable M = sum2 + N * mx2 - 2 * mx * sum;
        import std.math : sqrt;
        return Result(sqrt(M / (N - 1)), mx, N, _min, _max);
    }


    static if (flag) {
        bool contains(const T size) {
            return (size in _histogram) !is null;
        }

        const(uint[T]) histogram() {
            return _histogram;
        }
    }
    }
    string toString() const {
        return format("N=%d sum2=%s sum=%s min=%s max=%s", N, sum2, sum, _min, _max);
    }

}

///
@safe
unittest {
    Statistic!uint s;
    const samples = [10, 15, 17, 6, 8, 12, 18];
    samples.each!(a => s(a));

    auto r = s.result;
    // Mean
    assert(approx(r.mean, 12.2857));
    // Number of samples
    assert(r.N == samples.length);
    // Sigma
    assert(approx(r.sigma, 4.5721));

    assert(r.max == samples.maxElement);
    assert(r.min == samples.minElement);

}

///
@safe
unittest {
    /// Use of the Statistic including histogram
    Statistic!(long, Yes.histogram) s;
    const samples = [-10, 15, -10, 6, 8, -12, 18, 8, -12, 9, 4, 5, 6];
    samples.each!(n => s(n));

    auto r = s.result;
    // Mean
    assert(approx(r.mean, 2.6923));
    // Number of samples
    assert(r.N == samples.length);
    // Sigma
    assert(approx(r.sigma, 10.266));

    assert(r.max == samples.maxElement);
    assert(r.min == samples.minElement);

    // samples/histogram does not contain -4
    assert(!s.contains(-4));
    // but conatians -10
    assert(s.contains(-10));

    // Get the statiscal histogram
    const histogram = s.histogram;

    assert(histogram.get(-4, 0) == 0);
    assert(histogram.get(-10, 0) > 0);

    // verifies the number of samples in the histogram
    assert(histogram.get(-10, 0) == samples.filter!(a => a == -10).count);
}

version(unittest) {
    import std.algorithm.iteration : each, filter;
    import std.algorithm.searching : count, maxElement, minElement;
    import std.math.operations : isClose;
    alias approx = (a, b) => isClose(a, b, 0.001);
}
