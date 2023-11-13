module tagion.logger.Statistic;

import std.exception : assumeWontThrow;
import std.format;
import std.meta : AliasSeq;
import std.typecons : Flag, No, Tuple, Yes;
import tagion.hibon.HiBONRecord;

@safe @recordType("S")
struct Statistic(T, Flag!"histogram" flag = No.histogram) {
    protected {
        double sum2 = 0.0;
        double sum = 0.0;
        @label("min") T _min = T.max;
        @label("max") T _max = T.min;
        uint N;
        static if (flag) {
            @label("H") uint[T] _histogram;
        }
    }

    void opCall(const T value) pure nothrow {
        import std.algorithm.comparison : max, min;

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
                    (ref uint a) => a += 1);
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
    string toString() pure const nothrow {
        return assumeWontThrow(format("N=%d sum2=%s sum=%s min=%s max=%s", N, sum2, sum, _min, _max));
    }

    static if (flag == Yes.histogram) {

        string histogramString() pure const nothrow {
            import std.algorithm : min, sort;
            import std.format;
            import std.range : repeat;

            string[] result;
            foreach (keypair; _histogram.byKeyValue.array.sort!((a, b) => a.key < b.key)) {
                const number = keypair.key;
                const size = keypair.value;
                result ~= assumeWontThrow(format("%4d|%4d| %s", number, size, "#".repeat(min(size, 100)).join));
            }

            return result.join("\n");

        }

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

version (unittest) {
    import std.algorithm.iteration : each, filter;
    import std.algorithm.searching : count, maxElement, minElement;
    import std.math : isClose;

    alias approx = (a, b) => isClose(a, b, 0.001);
}
