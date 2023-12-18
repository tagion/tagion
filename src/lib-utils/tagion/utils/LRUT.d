module tagion.utils.LRUT;

import core.atomic;
import std.algorithm : map;
import std.conv;
import std.format;
import std.traits;
import std.datetime.systime;
import tagion.utils.DList;
import tagion.utils.Result;

import tagion.utils.LRU;

@safe:

double timestamp() nothrow
{
    auto ts = Clock.currTime().toTimeSpec();
    return ts.tv_sec + ts.tv_nsec/1e9;
}

// LRUT is a thread-safe timed successor of tagion.utils.LRU

synchronized 
class LRUT(K,V) {
    
    enum does_not_have_immutable_members = __traits(compiles, { V v; void f(ref V _v) { _v = v;} });


    alias LRU_t=LRU!(K, V);
    
    alias Entry = LRU_t.Entry;
    alias EvictList = LRU_t.EvictList;
    alias Element = LRU_t.Element;
    alias EvictCallback = LRU_t.EvictCallback;

    
    protected LRU!(K, V) _lru;
    private immutable double maxage;
    private double[K] ctime;

    this(EvictCallback onEvict = null, immutable uint size = 0, immutable double maxage = 0) nothrow {
        _lru = new LRU_t(null,size);
        auto tmp_lru=(() @trusted => cast(LRU_t)_lru)();
        tmp_lru.setEvict(cast(EvictCallback)onEvict);
        this.maxage = maxage;
    }    

    double upTime( K key ) nothrow {
        auto t = key in ctime;
        return (t !is null) ? timestamp() - *t : -1;
    }
    
    bool expired( K key ) nothrow {
        return (this.maxage > 0) && (upTime(key) > this.maxage);
    }
    
    // -- LRU members wrapped

    // purge is used to completely clear the cache
    void purge() {
        auto tmp_lru=(() @trusted => cast(LRU_t)_lru)();
        tmp_lru.purge();
        ctime = null;
    }


    // add adds a value to the cache.  Returns true if an eviction occurred.
    bool add( K key, ref V value, bool update = false) {
        auto tmp_lru=(() @trusted => cast(LRU_t)_lru)();
        if(tmp_lru.contains(key) && update){
            tmp_lru.update(key,value);
            ctime[key] = timestamp;
            return false;
        }
        ctime[key] = timestamp;
        return tmp_lru.add(key,value);
    }

    // updates the value if exists or inserts if flag pecified
    bool update(const(K) key, ref V value, bool upsert = false){
        auto tmp_lru=(() @trusted => cast(LRU_t)_lru)();
        ctime[key] = timestamp;
        return tmp_lru.update(key, value, upsert);
    }

    // Get looks up a key's value from the cache.
    static if (does_not_have_immutable_members) {
        bool get( K key, ref V value) {
            auto tmp_lru=(() @trusted => cast(LRU_t)_lru)();
            if(expired(key)){
                tmp_lru.remove(key);
                return false;
            }    
            return tmp_lru.get(key, value);
        }
    }

    V opIndex( K key) {
        auto tmp_lru=(() @trusted => cast(LRU_t)_lru)();
        if(expired(key)){
            tmp_lru.remove(key);
            static if (hasMember!(V, "undefined")) {
                return V.undefined;
            } else {
                return V.init;
            }                        
        }
        return tmp_lru.opIndex(key);
    }

    void opIndexAssign(ref V value, const(K) key) {
        auto tmp_lru=(() @trusted => cast(LRU_t)_lru)();
        tmp_lru.add(key, value);
    }

    // Check if a key is in the cache, without updating the recent-ness or deleting it for being stale.
    bool contains( K key ) nothrow {
        auto tmp_lru=(() @trusted => cast(LRU_t)_lru)();
        if(expired(key)){
            tmp_lru.remove(key);
            return false;
        }            
        return tmp_lru.contains(key);
    }

    // Returns the key value (or undefined if not found) without updating
    // the "recently used"-ness of the key.
    static if (does_not_have_immutable_members) {
        bool peek( K key, ref V value) nothrow {
            auto tmp_lru=(() @trusted => cast(LRU_t)_lru)();
            if(expired(key)){
                tmp_lru.remove(key);
                return false;
            }
            return tmp_lru.peek(key, value);
        }
    }

    V peek( K key ) {
        auto tmp_lru=(() @trusted => cast(LRU_t)_lru)();
        if(expired(key)){
            tmp_lru.remove(key);
            static if (hasMember!(V, "undefined")) {
                return V.undefined;
            }else{
                return V.init;
            }    
        }
        return tmp_lru.peek(key);
    }

    // Remove removes the provided key from the cache, returning if the key was contained.
    bool remove(scope const(K) key) {
        auto tmp_lru=(() @trusted => cast(LRU_t)_lru)();
        bool b = tmp_lru.remove(key);
        if(b)
            ctime.remove(key);
        return b;
    }

    @nogc
    void setEvict(EvictCallback evict) nothrow {
        auto tmp_lru=(() @trusted => cast(LRU_t)_lru)();
        tmp_lru.setEvict(evict);
    }

    // RemoveOldest removes the oldest item from the cache.
    const(Result!(Entry*)) removeOldest() nothrow {
        auto tmp_lru=(() @trusted => cast(LRU_t)_lru)();
        auto e = tmp_lru.removeOldest();
        if (!e.error)
            ctime.remove(e.value.key);
        return e;            
    }

    // GetOldest returns the oldest entry
    @nogc
    const(Entry)* getOldest() const pure nothrow {
        auto tmp_lru=(() @trusted => cast(LRU_t)_lru)();
        return tmp_lru.getOldest();
    }


    /// keys returns a slice of the keys in the cache, from oldest to newest.
    @nogc
    auto keys() pure nothrow {
        auto tmp_lru=(() @trusted => cast(LRU_t)_lru)();
        return tmp_lru.keys();
    }

    // length returns the number of items in the cache.
    @nogc
    uint length() pure const nothrow {
        auto tmp_lru=(() @trusted => cast(LRU_t)_lru)();
        return tmp_lru.length();
    }

    @nogc EvictList.Range!false opSlice() nothrow {
        auto tmp_lru=(() @trusted => cast(LRU_t)_lru)();
        return tmp_lru.opSlice();
    }

} // class LRUT


unittest {
    import core.thread;

    alias LRUT!(int, int) TestLRU;
    shared uint evictCounter;
    
    
    void onEvicted(scope const(int) i, TestLRU.Element* e) @safe {
        assert(e.entry.key == e.entry.value);
        core.atomic.atomicOp!"+="(evictCounter, 1);
        //evictCounter++;
    }

    enum amount = 8;
    double ttl = 0.5; // max age in seconds

    auto l = new shared(TestLRU)(&onEvicted, amount, ttl);


    foreach (i; 0 .. amount) {
        l.add(i, i);
    }
    
    (() @trusted => Thread.sleep(500.msecs))();

    int x  = 999;
    l.add(999,x);

    assert(l.expired(1));
    assert(!l.expired(999));
    
    bool ok;
    int v;

    ok = l.get(1,v);
    assert(!ok);

    ok = l.get(999,v);
    assert(ok);
    assert(v == 999);
}

unittest {
    import core.thread;
    import std.random;
    import std.range;
    
    pragma(msg, "LRUT() to start");

    alias LRUT!(int, int) TestLRU;
    
    enum amount = 8;
    enum repeat = 4;
    double ttl = 0.5; // max age in seconds

    auto l = new shared(TestLRU)(null, amount, ttl);
    
    foreach (i; 0 .. amount) {
        l.add(i, i);
    }

    void cache_check_yes(){
        bool ok;
        int v;
        auto rnd = Random(41);
        foreach(j; 0..repeat)            
            foreach(i; 0..amount){
                (() @trusted => Thread.sleep((10.iota.choice(rnd)).msecs))();
                ok = l.get(i,v);    
                assert(ok);
                assert(v == i, "check YES failed");
            }
    }
    
    void cache_check_no(){
        bool ok;
        int v;
        auto rnd = Random(42);
        foreach(j; 0..repeat)            
            foreach(i; 0..amount){
                (() @trusted => Thread.sleep((10.iota.choice(rnd)).msecs))();
                ok = l.get(i,v);    
                assert(!ok, "check NO failed");
            }
    }
    
    void cache_update(){
        bool ok;
        auto rnd = Random(43);
        foreach(j; 0..repeat)            
            foreach(i; 0..amount){
                (() @trusted => Thread.sleep((10.iota.choice(rnd)).msecs))();
                ok = l.update(i,i);    
                assert(ok, "update failed");
            }
    }

    auto t1 = new Thread(&cache_check_yes);
    auto t2 = new Thread(&cache_update);
    auto t3 = new Thread(&cache_check_yes);
    
    pragma(msg, "LRUT() threads to start");
    
    (() @trusted => t1.start() )();
    (() @trusted => t2.start() )();
    (() @trusted => t3.start() )();
    
    (() @trusted => t3.join() )();
    (() @trusted => t2.join() )();
    (() @trusted => t1.join() )();

    pragma(msg, "LRUT() threads joined");
    
    (() @trusted => Thread.sleep(500.msecs))();

    cache_check_no();

    pragma(msg, "LRUT() passed");

}
