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
    immutable(H) opIndex(const uint index) const pure;
}

@safe
public class MerkleTree(H) {
    static assert(is(H : Hash), "The hash object H must implement the Hash interface");
    alias immutable(Node)[] Nodes;
    enum int MAGIC_HDR = 0xcdaace99;
    /*
      enum int INT_BYTES = 4;
      enum int LONG_BYTES = 8;

      enum byte LEAF_SIG_TYPE = 0x0;
      enum byte INTERNAL_SIG_TYPE = 0x01;
    */

    //private final Adler32 crc = new Adler32();
    private const MerkleTable!(H) leafSigs;
    private immutable(Node) root;
    private int depth;
    private int nnodes;

    /**
     * Use this constructor to create a MerkleTree from a list of leaf signatures.
     * The Merkle tree is built from the bottom up.
     * @param leafSignatures
     */
    this(immutable MerkleTable!(H)  leafSignatures) immutable
    in {
        assert(leafSignatures.size() > 1, "Must be at least two signatures to construct a Merkle tree");
    }
    body
    {
        uint counted_nodes;
        uint counted_depth;
        leafSigs = leafSignatures;
        counted_nodes = leafSignatures.size();
        Nodes  parents = bottomLevel(leafSignatures);
        counted_nodes += parents.length;
        counted_depth = 1;

        while (parents.length > 1) {
            parents ~= internalLevel(parents);
            counted_depth++;
            counted_nodes += parents.length;
        }
        nnodes = counted_nodes;
        depth = counted_depth;
        root = parents[0];
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
    bool validate() const pure {
        bool result;
        void local_validate(const(Node) node) pure {
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
        scope bool delegate(const(Node) node, const(uint) index) @safe pure dg) const pure {
        bool result=true;
        uint index=0;
        void local_validate(const(Node) node) @safe pure  {
            if ( result ) {
                if ( node !is null ) {
                    if ( node.type == Node.sigType.leaf ) {
                        if ( (index >= leafSigs.length) || ( !node.signature.isEqual(leafSigs[index]) ) ) {
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
  /**
   * Constructs an internal level of the tree
   */
    protected Nodes internalLevel(Nodes children) immutable {
      Nodes parents;
      for (uint i = 0; i < children.length - 1; i += 2) {
          auto parent = new immutable(Node)(children[i], children[i+1]);
          parents~=parent;
      }

      if (children.length % 2 != 0) {
          immutable Node right_null = null;
          auto parent = new immutable(Node)(children[$-1], right_null);
          parents~=parent;
      }
      return assumeUnique(parents);
  }


  /**
   * Constructs the bottom part of the tree - the leaf nodes and their
   * immediate parents.  Returns a list of the parent nodes.
   */
    Nodes bottomLevel(immutable(MerkleTable!(H)) signatures) immutable {
        Nodes parents;
//        auto parents = new const(Node)[signatures.size/2];

//            List<Node> parents = new ArrayList<Node>(signatures.size() / 2);
        for(uint i=0; i < signatures.size - 1; i += 2) {
            auto parent = new immutable(Node)(H(signatures[i], signatures[i+1]));
            parents~=parent;
        }

        // if odd number of leafs, handle last entry
        if (signatures.size % 2 != 0) {
            auto parent = new immutable(Node)(signatures[signatures.size-1]);
            parents~=parent;
        }

        return parents;
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
    class Node {
        enum sigType : ubyte {
            // Type of the Node
            internal,
                leaf
                };
        static immutable payload_size = sigType.sizeof + H.buffer_size;
        this(immutable(Node) child1, immutable(Node) child2) immutable
            in {
                assert(child1 !is null);
            }
        body {
            this.type = sigType.internal;
            if ( child2 is null ) {
                this.signature = child2.signature;
            }
            else {
                this.signature = H(child1.signature, child2.signature);
            }
            this.left = child1;
            this.right = child2;
        }
        this(immutable(H) signature) immutable {
            type = sigType.leaf;
            this.signature = signature;
            left = null;
            right = null;
        }
        this(immutable(ubyte)[] buffer) immutable {
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
        static immutable(H) cHash(const(Node) A, const(Node) B) pure
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
