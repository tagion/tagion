module hibon.utils.RBTree;
/*
 * [PROG]               : Red Black Tree
 * [AUTHOR]             : Ashfaqur Rahman <sajib.finix@gmail.com>
 * [PURPOSE]            : Red-Black tree is an algorithm for creating a balanced
 *                        binary search tree data structure. Implementing a red-balck tree
 *                        data structure is the purpose of this program.
 *
 * [DESCRIPTION]        : Its almost like the normal binary search tree data structure. But
 *                        for keeping the tree balanced an extra color field is introduced to each node.
 *                        This tree will mantain bellow properties.
 *                                1. Nodes can be either RED or BLACK.
 *                                2. root is BLACK.
 *                                3. Leaves of this tree are null nodes. Here null is represented bya special node null.
 *                                   Each null nodes are BLACK. So each leave is BLACK.
 *                                4. Each RED node's parent is BLACK
 *                                5. Each simple path taken from a node to descendent leaf has same number of black height.
 *                                   That means each path contains same number of BLACK nodes.

 */

extern(C):
@nogc:
import hibon.utils.Memory;
import hibon.utils.Stack;
import core.stdc.stdio;
import std.algorithm.searching : count;

struct RBTree(K, V=void) {
    enum Color { RED, BLACK };
    struct Node {
        K key;
        static if (!is(V==void)) {
            V value;
        }
        else {
            alias value=key;
        }
        Color color;
        Node* parent;
        Node* left;
        Node* right;
    };

    private {
        Node NILL;
        Node* nill;
        Node* root;
        bool owner;
    }
    version(none)
    invariant {
        if ( root is null ) {
            printf("%s root is null\n", __FUNCTION__.ptr);
        }
        assert(root !is null, "Must ctor must be called");
    }

    @disable this();
    this(const bool _owner) {
        NILL.color=Color.BLACK;
        nill=&NILL;
        root=nill;
        owner=_owner;
    }

    ~this() {
        dispose;
    }

    void dispose() {
        void _dispose(Node* current) {
            if (current !is nill) {
                _dispose(current.left);
                _dispose(current.right);
                if (owner) {
                    static if (__traits(compiles, current.key.dispose)) {
                        current.key.dispose;
                    }
                    static if (__traits(compiles, current.value.dispose)) {
                        current.value.dispose;
                    }
                }
                current.dispose;
            }
        }
        _dispose(root);
        root=nill;
    }
    /* Print tree keys by inorder tree walk */

    @property empty() const pure {
        return root is nill;
    }

    protected Node* _search(K key) {
        Node* x = root;
        while ((x !is nill) && (x.key != key)) {
            if (x.key > key) {
                x = x.left;
            }
            else {
                x = x.right;
            }
        }
        return x;
    }

    const(Node*) search(K key) const pure {
        const(Node*) _search(const(Node*) current) pure {
            if (current !is nill) {
                if (current.key == key) {
                    return current;
                }
                else if (current.key > key) {
                    return _search(current.left);
                }
                else {
                    return _search(current.right);
                }
            }
            return nill;
        }
        auto result=_search(root);
        if (result !is nill) {
            return result;
        }
        return null;
    }

    bool exists(K key) const {
//        const result=search(key);
        return search(key) !is null;
    }

    @property size_t length() const {
        size_t count;
        foreach(m; this[]) {
            count++;
        }
        return count;
    }

    protected Node* tree_minimum(Node *x) {
        while(x.left !is nill) {
            x = x.left;
        }
        return x;
    }

    /*
     * Insertion is done by the same procedure for BST Insert. Except new node is colored
     * RED. As it is coloured RED it may violate property 2 or 4. For this reason an
     * auxilary procedure called insert_fixup is called to fix these violation.
     */

    static if (is(V==void)) {
        void insert(K key) {
            Node* z = create!(Node*);
            z.key=key;
            insert(z);
        }
        const(K) get(const(K) key) const {
            alias _K=const(K);
            auto result=search(key);
            if (result !is null) {
                return result.key;
            }
            return K.init;
        }

    }
    else {
        void insert(K key, V value) {
            Node* z = create!(Node*);
            z.key=key;
            z.value=value;
            insert(z);
        }

        void opIndexAssign(V value, K key) {
            insert(key, value);
        }

        const(V) opIndex(K key) const {
            if (auto result=serach(key) !is nill) {
                return result.value;
            }
            return V.init;
        }
    }

    private void insert(Node* z) {
        Node*  x, y;
        z.color = Color.RED;
        z.left = nill;
        z.right = nill;

        x = root;
        y = nill;

        /*
         * Go through the tree untill a leaf(null) is reached. y is used for keeping
         * track of the last non-null node which will be z's parent.
         */
        while (x !is nill) {
            y = x;
            if (z.key <= x.key) {
                x = x.left;
            }
            else {
                x = x.right;
            }
        }

        if (y is nill) {
            root = z;
        }
        else if (z.key <= y.key) {
            y.left = z;
        }
        else {
            y.right = z;
        }

        z.parent = y;

        insert_fixup(z);
    }

    /*
     * Here is the psudocode for fixing violations.
     *
     * while (z's parent is RED)
     *              if (z's parent is z's grand parent's left child) then
     *                      if (z's right uncle or grand parent's right child is RED) then
     *                              make z's parent and uncle BLACK
     *                              make z's grand parent RED
     *                              make z's grand parent new z as it may violate property 2 & 4
     *                              (so while loop will contineue)
     *
     *                      else(z's right uncle is not RED)
     *                              if (z is z's parents right child) then
     *                                      make z's parent z
     *                                      left rotate z
     *                              make z's parent's color BLACK
     *                              make z's grand parent's color RED
     *                              right rotate z's grand parent
     *                              ( while loop won't pass next iteration as no violation)
     *
     *              else(z's parent is z's grand parent's right child)
     *                      do exact same thing above just swap left with right and vice-varsa
     *
     * At this point only property 2 can be violated so make root BLACK
     */

    protected void insert_fixup(Node *z) {
        while (z.parent.color is Color.RED) {

            /* z's parent is left child of z's grand parent*/
            if (z.parent is z.parent.parent.left) {

                /* z's grand parent's right child is RED */
                if ((z.parent.parent.right !is nill) && (z.parent.parent.right.color is Color.RED)) {
                    z.parent.color = Color.BLACK;
                    z.parent.parent.right.color = Color.BLACK;
                    z.parent.parent.color = Color.RED;
                    z = z.parent.parent;
                }

                /* z's grand parent's right child is not RED */
                else {

                    /* z is z's parent's right child */
                    if (z is z.parent.right) {
                        z = z.parent;
                        left_rotate(z);
                    }

                    z.parent.color = Color.BLACK;
                    z.parent.parent.color = Color.RED;
                    right_rotate(z.parent.parent);
                }
            }

            /* z's parent is z's grand parent's right child */
            else {

                /* z's left uncle or z's grand parent's left child is also RED */
                if (z.parent.parent.left.color is Color.RED) {
                    z.parent.color = Color.BLACK;
                    z.parent.parent.left.color = Color.BLACK;
                    z.parent.parent.color = Color.RED;
                    z = z.parent.parent;
                }

                /* z's left uncle is not RED */
                else {
                    /* z is z's parents left child */
                    if (z is z.parent.left) {
                        z = z.parent;
                        right_rotate(z);
                    }

                    z.parent.color = Color.BLACK;
                    z.parent.parent.color = Color.RED;
                    left_rotate(z.parent.parent);
                }
            }
        }

        root.color = Color.BLACK;
    }

    /*
     * Lets say y is x's right child. Left rotate x by making y, x's parent and x, y's
     * left child. y's left child becomes x's right child.
     *
     *         x                            y
     *        / \                          /  \
     *      STA  y     ----------->       x   STC
     *      / \                          /      \
     *   STB   STC                      STA    STB
     */

    void left_rotate(Node* x) {
        Node* y;

        /* Make y's left child x's right child */
        y = x.right;
        x.right = y.left;
        if (y.left !is nill) {
            y.left.parent = x;
        }

        /* Make x's parent y's parent and y, x's parent's child */
        y.parent = x.parent;
        if (y.parent is nill) {
            root = y;
        }
        else if (x is x.parent.left) {
            x.parent.left = y;
        }
        else {
            x.parent.right = y;
        }

        /* Make x, y's left child & y, x's parent */
        y.left = x;
        x.parent = y;
    }

    /*
     * Lets say y is x's left child. Right rotate x by making x, y's right child and y
     * x's parent. y's right child becomes x's left child.
     *
     *          |                                                |
     *          y
     *         / \                                              / \
     *        y   STA               ---------------->        STB   x
     *       / \                                             / \
     *    STB   STC                                       STC   STA
     */

    protected void right_rotate(Node* x) {
        Node* y;

        /* Make y's right child x's left child */
        y = x.left;
        x.left = y.right;
        if (y.right !is nill) {
            y.right.parent = x;
        }

        /* Make x's parent y's parent and y, x's parent's child */
        y.parent = x.parent;
        if (y.parent is nill) {
            root = y;
        }
        else if (x is x.parent.left) {
            x.parent.left = y;
        }
        else {
            x.parent.right = y;
        }

        /* Make y, x's parent and x, y's child */
        y.right = x;
        x.parent = y;
    }

    /*
     * Deletion is done by the same mechanism as BST deletion. If z has no child, z is
     * removed. If z has single child, z is replaced by its child. Else z is replaced by
     * its successor. If successor is not z's own child, successor is replaced by its
     * own child first. then z is replaced by the successor.
     *
     * A pointer y is used to keep track. In first two case y is z. 3rd case y is z's
     * successor. So in first two case y is removed. In 3rd case y is moved.
     *
     *Another pointer x is used to keep track of the node which replace y.
     *
     * As removing or moving y can harm red-black tree properties a variable
     * yOriginalColor is used to keep track of the original colour. If its BLACK then
     * removing or moving y harm red-black tree properties. In that case an auxilary
     * procedure remove_fixup(x) is called to recover this.
     */

    bool remove(K key) {
        auto remove_node=_search(key);
        if (remove_node !is nill) {
            remove(remove_node);
            return true;
        }
        return false;
    }

    protected void remove(ref Node* z) {
        scope(exit) {
            z.dispose;
        }
        Node* y, x;
        Color yOriginalColor;

        y = z;
        yOriginalColor = y.color;

        if (z.left is nill) {
            x = z.right;
            transplant(z, z.right);
        }
        else if (z.right is nill) {
            x = z.left;
            transplant(z, z.left);
        }
        else {
            y = tree_minimum(z.right);
            yOriginalColor = y.color;

            x = y.right;

            if (y.parent == z) {
                x.parent = y;
            }
            else {
                transplant(y, y.right);
                y.right = z.right;
                y.right.parent = y;
            }

            transplant(z, y);
            y.left = z.left;
            y.left.parent = y;
            y.color = z.color;
        }

        if (yOriginalColor is Color.BLACK) {
            remove_fixup(x);
        }
    }

    /*
     * As y was black and removed x gains y's extra blackness.
     * Move the extra blackness of x until
     *              1. x becomes root. In that case just remove extra blackness
     *              2. x becomes a RED and BLACK node. in that case just make x BLACK
     *
     * First check if x is x's parents left or right child. Say x is left child
     *
     * There are 4 cases.
     *
     * Case 1: x's sibling w is red. transform case 1 into case 2 by recoloring
     * w and x's parent. Then left rotate x's parent.
     *
     * Case 2: x's sibling w is black, w's both children is black. Move x and w's
     * blackness to x's parent by coloring w to RED and x's parent to BLACK.
     * Make x's parent new x.Notice if case 2 come through case 1 x's parent becomes
     * RED and BLACK as it became RED in case 1. So loop will stop in next iteration.
     *
     * Case 3: w is black, w's left child is red and right child is black. Transform
     * case 3 into case 4 by recoloring w and w's left child, then right rotate w.
     *
     * Case 4: w is black, w's right child is red. recolor w with x's parent's color.
     * make x's parent BLACK, w's right child black. Now left rotate x's parent. Make x
     * point to root. So loop will be stopped in next iteration.
     *
     * If x is right child of it's parent do exact same thing swapping left<->right
     */

    protected void remove_fixup(Node *x) {
        Node *w;

        while (x !is root && x.color is Color.BLACK) {
            if (x is x.parent.left) {
                w = x.parent.right;

                if (w.color is Color.RED) {
                    w.color = Color.BLACK;
                    x.parent.color = Color.RED;
                    left_rotate(x.parent);
                    w = x.parent.right;
                }

                if (w.left.color is Color.BLACK && w.right.color is Color.BLACK) {
                    w.color = Color.RED;
                    x.parent.color = Color.BLACK;
                    x = x.parent;
                }
                else {

                    if (w.right.color is Color.BLACK) {
                        w.color = Color.RED;
                        w.left.color = Color.BLACK;
                        right_rotate(w);
                        w = x.parent.right;
                    }

                    w.color = x.parent.color;
                    x.parent.color = Color.BLACK;
                    x.right.color = Color.BLACK;
                    left_rotate(x.parent);
                    x = root;

                }

            }
            else {
                w = x.parent.left;

                if (w.color is Color.RED) {
                    w.color = Color.BLACK;
                    x.parent.color = Color.BLACK;
                    right_rotate(x.parent);
                    w = x.parent.left;
                }

                if (w.left.color is Color.BLACK && w.right.color is Color.BLACK) {
                    w.color = Color.RED;
                    x.parent.color = Color.BLACK;
                    x = x.parent;
                }
                else {

                    if (w.left.color is Color.BLACK) {
                        w.color = Color.RED;
                        w.right.color = Color.BLACK;
                        left_rotate(w);
                        w = x.parent.left;
                    }

                    w.color = x.parent.color;
                    x.parent.color = Color.BLACK;
                    w.left.color = Color.BLACK;
                    right_rotate(x.parent);
                    x = root;

                }
            }

        }

        x.color = Color.BLACK;
    }

    /* replace node u with node v */
    protected void transplant(Node* u, Node* v) {
        if (u.parent is nill) {
            root = v;
        }
        else if (u is u.parent.left) {
            u.parent.left = v;
        }
        else {
            u.parent.right = v;
        }

        v.parent = u.parent;
    }

    Range opSlice() const {
        // In betterC the descructor of RBTree is call if the argument is passed to the Range struct
        // This is the reason why the pointer to RBTree is used
        auto range=Range(&this);
        return range;
    }

    struct Range {
        import std.traits;
//        int level;
        private {
            Node* nill;
            Node* current;
            Node* walker;
            Stack!(Node*) stack;
        }

        this(const(RBTree*) owner)  {
            this.nill=cast(Node*)(owner.nill);
            walker=current=cast(Node*)(owner.root);
            popFront;
        }

        ~this() {
            dispose;
        }

        void dispose() {
            stack.dispose;
            nill=walker=current=null;
        }

        private void push(Node* node) {
            stack.push(node);
        }
        private Node* pop() {
            if (stack.empty) {
                return nill;
            }
            return stack.pop;
        }

        @property bool empty() const pure {
            return (current is nill);
        }

        @property const(Node*) front() const pure {
            if (current is nill) {
                return null;
            }
            return current;
        }

        void popFront() {
            while (walker !is nill) {
                push(walker);
                walker=walker.left;
            }

            if (!stack.empty) {
                walker=current=pop;
                walker=walker.right;
            }
            else {
                current=nill;
            }
        }
    }

    version(none)
    void inOrder(scope ref Stack queue) const {
        void _inorder(const(Node*) current) {
            if (current is nill) {
                _inorder(current.right);
                queue.push(current.key);
                _inorder(current.left);
            }
        }
        _inorder(root);

    }
}

unittest {
    auto tree=RBTree!int(false);

    enum tcase=[ 60, 140, 20, 130, 30, 160, 110, 170, 40, 120, 50, 70, 100, 10, 150, 80, 90];
    const(int[17]) result=[ 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170];

    assert(tcase.length == result.length);

    foreach(key; tcase) {
        tree.insert(key);
    }


    // Check that all the elements has been added
    uint count;
    foreach(n; tree[]) {
        const key=result[count++];
        assert(n.key == key);
    }

    // Check the size of the check lists
    assert(tcase.length == count);

    enum indices=[5,3, 14, 0, tcase.length-1];

    // Check exists
    foreach(i; indices) {
        const key=result[i];
        assert(tree.exists(key));
    }

    // Check search
    foreach(i; indices) {
        const key=result[i];
        const n=tree.search(key);
        assert(n !is null);
        assert(key == n.key);
    }

    // Check remove
    foreach(i; indices) {
        const key=result[i];
        const n_exists=tree.search(key);
        assert(n_exists !is null);
        tree.remove(key);
        assert(!tree.exists(key));
        const n=tree.search(key);
        assert(n is null);
        count--;
        assert(tree.length == count);
    }
}
