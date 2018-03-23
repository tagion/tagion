module bakery.crypto.MerkleTree;

import bakery.crypto.Hash;
import std.exception : assumeUnique;
import tango.core.Traits;

/**
 * MerkleTree is an implementation of a Merkle binary hash tree where the leaves
 * are signatures (hashes, digests, CRCs, etc.) of some underlying data structure
 * that is not explicitly part of the tree.
 *
 * The internal leaves of the tree are signatures of its two child nodes. If an
 * internal node has only one child, the the signature of the child node is
 * adopted ("promoted").
 *
 * MerkleTree knows how to serialize itself to a binary format, but does not
 * implement the Java Serializer interface.  The {@link #serialize()} method
 * returns a byte array, which should be passed to
 * {@link MerkleDeserializer#deserialize(byte[])} in order to hydrate into
 * a MerkleTree in memory.
 *
 * This MerkleTree is intentionally ignorant of the hashing/checksum algorithm
 * used to generate the leaf signatures. It uses Adler32 CRC to generate
 * signatures for all internal node signatures (other than those "promoted"
 * that have only one child).
 *
 * The Adler32 CRC is not cryptographically secure, so this implementation
 * should NOT be used in scenarios where the data is being received from
 * an untrusted source.
 */

@safe
interface MerkleTable(H) {
    static assert(is(H : Hash), "The hash object H must implement the Hash interface");
    @property
    final size_t length() const pure nothrow {
        return cast(size_t)this.size;
    }
    @property
    uint size() const pure nothrow;
    immutable(H) opIndex(const uint index) const;
}

@trusted
immutable(ubyte)[] buffer(string str) pure nothrow {
    ubyte* buf=cast(ubyte*)str.ptr;
    return cast(immutable)(buf[0..str.length]);
}
/**
   @param H is the hash function object
   @param D is data object
 */
@safe
public class MerkleTree(H,D=string) {
    static assert(is(H : Hash), "The hash object H must implement the Hash interface");
//    alias immutable(Node)[] Nodes;
    enum int MAGIC_HDR = 0xcdaace99;
    /*
      enum int INT_BYTES = 4;
      enum int LONG_BYTES = 8;

      enum byte LEAF_SIG_TYPE = 0x0;
      enum byte INTERNAL_SIG_TYPE = 0x01;
    */

    //private final Adler32 crc = new Adler32();
    //   private const(D)  leafSigs;
//    private immutable(Node) root;
    private immutable(Node)[][] parents;
//    private immutable(H)[][] famelitree;
//    private int depth;
//    private int nnodes;

    /**
     * Use this constructor to create a MerkleTree from a list of leaf signatures.
     * The Merkle tree is built from the bottom up.
     * @param leafSignatures
     */
    this(const(D)[] leafs) {
        buildTree(parents, leafs);
//        leafSigs = leafSignatures;
//        counted_nodes = cast(uint)leafs.length;
//        parents ~= bottomLevel(leafs);
//        counted_nodes += parents.length;
//        counted_depth = 1;

//        foreach(i;0..parents.length) {
//        while (parents.length > 1) {
//            parents ~= internalLevel(parents[i-1]);
//            counted_depth++;
//            counted_nodes += parents.length;
    }

    uint depth() const pure nothrow {
        return cast(uint)parents.length;
    }

    uint nnodes() const pure nothrow {
        uint result;
        foreach(p; parents) {
            result+=cast(uint)p.length;
        }
        return result;
    }

    immutable(Node) root() const pure nothrow {
        return parents[$-1][0];
    }

    Iterator search(MerkleTree!(H) B) {
        return Iterator(this, B);
    }


    struct Iterator {
        alias bool delegate(immutable(Node) a, immutable(Node) b) @safe pure nothrow searchDg;
        private MerkleTree!(H) A, B;
        this(MerkleTree!(H) A, MerkleTree!(H) B) {
            this.A=A;
            this.B=B;
        }
        bool search(scope searchDg dg) {
            bool stop=false;
            void local_search(immutable(Node) a, immutable(Node) b) @safe {
                if ( stop ) {
                    return;
                }
                if ( ( a is null) || ( b is null ) ) {
                    if ( a is null ) {
                        local_search(a,b.left);
                        stop = dg(a, b);
                        local_search(a,b.right);

                    }
                    else if ( b is null ) {
                        local_search(a.left, b);
                        stop = dg(a, b);
                        local_search(a.right, b);
                    }
                }
                if ( !a.signature.isEqual(b.signature) ) {
                    local_search(a.left, b.left);
                    stop = dg(a, b);
                    local_search(a.right, b.right);
                }
            }
            local_search(A.root, B.root);
            return stop;
        }
    }
    /**
       The function validates the merkel tree.
       I only validate the tree not the hash of the item array.

     */
    bool validate() const  {
        bool result;
        void local_validate(const(Node) node)  {
            if ( result ) {
                if ( node !is null ) {
                    if ( node.signature.isEqual(Node.cHash(node.left, node.right)) ) {
                        result = false;
                        return;
                    }
                }
            }
        }
        local_validate(root);
        return result;
    }
    /**
       This function validates of the leaf of the MerkleTree mach the item list
       The delegate function is call when the leaf node does not match
    */
bool validateSignatures(
        const(D)[] leafs,
        scope bool delegate(const(Node) node, const(uint) index) @safe pure dg) const  {
        bool result=true;
        uint index=0;
        void local_validate(const(Node) node) @safe   {
            if ( result ) {
                if ( node !is null ) {
                    if ( node.type == Node.sigType.leaf ) {
                        if (
                            ( index >= leafs.length ) ||
                            ( !node.signature.isEqual(H(leafs[index])) ) ) {
                            result = dg(node, index);
                        }
                        else {
                            index++;
                        }
                    }
                    else {
                        local_validate(node.left);
                        local_validate(node.right);
                    }
                }
            }
        }
        local_validate(root);
        return result;
    }
  /**
   * Serialization format:
   * (magicheader:uint)(numnodes:uint)[(nodetype:byte)(siglength:uint)(signature:[]byte)]
   * @return
   */
    version(none)
    @trusted
    immutable(ubyte)[] serialize() {
        void serializeTree(immutable(Node) tree, ubyte[] buffer, immutable(uint) level) {
            if ( tree !is null ) {
                buffer[0..Node.payload_size] = tree.payload;
                buffer=buffer[Node.payload_size*(1 << level)..$];
                serializeTree(tree.left, buffer, level+1);
                serializeTree(tree.right, buffer[Node.payload_size..$], level+1);
            }
        }
        ubyte[] result;
        ubyte[] buffer;
        immutable uint num_of_nodes=root.number_of_elements;

        enum {
            magicHeaderSz = MAGIC_HDR.sizeof,
            nnodesSz = num_of_nodes.sizeof,
//            siglengthSz = siglength.sizeof,
            hdrSz = magicHeaderSz + nnodesSz // + siglengthSz,
        };
        result = new ubyte[hdrSz + num_of_nodes * Node.payload_size];
        // buffer points into result
        buffer = result;
        /** buffer append function */
        void append(T)(T item) {
            static assert(isAtomicType!(BaseTypeOf!(T)), "Only atomic type supported");
            static if ( is(BaseTypeOf!(T) == T) ) {
                ubyte* item_p = cast(ubyte*)&item;
            }
            else {
                T x=item;
                ubyte* item_p = cast(ubyte*)&x;
            }
            buffer[0..item.sizeof]=item_p[0..item.sizeof];
            buffer=buffer[item.sizeof..$];
        }
        append(MAGIC_HDR);
        append(num_of_nodes);
        append(Node.payload_size);
        // And the whole thee
        serializeTree(root, buffer, 0);
        //

        return assumeUnique(result);
    }


/**
   * Serialization format after the header section:
   * [(nodetype:byte)(siglength:int)(signature:[]byte)]
   * @param buf
   */
    /*
  void serializeBreadthFirst(ByteBuffer buf) {
      Queue<Node> q = new ArrayDeque<Node>((nnodes / 2) + 1);
      q.add(root);

    while (!q.isEmpty()) {
      Node nd = q.remove();
      buf.put(nd.type).putInt(nd.sig.length).put(nd.sig);

      if (nd.left != null) {
        q.add(nd.left);
      }
      if (nd.right != null) {
        q.add(nd.right);
      }
    }
  }
    */
  /**
   * Create a tree from the bottom up starting from the leaf signatures.
   * @param signatures
   */
    version(node)
    private immutable(Node) constructTree(MerkleTable!(H) signatures)
    in {
          assert(signatures.size() > 1, "Must be at least two signatures to construct a Merkle tree");
      }
body
    {
        leafSigs = signatures;
        nnodes = signatures.size();
        auto  parents = bottomLevel(signatures);
        nnodes += cast(uint)parents.length;
        depth = 1;

        while (parents.length > 1) {
            parents = internalLevel(parents);
            depth++;
            nnodes += cast(uint)parents.length;
        }

        return parents[0];
    }

/*
    public int getNumNodes() {
        return nnodes;
    }

    public Node getRoot() {
        return root;
    }

    public int getHeight() {
        return depth;
    }
*/
    /*
    @trusted
    private immutable(Node) createNode(immutable(Node) node1, immutable(Node) node2) const pure {
        auto result=new const(Node)(node1, node2);
        return cast(immutable)(result);
    }
    @trusted
    private immutable(Node) createNode(immutable(Node) node) const pure {
        immutable(Node) right_null = null;
        auto result=new const(Node)(node, right_null);
        return cast(immutable)(result);
    }
    */
    static void buildTree(ref immutable(Node)[][] parents, const(D)[] leafs)
        in {
            assert(leafs.length > 1, "Must be at least two signatures to construct a Merkle tree");
        }
    out {
        assert(parents.length == node_size(leafs.length));
    }
    body {
        /**
         * Constructs an internal level of the tree
         */
        void internalLevel(ref Node[] p, immutable(Node)[] children) {
            uint j;
            immutable width=parent_width(cast(uint)children.length);
            parents~=immune(p[0..width]);
            for (uint i = 0; i < children.length - 1; i += 2) {
                auto parent = new Node(children[i], children[i+1]);
                p[j++]=parent;
            }

            if (children.length % 2 != 0) {
                immutable Node right_null = null;
                auto parent = new Node(children[$-1], right_null);
                p[j++]=parent;
            }
            p=p[j..$];
        }


        /**
         * Constructs the bottom part of the tree - the leaf nodes and their
         * immediate parents.  Returns a list of the parent nodes.
         */
        void bottomLevel(ref Node[] p, const(D)[] leafs) {
            uint i;
            immutable width=parent_width(cast(uint)leafs.length);
            parents~=immune(p[0..width]);
            foreach(l;leafs) {
                p[i++] = new Node(H(l.buffer));
            }
            p=p[i..$];
        }
        Node[] nodes=new Node[node_size(leafs.length)];
        Node[] p=nodes;
        bottomLevel(p, leafs);
        while (p.length > 1) {
            internalLevel(p, parents[$-1]);
        }
    }

    @trusted
    static private immutable(T)[] immune(T)(const(T)[] table) pure nothrow {
        return assumeUnique(table);
    }

//    private immutable(Node) createNode();
    /*
    private Node constructInternalNode(const(Node) child1, const(Node) child2) {
        Node parent = new Node();
        parent.type = Node.Si;

        if (child2 is null) {
            parent.sig = child1.sig;
        } else {
            parent.sig = internalHash(child1.sig, child2.sig);
        }

        parent.left = child1;
        parent.right = child2;
        return parent;
    }
    */
    /*
    private static Node constructLeafNode(String signature) {
        Node leaf = new Node(Node.sigType.leaf, signature);
        // leaf.type = LEAF_SIG_TYPE;
        // leaf.sig = signature.getBytes(StandardCharsets.UTF_8);
        return leaf;
    }
    */
/*
    immutable(HashT) internalHash(const(HashT) leftChildSig, const(HashT) rightChildSig) const pure nothrow {
        return H(leftChildSig,
        buffer ~= leftChilSig;
        buffer ~= rightChilSig;

    crc.reset();
    crc.update(leftChildSig);
    crc.update(rightChildSig);
    return longToByteArray(crc.getValue());
*/
    //}

    unittest {
        //
        // Merkle tree test
        //
        size_t tree_span(const(size_t) n) const {
            return (n/2)+(n & 1);
        }
        //
        // Item table
        //
        string[] table=[
            "A",
            "BB",
            "CCC",
            "EEEE",
            "FFFFF"
            ];
        //
        // Leaf hashs
        //
        const(H)[] leaf_hash;
        foreach(i;0..table.length) {
            leaf_hash~=H(table[i]);
        }
        // Lowest merkle level
        const(H)[] level2;
        foreach(i;0..leaf_hash.length/2) {
            level2~=H(leaf_hash[2*i], leaf_hash[2*i+1]);
        }
        if ( leaf_hash.length % 1 ) {
            level2~=leaf_hash[$-1];
        }
        assert(level2.length == tree_span(leaf_hash.length));

        const(H)[] level1;
        foreach(i;0..level2.length/2) {
            level1~=H(level2[2*i], level2[2*i+1]);
        }
        if ( level2.length % 1 ) {
            level1~=level2[$-1];
        }
        assert(level1.length == tree_span(level2.length));

        const(H)[] level0;
        foreach(i;0..level1.length/2) {
            level0~=H(level1[2*i], level1[2*i+1]);
        }
        if ( level1.length % 1 ) {
            level0~=level1[$-1];
        }
        assert(level0.length == tree_span(level1.length));
        assert(level0.length == 2);

        auto mt=new MerkleTree!H(table);
//        auto root=

    }

    static uint parent_width(uint child_width) pure nothrow {
        return (child_width/2)+(child_width % 2);
    }

    static uint node_size(size_t leaf_width) pure nothrow {
        uint local_size(uint width) {
            if ( width > 0 ) {
                return width+local_size(parent_width(width));

            }
            return 0;
        }
        return local_size(cast(uint)leaf_width);
    }
  /* ---[ Node class ]--- */

  /**
   * The Node class should be treated as immutable, though immutable
   * is not enforced in the current design.
   *
   * A Node knows whether it is an internal or leaf node and its signature.
   *
   * Internal Nodes will have at least one child (always on the left).
   * Leaf Nodes will have no children (left = right = null).
   */
    static class Node {
        enum sigType : ubyte {
            // Type of the Node
            internal,
                leaf
                };
        static immutable payload_size = sigType.sizeof + H.buffer_size;
        this(immutable(Node) child1, immutable(Node) child2)
            in {
                assert(child1 !is null);
            }
        body {
            this.type = sigType.internal;
            if ( child2 is null ) {
                this.signature = child1.signature;
            }
            else {
                this.signature = H(child1.signature, child2.signature);
            }
            this.left = child1;
            this.right = child2;
        }
        this(immutable(H) signature) {
            type = sigType.leaf;
            this.signature = signature;
            left = null;
            right = null;
        }
        this(const(ubyte)[] buffer) {
            type = sigType.leaf;
            this.signature = H(buffer);
            left = null;
            right = null;
        }
        /*
        static immutable(Node) opCall(immutable(ubyte)[] buffer) {
            auto result=new Node(buffer);
            return result;
        }
        static const(Node) opCall(immutable(H) signature) {
            auto result=new MerkleTree.Node(signature);
            return result;
        }
        @trusted
        static immutable(Node) opCall(ref immutable(Node) child1, ref immutable(Node) child2) {
            auto result=new Node(child1, child2);
            return cast(immutable(Node))(result);
        }
        */
        immutable(ubyte)[] payload() const pure nothrow {
            immutable(ubyte)[] buffer;
            ubyte type_b=type;
            buffer~=type_b;
            buffer~=signature.signed;
            return buffer;
        }
        uint number_of_elements() const pure nothrow {
            uint count = 0;
            void local_count(const(Node) node) pure nothrow {
                if ( node !is null ) {
                    count++;
                    local_count(node.left);
                    local_count(node.right);
                }
            }
            local_count(this);
            return count;
        }
        static immutable(H) cHash(const(Node) A, const(Node) B)
            in {
                assert(A !is null);
            }
        body {
            if ( B is null ) {
                return A.signature;
            }
            else {
                return H(A.signature, B.signature);

            }
        }
      /*
      @Override
      public String toString() {
          String leftType = "<null>";
          String rightType = "<null>";
          if (left != null) {
              leftType = String.valueOf(left.type);
          }
          if (right != null) {
              rightType = String.valueOf(right.type);
          }
          return String.format("MerkleTree.Node<type:%d, sig:%s, left (type): %s, right (type): %s>",
              type, sigAsString(), leftType, rightType);
      }

      private String sigAsString() {
          StringBuffer sb = new StringBuffer();
          sb.append('[');
          for (int i = 0; i < sig.length; i++) {
              sb.append(sig[i]).append(' ');
          }
          sb.insert(sb.length()-1, ']');
          return sb.toString();
      }
      */
  private:
        immutable(sigType) type;
        immutable(H) signature; // signature of the node
        immutable(Node) left;
        immutable(Node) right;
  }

  /**
   * Big-endian conversion
   */
/*
  public static byte[] longToByteArray(long value) {
    return new byte[] {
        (byte) (value >> 56),
        (byte) (value >> 48),
        (byte) (value >> 40),
        (byte) (value >> 32),
        (byte) (value >> 24),
        (byte) (value >> 16),
        (byte) (value >> 8),
        (byte) value
    };
  }
*/
}
