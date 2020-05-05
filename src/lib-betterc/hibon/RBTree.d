module hibon.RBTree;

/** C++ implementation for Red-Black Tree Insertion
This code is adopted from the code provided by
Dinesh Khandelwal in comments **/
//#include <bits/stdc++.h>
//using namespace std;
extern(C):
import hibon.Memory;
import hibon.Queue;
import core.stdc.stdio;

// Class to represent Red-Black Tree
struct RBTree(K, V=void) {
    enum Color {RED, BLACK};

    struct Node {
        K data;
        bool color;
        Node* left, right, parent;
        static if (!is(V == void)) {
            V value;
        }
        // Constructor
        this(K data) {
            this.data = data;
            left = right = parent = null;
            this.color = Color.RED;
        }
        private void clean() {
            static if (is(V == void)) {
                static if (__traits(compiles, value.dispose)) {
                    value.dispose;
                }
            }
            static if (__traits(compiles, data.dispose)) {
                data.dispose;
            }
        }
    }

    protected Node* root;
    // Constructor
    ~this() {
        dispose;
    }

    void dispose() {
        void _dispose(Node* current) {
            if (current is null) {
                _dispose(current.left);
                _dispose(current.right);
                current.clean;
                current.dispose;
            }
        }
        _dispose(root);
        root=null;
    }

    // void insert(const int &n);
    // void inorder();
    // void levelOrder();


// A recursive function to do level order traversal
    void inorderHelper(Node* root) {
	if (root is null) {
            return;
        }

	inorderHelper(root.left);
        printf("%d ", root.data);
//	cout << root.data << " ";
	inorderHelper(root.right);
    }

/* A utility function to insert a new node with given key
in BST */
    static Node* BSTInsert(Node* root, Node *pt) {
	/* If the tree is empty, return a new node */
	if (root is null) {
            return pt;
        }

	/* Otherwise, recur down the tree */
	if (pt.data < root.data) {
            root.left = BSTInsert(root.left, pt);
            root.left.parent = root;
	}
	else if (pt.data > root.data) {
            root.right = BSTInsert(root.right, pt);
            root.right.parent = root;
	}

	/* return the (unchanged) node pointer */
	return root;
    }

// Utility function to do level order traversal
    static void levelOrderHelper(Node* root) {
	if (root is null) {
            return;
        }

        Queue!(Node*) q;
	q.push(root);

	while (!q.empty()) {
            auto temp = q.front();
            printf("%d ", temp.data);
            q.popFront;

            if (temp.left !is null) {
                q.push(temp.left);
            }
            if (temp.right !is null) {
                q.push(temp.right);
            }
	}
    }

    protected void rotateLeft(ref Node* root, ref Node* pt) {
	Node* pt_right = pt.right;

	pt.right = pt_right.left;

	if (pt.right !is null) {
            pt.right.parent = pt;
        }

	pt_right.parent = pt.parent;

	if (pt.parent is null) {
            root = pt_right;
        }
	else if (pt is pt.parent.left) {
            pt.parent.left = pt_right;
        }
	else {
            pt.parent.right = pt_right;
        }
	pt_right.left = pt;
	pt.parent = pt_right;
    }

    protected void rotateRight(ref Node* root, Node* pt) {
	Node* pt_left = pt.left;

	pt.left = pt_left.right;

	if (pt.left != NULL)
		pt.left.parent = pt;

	pt_left.parent = pt.parent;

	if (pt.parent == NULL)
		root = pt_left;

	else if (pt == pt.parent.left)
		pt.parent.left = pt_left;

	else
		pt.parent.right = pt_left;

	pt_left.right = pt;
	pt.parent = pt_left;
    }

// This function fixes violations caused by BST insertion
    protected void fixViolation(ref Node* root, ref Node* pt) {
	Node* parent_pt = null;
	Node* grand_parent_pt = null;

	while ((pt !is root) && (pt.color !is Color.BLACK) &&
            (pt.parent.color is Color.RED)) {
            parent_pt = pt.parent;
            grand_parent_pt = pt.parent.parent;

            /* Case : A
               Parent of pt is left child of Grand-parent of pt */
            if (parent_pt is grand_parent_pt.left) {
                Node* uncle_pt = grand_parent_pt.right;

                /* Case : 1
                   The uncle of pt is also red
                   Only Recoloring required */
                if (uncle_pt !is null && uncle_pt.color is Color.RED) {
                    grand_parent_pt.color = Color.RED;
                    parent_pt.color = Color.BLACK;
                    uncle_pt.color = Color.BLACK;
                    pt = grand_parent_pt;
                }
                else {
                    /* Case : 2
                       pt is right child of its parent
                       Left-rotation required */
                    if (pt is parent_pt.right) {
                        rotateLeft(root, parent_pt);
                        pt = parent_pt;
                        parent_pt = pt.parent;
                    }

                    /* Case : 3
                       pt is left child of its parent
                       Right-rotation required */
                    rotateRight(root, grand_parent_pt);
                    swap(parent_pt.color, grand_parent_pt.color);
                    pt = parent_pt;
                }
            }

            /* Case : B
               Parent of pt is right child of Grand-parent of pt */
            else {
                Node* uncle_pt = grand_parent_pt.left;

                /* Case : 1
                   The uncle of pt is also red
                   Only Recoloring required */
                if ((uncle_pt !is null) && (uncle_pt.color is Color.RED)) {
                    grand_parent_pt.color = Color.RED;
                    parent_pt.color = Color.BLACK;
                    uncle_pt.color = Color.BLACK;
                    pt = grand_parent_pt;
                }
                else {
                    /* Case : 2
                       pt is left child of its parent
                       Right-rotation required */
                    if (pt is parent_pt.left) {
                        rotateRight(root, parent_pt);
                        pt = parent_pt;
                        parent_pt = pt.parent;
                    }

                    /* Case : 3
                       pt is right child of its parent
                       Left-rotation required */
                    rotateLeft(root, grand_parent_pt);
                    swap(parent_pt.color, grand_parent_pt.color);
                    pt = parent_pt;
                }
            }
	}
	root.color = Color.BLACK;
    }


// Function to insert a new node with given data
    void insert(ref const K data) {
        Node* pt = create!Node(data);
	// Do a normal BST insert
	root = BSTInsert(root, pt);
	// fix Red Black Tree violations
	fixViolation(root, pt);
    }

// Function to do inorder and level order traversals
    void inorder() {
        inorderHelper(root);
    }
    void levelOrder() {
        levelOrderHelper(root);
    }
}
// Driver Code
unittest {
    RBTree!int tree;

    tree.insert(7);
    tree.insert(6);
    tree.insert(5);
    tree.insert(4);
    tree.insert(3);
    tree.insert(2);
    tree.insert(1);

    printf("Inoder Traversal of Created Tree\n");
    tree.inorder();

    printf("\n\nLevel Order Traversal of Created Tree\n");
    tree.levelOrder();
}
