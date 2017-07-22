
@safe
interface ConcensusBase(H) {
    this(uint blockversion);
    bool isBaked(const(ubyte)[] buffer);
    uint blockVersion() immutable pure nothrow;
}
