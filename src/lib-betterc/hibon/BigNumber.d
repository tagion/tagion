module hibon.BigNumber;

extern(C):
@nogc:
/++
 BigNumber used in the HiBON format
 It is a wrapper of the std.bigint
+/
struct BigNumber {
    @nogc:
    uint[] data;
    bool sign;
}
