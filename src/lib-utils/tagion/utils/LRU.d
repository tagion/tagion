module tagion.utils.LRU;

//TAKEN FROM HASHICORP LRU

//import "container/list"

// EvictCallback is used to get a callback when a cache entry is evicted

//import tango.util.container.LinkedList;
//import std.stdio;
import tagion.utils.DList;
import std.conv;


// LRU implements a non-thread safe fixed size LRU cache
@safe
class LRU(K,V)  {
    struct Entry {
        K key;
        V value;
        this(K key, V value) {
            this.key=key;
            this.value=value;
        }
    };
    alias DList!(Entry*)  EvictList;
    alias EvictList.Element Element;
    private EvictList evictList;
    private Element*[K] items;
    alias void delegate(Element*) @safe EvictCallback;
    immutable uint      size;
    private EvictCallback onEvict;



// NewLRU constructs an LRU of the given size
    // size zero means unlimited
    this( EvictCallback onEvict, immutable uint size=0) {
        this.size=      size;
        evictList = new EvictList;
            //	items:     make(map[interface{}]*list.Element),
        this.onEvict=onEvict;
    }

// purge is used to completely clear the cache
    void purge() {
        foreach(ref k, ref e; items)  {
            if (onEvict !is null) {
                onEvict(e);
            }
	}
        items = null;
	evictList = new EvictList;
    }

// add adds a value to the cache.  Returns true if an eviction occurred.
    @trusted // <--- only in debug
    bool add(const(K) key, V value ) {
        // Check for existing item
        auto ent = key in items;
        if ( ent !is null ) {
            auto element=*ent;
            evictList.moveToFront(element);
//            onEvict(element, CallbackType.MOVEFRONT);
            return false;
        }

        // Add new item
        auto entry=new Entry(key, value);
        auto element=evictList.unshift(entry);
        items[key] = element;

        bool evict = (size!=0) && (evictList.length > size);
        // Verify size not exceeded
        if (evict) {
            // Remove the oldest element
            removeOldest;
        }
        static if ( is (K:const(ubyte)[]) ) {
            import std.stdio;
            import tagion.crypto.Hash : toHexString;
//            writefln("Add[%s]=%s evict=%s", key.toHexString, value.id, evict);
        }
        return evict;
    }

// Get looks up a key's value from the cache.
    bool get(const(K) key, ref V value) {
        auto ent = key in items;
        if ( ent !is null ) {
            auto element=*ent;
            evictList.moveToFront(element);
//            onEvict(element, CallbackType.MOVEFRONT);
            value=element.entry.value;
            return true;
        }
        return false;
    }

    V opIndex(const(K) key) {
        V value;
        get(key, value);
        return value;
    }

    void opIndexAssign(ref V value, const(K) key) {
        add(key, value);
    }
// Check if a key is in the cache, without updating the recent-ness
// or deleting it for being stale.
    bool contains(const(K) key) const {
        return (key in items) !is null;
    }

// Returns the key value (or undefined if not found) without updating
// the "recently used"-ness of the key.
    bool peek(const(K) key, ref V value) {
        auto ent = key in items;
	if ( ent !is null ) {
            value=(*ent).entry.value;
            return true;
	}
	return false;
    }

// Remove removes the provided key from the cache, returning if the
// key was contained.
    bool remove(const(K) key) {
        auto ent=key in items;
        if ( ent !is null ) {
            auto element=*ent;
            onEvict(element);
            evictList.remove(element);
            items.remove(key);
            return true;
        }
        return false;
    }

// RemoveOldest removes the oldest item from the cache.
    const(Entry)* removeOldest() {

        auto ent = evictList.pop;
        if (ent !is null) {
            auto element=items[ent.key];
            items.remove(ent.key);
            onEvict(element);
        }
        return ent;
    }

// GetOldest returns the oldest entry
    const(Entry)* getOldest() {
        auto last=evictList.last;
        if ( last ) {
            return evictList.last.entry;
        }
        else {
            return null;
        }
    }
//}

// keys returns a slice of the keys in the cache, from oldest to newest.
    immutable(K[]) keys() {
        immutable(K)[] result;
	uint i;
        foreach_reverse(entry; evictList) {
            result~=entry.key;
	}
	return result;
    }

// length returns the number of items in the cache.
    uint length() pure const {
        return evictList.length;
    }

    EvictList.Iterator iterator() {
        return evictList.iterator;
    }

    invariant {
        assert(items.length == evictList.length);
    }
// // removeOldest removes the oldest item from the cache.
//     void removeOldest() {
//         auto ent = evictList.Back();
//         if ( ent !is null) {
//             removeElement(ent);
// 	}
//     }

// // removeElement is used to remove a given list element from the cache
//     func (c *LRU) removeElement(e *list.Element) {
// 	c.evictList.Remove(e)
// 	auto kv = e.Value.(*entry)
// 	delete(c.items, kv.key)
// 	if c.onEvict != nil {
// 		c.onEvict(kv.key, kv.value)
// 	}
//     }
}

// package common

// import "testing"

// func TestLRU(t *testing.T) {
// 	evictCounter := 0
unittest {
    alias LRU!(int,int) TestLRU;
    uint evictCounter;

    void onEvicted(TestLRU.Element* e) @safe {
        assert( e.entry.key == e.entry.value );
        evictCounter++;
    }
    enum amount = 8;
    auto l = new TestLRU(&onEvicted, amount);
    foreach(i;0..amount) {
        l.add(i, i);
    }
}

unittest {
    alias LRU!(int,int) TestLRU;
    uint evictCounter;

    void onEvicted(TestLRU.Element* e) @safe {
        assert( e.entry.key == e.entry.value );
        evictCounter++;
    }
    enum amount = 8;
    auto l = new TestLRU(&onEvicted, amount);
    foreach(i;0..amount*2) {
        l.add(i, i);
        if ( i < amount ) {
            assert(i+1 == l.length);
        }
        else {
            assert(amount == l.length);
        }
    }
    assert(l.length == amount);
    assert(evictCounter == amount);
    int v;
    bool ok;
    foreach(i, k; l.keys ) {
        ok=l.get(k, v);
        assert(ok);
        assert(k == v);
        assert(v == i+amount);
    }
    foreach(j; 0..amount) {
        ok=l.get(j, v);
        assert(!ok, "should be evicted");
    }

    foreach(j; amount..amount*2) {
        ok=l.get(j, v);
        assert(ok, "should not be evicted");
    }
    enum amount2=(amount+amount/2);
    foreach(j; amount..amount2) {
        ok = l.remove(j);
        assert(ok, "should be contained");
        ok = l.remove(j);
        assert(!ok, "should not be contained");
        ok = l.get(j, v);
        assert(!ok, "should be deleted");
    }

    l.get(amount2, v); // expect amount2 to be last key in l.Keys()

    foreach(i, k; l.keys) {
        enum amount_i = amount/2-1;
        bool not_good=((i < amount_i) && (k != i+amount2+1)) || ((i == amount_i) && (k != amount2));
        assert(!not_good, "out of order key: "~to!string(k));
    }

    l.purge();
    assert(l.length==0);

    ok = l.get(200, v);
    assert(!ok, "should contain nothing");
}

//func TestLRU_GetOldest_RemoveOldest(t *testing.T) {
unittest { // getOldest removeOldest
    alias LRU!(int,int) TestLRU;
    uint evictCounter;
    void onEvicted(TestLRU.Element* e) @safe {
        assert( e.entry.key == e.entry.value );
        evictCounter++;
    }
    enum amount = 8;
    auto l = new TestLRU(&onEvicted, amount);
    bool ok;
    foreach(i;0..amount*2) {
        l.add(i, i);
    }
    auto e = l.getOldest();
    assert(e !is null, "missing");
    // if !ok {
    // 	t.Fatalf("missing")
    // }
    assert(e.value == amount, "bad value "~to!string(e.key));
	// if k.(int) != 128 {
	// 	t.Fatalf("bad: %v", k)
	// }

    e = l.removeOldest();
    assert(e !is null, "missing");
    assert(e.value == amount, "bad value "~to!string(e.key));
	// if !ok {
	// 	t.Fatalf("missing")
	// }
	// if k.(int) != 128 {
	// 	t.Fatalf("bad: %v", k)
	// }
    e = l.removeOldest();
    assert(e !is null, "missing");
    assert(e.value == amount+1, "bad value "~to!string(e.value));

	// k, _, ok = l.RemoveOldest()
	// if !ok {
	// 	t.Fatalf("missing")
	// }
	// if k.(int) != 129 {
	// 	t.Fatalf("bad: %v", k)
	// }
}

// Test that Add returns true/false if an eviction occurred
unittest { // add
//func TestLRU_Add(t *testing.T) {
    alias LRU!(int,int) TestLRU;
    uint evictCounter;
    void onEvicted(TestLRU.Element* e) @safe {
        assert( e.entry.key == e.entry.value );
        evictCounter++;
    }
    bool ok;
    auto l = new TestLRU(&onEvicted, 1);
	// evictCounter := 0
	// onEvicted := func(k interface{}, v interface{}) {
	// 	evictCounter += 1
	// }

	// l := NewLRU(1, onEvicted)
    ok = l.add(1, 1);
    assert(!ok);
    assert(evictCounter == 0, "should not have an eviction");
    ok = l.add(2, 2);
    assert(ok);
    assert(evictCounter == 1, "should have an eviction");
}

// Test that Contains doesn't update recent-ness
//func TestLRU_Contains(t *testing.T) {
unittest {
    alias LRU!(int,int) TestLRU;
    void onEvicted(TestLRU.Element* e) @safe {
        assert( e.entry.key == e.entry.value );
    }
    auto l = new TestLRU(&onEvicted, 2);
	// l := NewLRU(2, nil)

    l.add(1, 1);
    l.add(2, 2);
    assert(l.contains(1), "1 should be contained");
    l.add(3, 3);
    assert(!l.contains(1), "Contains should not have updated recent-ness of 1");

}

// Test that Peek doesn't update recent-ness
//func TestLRU_Peek(t *testing.T) {
unittest {
    alias LRU!(int,int) TestLRU;
    void onEvicted(TestLRU.Element* e) @safe {
        assert( e.entry.key == e.entry.value );
    }
    auto l = new TestLRU(&onEvicted, 2);
//	l := NewLRU(2, nil)

    l.add(1, 1);
    l.add(2, 2);
    int v;
    bool ok;
    ok = l.peek(1, v);
    assert(ok);
    assert(v == 1, "1 should be set to 1 not "~to!string(v));
    l.add(3, 3);
    assert( !l.contains(1), "should not have updated recent-ness of 1");
}
