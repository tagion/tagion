module hibon.utils.Stack;

extern(C):
@nogc:

import hibon.utils.Memory;
import core.stdc.stdio;

struct Stack(T) {
    struct Element {
        Element* next;
        T value;
    }
    protected {
        Element* root;
    }
    // this() {
    //     top=null;
    // }
    ~this() {
        dispose;
    }

    void dispose() {
        static void _dispose(ref Element* e) {
            if (e !is null) {
                _dispose(e.next);
                e.dispose;
            }
        }
        printf("before _dispose(root)=%p\n", root);
        _dispose(root);
        printf("after _dispose(root)=%p\n", root);
    }

    void push(T x) {
        auto new_e=create!(Element*);
        new_e.value=x;
        new_e.next=root;
        root=new_e;
    }

    T pop() {
        scope(exit) {
            if (root !is null) {
                auto temp_e=root;
                root=root.next;
                temp_e.dispose;
            }
        }
        return root.value;
    }

    @property T top() {
        return root.value;
    }

    @property bool empty() const pure {
        return root is null;
    }

    @property size_t length() const pure {
        size_t count;
        for(Element* e=cast(Element*)root; e !is null; e=e.next) {
            count++;
        }
        return count;
    }

    Range opSlice() {
        return Range(root);
    }

    struct Range {
        private Element* current;
        bool empty() const pure {
            return (current is null);
        }

        T front() pure {
            return current.value;
        }

        void popFront() {
            current=current.next;
        }
    }

}

unittest {
    Stack!int q;
    const(int[7]) table=[7, 6, 5, 4, 3, 2, 1];

    assert(q.empty);
    foreach(t; table) {
        q.push(t);
    }

    assert(!q.empty);
    assert(table.length == q.length);
    assert(q.top == table[table.length-1]);

    size_t i=table.length;
    int[table.length] check=table;
    foreach(b; q[]) {
        i--;
        assert(check[i] is b);
    }

    foreach_reverse(j;0..table.length) {
        assert(q.top == table[j]);
        q.pop;
    }
}
