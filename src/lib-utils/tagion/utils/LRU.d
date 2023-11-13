module tagion.utils.LRU;

// EvictCallback is used to get a callback when a cache entry is evicted

//import std.stdio;
import std.algorithm : map;
import std.conv;
import std.format;
import std.traits;
import tagion.utils.DList;
import tagion.utils.Result;

// LRU implements a non-thread safe fixed size LRU cache
@safe
class LRU(K, V) {
    enum does_not_have_immutable_members = __traits(compiles, { V v; void f(ref V _v) {
            _v = v;} });

            static if (!does_not_have_immutable_members) {
                static assert(hasMember!(V, "undefined"), format(
                    "%s must have a static member named 'undefined'", V.stringof));
            }

            @safe @nogc struct Entry {
                K key;
                V value;
                this(K key, ref V value) pure nothrow {
                    this.key = key;
                    this.value = value;
                }
            }

            alias EvictList = DList!(Entry*);
            alias Element = EvictList.Element;
            private EvictList evictList;
            private Element*[K] items;
            alias void delegate(scope const(K), Element*) @safe nothrow EvictCallback;
            immutable uint size;
            private EvictCallback onEvict;

            // NewLRU constructs an LRU of the given size
            // size zero means unlimited
            this(EvictCallback onEvict = null, immutable uint size = 0) pure nothrow {
                this.size = size;
                //evictList =  EvictList;
                this.onEvict = onEvict;
            }

            // purge is used to completely clear the cache
            void purge() {
                foreach (ref k, ref e; items) {
                    if (onEvict !is null) {
                        onEvict(k, e);
                    }
                }
                items = null;
                evictList = EvictList.init;
            }

            // add adds a value to the cache.  Returns true if an eviction occurred.
            //    @trusted // <--- only in debug
            bool add(scope const(K) key, ref V value) {
                // Check for existing item
                auto ent = key in items;
                if (ent !is null) {
                    auto element = *ent;
                    evictList.moveToFront(element);
                    //            onEvict(element, CallbackType.MOVEFRONT);
                    return false;
                }

                // Add new item
                auto entry = new Entry(key, value);
                auto element = evictList.unshift(entry);
                items[key] = element;

                bool evict = (size != 0) && (evictList.length > size);
                // Verify size not exceeded
                if (evict) {
                    // Remove the oldest element
                    removeOldest;
                }
                return evict;
            }

            // Get looks up a key's value from the cache.
            static if (does_not_have_immutable_members) {
                bool get(scope const(K) key, ref V value) nothrow {

                    auto ent = key in items;
                    if (ent !is null) {
                        auto element = *ent;
                        evictList.moveToFront(element);
                        value = element.entry.value;
                        return true;
                    }
                    return false;
                    // }
                    // assert(0,
                    //     format("%s has immutable members, use %s instead", V.stringof, opIndex(key).stringof));
                }
            }

            V opIndex(scope const(K) key) {
                static if (does_not_have_immutable_members) {
                    V value;
                    get(key, value);
                    return value;
                }
                else {
                    auto ent = key in items;
                    if (ent !is null) {
                        auto element = *ent;
                        evictList.moveToFront(element);
                        return element.entry.value;
                    }
                    return V.undefined;
                }
            }

            void opIndexAssign(ref V value, scope const(K) key) {
                add(key, value);
            }

            // Check if a key is in the cache, without updating the recent-ness
            // or deleting it for being stale.
            @nogc
            bool contains(scope const(K) key) const pure nothrow {
                return (key in items) !is null;
            }

            // Returns the key value (or undefined if not found) without updating
            // the "recently used"-ness of the key.
            static if (does_not_have_immutable_members) {
                @nogc
                bool peek(const(K) key, ref V value) pure nothrow {
                    auto ent = key in items;
                    if (ent !is null) {
                        value = (*ent).entry.value;
                        return true;
                    }
                    return false;
                }
            }

            V peek(const(K) key) {
                static if (does_not_have_immutable_members) {
                    V value;
                    peek(key, value);
                    return value;
                }
                else {
                    auto ent = key in items;
                    if (ent !is null) {
                        return (*ent).entry.value;
                    }
                    return V.undefined;
                }
            }

            // Remove removes the provided key from the cache, returning if the
            // key was contained.

            bool remove(scope const(K) key) {
                auto ent = key in items;
                if (ent !is null) {
                    auto element = *ent;
                    if (onEvict !is null) {
                        onEvict(key, element);
                    }
                    evictList.remove(element);
                    items.remove(key);
                    return true;
                }
                return false;
            }

            @nogc
            void setEvict(EvictCallback evict) nothrow {
                onEvict = evict;
            }

            // RemoveOldest removes the oldest item from the cache.
            const(Result!(Entry*)) removeOldest() nothrow {
                const e = evictList.pop;
                if (!e.error) {
                    auto element = items[e.value.key];
                    items.remove(e.value.key);
                    if (onEvict !is null) {
                        onEvict(e.value.key, element);
                    }
                }
                return e;
            }

            // GetOldest returns the oldest entry
            @nogc
            const(Entry)* getOldest() const pure nothrow {
                auto last = evictList.last;
                if (last) {
                    return evictList.last.entry;
                }
                else {
                    return null;
                }
            }

            /// keys returns a slice of the keys in the cache, from oldest to newest.
            @nogc
            auto keys() pure nothrow {
                return evictList.revert.map!(a => a.key);
            }

            // length returns the number of items in the cache.
            @nogc
            uint length() pure const nothrow {
                return evictList.length;
            }

            @nogc EvictList.Range!false opSlice() nothrow {
                return evictList[];
            }

            invariant {
                assert(items.length == evictList.length);
            }
        }

    unittest {
        alias LRU!(int, int) TestLRU;
        uint evictCounter;

        void onEvicted(scope const(int) i, TestLRU.Element* e) @safe {
            assert(e.entry.key == e.entry.value);
            evictCounter++;
        }

        enum amount = 8;
        auto l = new TestLRU(&onEvicted, amount);
        foreach (i; 0 .. amount) {
            l.add(i, i);
        }
    }

    unittest {
        alias LRU!(int, int) TestLRU;
        uint evictCounter;

        void onEvicted(scope const(int) i, TestLRU.Element* e) @safe {
            assert(e.entry.key == e.entry.value);
            evictCounter++;
        }

        enum amount = 8;
        auto l = new TestLRU(&onEvicted, amount);
        foreach (i; 0 .. amount * 2) {
            l.add(i, i);
            if (i < amount) {
                assert(i + 1 == l.length);
            }
            else {
                assert(amount == l.length);
            }
        }
        assert(l.length == amount);
        assert(evictCounter == amount);
        int v;
        bool ok;
        import std.range : enumerate;

        foreach (i, k; l.keys.enumerate) {
            ok = l.get(k, v);
            assert(ok);
            assert(k == v);
            assert(v == i + amount);
        }
        foreach (j; 0 .. amount) {
            ok = l.get(j, v);
            assert(!ok, "should be evicted");
        }

        foreach (j; amount .. amount * 2) {
            ok = l.get(j, v);
            assert(ok, "should not be evicted");
        }
        enum amount2 = (amount + amount / 2);
        foreach (j; amount .. amount2) {
            ok = l.remove(j);
            assert(ok, "should contain j");
            ok = l.remove(j);
            assert(!ok, "should not be contained");
            ok = l.get(j, v);
            assert(!ok, "should be deleted");
        }

        l.get(amount2, v); // expect amount2 to be last key in l.Keys()

        foreach (i, k; l.keys.enumerate) {
            enum amount_i = amount / 2 - 1;
            bool not_good = ((i < amount_i) && (k != i + amount2 + 1)) || ((i == amount_i) && (
                    k != amount2));
            assert(!not_good, "out of order key: " ~ to!string(k));
        }

        l.purge();
        assert(l.length == 0);

        ok = l.get(200, v);
        assert(!ok, "should contain nothing");
    }

    unittest { // getOldest removeOldest
        alias LRU!(int, int) TestLRU;
        uint evictCounter;
        void onEvicted(scope const(int) i, TestLRU.Element* e) @safe {
            assert(e.entry.key == e.entry.value);
            evictCounter++;
        }

        enum amount = 8;
        auto l = new TestLRU(&onEvicted, amount);
        bool ok;
        foreach (i; 0 .. amount * 2) {
            l.add(i, i);
        }
        auto e = l.getOldest();
        assert(e !is null, "missing");
        assert(e.value == amount, "bad value " ~ to!string(e.key));
        e = l.removeOldest.value;
        assert(e !is null, "missing");
        assert(e.value == amount, "bad value " ~ to!string(e.key));
        e = l.removeOldest.value;
        assert(e !is null, "missing");
        assert(e.value == amount + 1, "bad value " ~ to!string(e.value));
    }

    // Test that Add returns true/false if an eviction occurred
    unittest { // add
        alias LRU!(int, int) TestLRU;
        uint evictCounter;
        void onEvicted(scope const(int) i, TestLRU.Element* e) @safe {
            assert(e.entry.key == e.entry.value);
            evictCounter++;
        }

        bool ok;
        auto l = new TestLRU(&onEvicted, 1);
        // evictCounter := 0
        // onEvicted := func(k interface{}, v interface{}) {
        // 	evictCounter += 1
        // }

        // l := NewLRU(1, onEvicted)
        int x = 1;
        ok = l.add(1, x);
        assert(!ok);
        assert(evictCounter == 0, "should not have an eviction");
        x++;
        ok = l.add(2, x);
        assert(ok);
        assert(evictCounter == 1, "should have an eviction");
    }

    // Test that Contains doesn't update recent-ness
    //func TestLRU_Contains(t *testing.T) {
    unittest {
        alias LRU!(int, int) TestLRU;
        void onEvicted(scope const(int) i, TestLRU.Element* e) @safe {
            assert(e.entry.key == e.entry.value);
        }

        auto l = new TestLRU(&onEvicted, 2);
        // l := NewLRU(2, nil)

        int x = 1;

        l.add(1, x);
        x++;
        l.add(2, x);
        x++;
        assert(l.contains(1), "1 should be contained");
        l.add(3, x);
        assert(!l.contains(1), "Contains should not have updated recent-ness of 1");

    }

    // Test that Peek doesn't update recent-ness
    //func TestLRU_Peek(t *testing.T) {
    unittest {
        alias LRU!(int, int) TestLRU;
        void onEvicted(scope const(int) i, TestLRU.Element* e) @safe {
            assert(e.entry.key == e.entry.value);
        }

        auto l = new TestLRU(&onEvicted, 2);
        //	l := NewLRU(2, nil)
        int x = 1;

        l.add(1, x);
        x++;
        l.add(2, x);
        x++;
        int v;
        bool ok;
        ok = l.peek(1, v);
        assert(ok);
        assert(v == 1, "1 should be set to 1 not " ~ to!string(v));
        l.add(3, x);
        assert(!l.contains(1), "should not have updated recent-ness of 1");
    }

    unittest { // Test undefined
        @safe struct E {
            immutable(char[]) x;
            static E undefined() {
                return E("Not found");
            }
        }

        alias TestLRU = LRU!(int, E);
        uint count;
        import std.stdio;

        void onEvicted(scope const(int) i, TestLRU.Element* e) @safe {
            count++;
        }

        auto l = new TestLRU(&onEvicted);

        enum N = 4;
        foreach (int i; 0 .. N) {
            auto e = E(i.to!string);
            l[i] = e;
        }

        assert(l[N] == E.undefined);
        assert(l[N - 1] != E.undefined);
        assert(l.length == N);
        assert(l.remove(2));
        assert(count == 1);
        assert(l.length == N - 1);
        assert(l[2] == E.undefined);
    }
