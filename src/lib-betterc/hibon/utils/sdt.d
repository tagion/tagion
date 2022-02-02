module hibon.utils.sdt;
//import std.typecons : Typedef;
enum TIME = "TIME";
struct sdt_t {
    @nogc:
    @(TIME) ulong time; //
    this(ulong x) {
        time=x;
    }
    bool opEquals(T)(T x) const pure {
        static if (is(T:const(sdt_t))) {
            return this.time == x.time;

        }
        else {
            return time == x;
        }
    }
}
