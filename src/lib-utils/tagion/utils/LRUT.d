module tagion.utils.LRUT;

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
    uint evictCounter;

    void onEvicted(scope const(int) i, TestLRU.Element* e) @safe {
        assert(e.entry.key == e.entry.value);
        evictCounter++;
    }

    enum amount = 8;
    double ttl = 0.5; // max age in seconds

    auto l = new TestLRU(&onEvicted, amount, ttl);
    foreach (i; 0 .. amount) {
        l.add(i, i);
    }
    
    Thread.sleep(500.msecs);

    l.add(999,999);

    assert(l.expired(1));
    assert(!l.expired(999));
    
    bool ok;
    int v;

    ok = l.get(1,v);
    assert(!ok);

    ok = l.get(999,v);
    assert(ok)
    assert(v == 999);

}


