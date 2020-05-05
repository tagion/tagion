module hibon.Queue;

extern(C):
import hibon.Memory;

struct Queue(T) {
    struct Element {
        Element* next;
        T value;
    }
    protected {
        Element* root;
    }
    this() {
        root=null;
    }
    ~this() {
        dispose;
    }
    void dispose() {
        for(Element* e=root; e !is null; e=e.next) {
            e.dispose;
        }
        root=null;
    }
    void push(T x) {
        auto new_e=create!Element;
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

    void empty() const pure {
        return (root is null);
    }

    T front() pure {
        return root;
    }

    void popFront() {
        pop();
    }

}
