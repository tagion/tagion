module hibon.utils.Stack;

extern(C):
import hibon.utils.Memory;
import core.stdc.stdio;

@nogc:
struct Stack(T) {
    struct Element {
        Element* next;
        T value;
    }
    protected {
        Element* root;
    }
    // this() {
    //     root=null;
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

    @property empty() const pure {
        return root is null;
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
    enum table=[7, 6, 5, 4, 3, 2, 1];
    foreach(t; table) {
        q.push(t);
    }

//    check=table;
    size_t i=table.length;
    int[table.length] check=table;
    foreach(b; q[]) {
        i--;
        assert(check[i] is b);
    }
}
