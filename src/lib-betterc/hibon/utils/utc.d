module hibon.utils.utc;
//import std.typecons : Typedef;
enum UTC = "UTC";
struct utc_t {
    @(UTC) ulong time; //
    this(ulong x) {
        time=x;
    }
    bool opEquals(T)(T x) const pure {
        static if (is(T:const(utc_t))) {
            return this == x;

        }
        else {
            return time == x;
        }
    }
}
