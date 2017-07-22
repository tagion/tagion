module Bakery.Crypto.MerkleTree;

import Bakery.Crypto.Hash;
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
interface SignatureArray(H : Hash) {
    @property
    final size_t length() const pure nothrow {
        return cast(size_t)this.size;
    }
    @property
    unit size() const pure nothrow;
    immutable(H) opIndex(const uint index) const pure nothrow;
}

@safe
public class MerkleTree(H : Hash) {

    alias immutable(immutable(Node))[] Nodes;
    enum int MAGIC_HDR = 0xcdaace99;
    /*
      enum int INT_BYTES = 4;
      enum int LONG_BYTES = 8;

      enum byte LEAF_SIG_TYPE = 0x0;
      enum byte INTERNAL_SIG_TYPE = 0x01;
    */

    private final Adler32 crc = new Adler32();
    private SignatureArray!(H) leafSigs;
    private Node root;
    private int depth;
    private int nnodes;

    /**
     * Use this constructor to create a MerkleTree from a list of leaf signatures.
     * The Merkle tree is built from the bottom up.
     * @param leafSignatures
     */
    this(SignatureArray!(H)  leafSignatures)
    in {
        assert(signatures.size() > 1, "Must be at least two signatures to construct a Merkle tree");
    }
    body
    {
        leafSigs = signatures;
        nnodes = signatures.size();
        auto  parents = bottomLevel(signatures);
        nnodes += parents.size();
        depth = 1;

        while (parents.size() > 1) {
            parents = internalLevel(parents);
            depth++;
            nnodes += parents.size();
        }
        root = parents[0];
    }

    Iterator search(MerkleTree!(H) B) {
        return Iterator(this, B);
    }

    struct Iterator {
        private MerkleTree!(H) A, B;
        private MerkleTree!(H) B;
        this(MerkleTree!(H) A, B) {
            this.A=A;
            this.B=B;
        }
        bool search(scope bool delegate(
                immutable(Node) a,
                immutable(Node) b) dg) {
            void local_search(immutable(Node) a, immutable(Node) b) {
                if ( stop ) {
                    return
                }
                if ( ( a is null) || ( b is null ) ) {
                    if ( a is null ) {
                        local_search(a,b.left);
                        stop = dg(a, b);
                        local_search(a,b.right);

                    }
                    else if ( b is null ) {
                        local_search(a.left, ,b);
                        stop = dg(a, b);
                        local_search(a.right, b);
                    }
                }
                if ( a.signature != b.signature ) {
                    local_search(a.left, b.left);
                    stop = dg(a, b);
                    local_search(a.right, b.right);
                }
            }
            bool stop=false;
            local_search(a.root, b.root);
            return stop;
        }
    }
    /**
       The function validates the merkel tree.
       I only validate the tree not the hash of the item array.

     */
    bool validate() const pure nothrow {
        void local_validate(const(Node) node) {
            if ( result ) {
                if ( node !is null ) {
                    if ( node.signature != Node.cHash(node.left, node.right) ) {
                        result = false;
                        return;
                    }
                }
            }
        }
        bool result;
        local_validate(root);
        return result;
    }
    /**
       This function validates of the leaf of the MerkleTree mach the item list
       The delegate function is call when the leaf node does not match
     */
    bool validateSignatures(scope bool delegate(const(Node) node, const(uint) index) dg) const pure nothrow {
        void local_validate(const(Node) node) {
            if ( result ) {
                if ( node !is null ) {
                    if ( node.type == Node.sigType.Leaf ) {
                        if ( (index => leafSigs.length) || ( node.signature != leafSigs[index].signature ) ) {
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
            uint index=0;
            bool result=true;
            local_validate(root);
            return result;
        }
    }
  /**
   * Serialization format:
   * (magicheader:uint)(numnodes:uint)[(nodetype:byte)(siglength:uint)(signature:[]byte)]
   * @return
   */
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
        const uint num_of_nodes=tree.number_of_elements;

        enum {
            magicHeaderSz = MAGIC_HDR.sizeof,
            nnodesSz = num_of_nodes.sizeof,
            siglength = siglength.sizeof,
            hdrSz = magicHeaderSz + nnodesSz + siglength,
        };
        result = new ubyte[hdrSz + num_of_nodes * Node.payload_size];
        // buffer points into result
        buffer = result;
        /** buffer append function */
        void append(T)(T item) {
            buffer[0..item.sizeof]=cast(ubyte[])item;
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

  /**
   * Create a tree from the bottom up starting from the leaf signatures.
   * @param signatures
   */
    private immutable(Node) constructTree(SignatureArray signatures)
      in {
          assert(signatures.size() > 1, "Must be at least two signatures to construct a Merkle tree");
      }
    body
    {
        leafSigs = signatures;
        nnodes = signatures.size();
        auto  parents = bottomLevel(signatures);
        nnodes += parents.size();
        depth = 1;

        while (parents.size() > 1) {
            parents = internalLevel(parents);
            depth++;
            nnodes += parents.size();
        }

        return parents[0];
    }


    public int getNumNodes() {
        return nnodes;
    }

    public Node getRoot() {
        return root;
    }

    public int getHeight() {
        return depth;
    }


  /**
   * Constructs an internal level of the tree
   */
  static Nodes internalLevel(Nodes children) {
      auto parrents = new (immutable(Node))[signatures.size/2];
      // List<Node> parents = new ArrayList<Node>(children.size() / 2);
      uint j=0;
      for (uint i = 0; i < children.size() - 1; i += 2) {
          auto parent = Node(children[i], children[i+1]);
          parents[j]=parent;
          j+=1;
      }

      if (children.size() % 2 != 0) {
          Node parent = constructInternalNode(children[$], null);
          parents.add(parent);
      }
      return assumeUnique(parents);
  }


  /**
   * Constructs the bottom part of the tree - the leaf nodes and their
   * immediate parents.  Returns a list of the parent nodes.
   */
    static Nodes bottomLevel(SignatureArray signatures) {
        auto parents = new (immutable(Node))[signatures.size/2];

//            List<Node> parents = new ArrayList<Node>(signatures.size() / 2);
        uint j=0;
        for(uint i=0; i < signatures.size - 1; i += 2) {
            auto leaf1 = Node(signatures[i].buffer);
            auto leaf2 = Node(signatures[i+1].buffer);
            auto parent = Node(leaf1, leaf2);
            parents[j]=parent;
            j+=1;
        }

        // if odd number of leafs, handle last entry
        if (signatures.size % 2 != 0) {
            auto leaf = constructLeafNode(signatures[$]);
            auto parent = Node(leaf, null);
            parents[j]=parent;
        }

        return assumeUnique(parents);
    }

    private Node constructInternalNode(const(Node) child1, const(Node) child2) {
        Node parent = new Node();
        parent.type = INTERNAL_SIG_TYPE;

        if (child2 is null) {
            parent.sig = child1.sig;
        } else {
            parent.sig = internalHash(child1.sig, child2.sig);
        }

        parent.left = child1;
        parent.right = child2;
        return parent;
    }

    private static Node constructLeafNode(String signature) {
        Node leaf = new Node(Node.sigType.leaf, signature);
        // leaf.type = LEAF_SIG_TYPE;
        // leaf.sig = signature.getBytes(StandardCharsets.UTF_8);
        return leaf;
    }
/*
    immutable(H) internalHash(const(H) leftChildSig, const(H) rightChildSig) const pure nothrow {
        return H(leftChildSig,
        buffer ~= leftChilSig;
        buffer ~= rightChilSig;

    crc.reset();
    crc.update(leftChildSig);
    crc.update(rightChildSig);
    return longToByteArray(crc.getValue());
*/
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
  class Node {
      enum : ubyte {
          // Type of the Node
          internal,
          leaf
      } sigType;
      enum payload_size = sigType.sizeof + H.buffer_size;
      private this(sigType type) {
          this.type = type;
      }
      static immutable(Node) opCall(const(Node) child1, const(Node) child2)
          in {
              assert(child2 !is null);
          }
      body {
          auto parent = new Node(sigType.internal);
          if ( child2 is null ) {
              parent.signature = child1.signature;
          }
          else {
              parent.signature = H(child1.signature, child2.signature);
          }
          parent.left = child1;
          parent.right = child2;
          return assumeUnique(parent);
      }
      static immutable(Node) opCall(immutable(H) signature) {
          auto leaf = new Node(sigType.internal);
          leaf.signature = hash;
      }
      immutable(ubyte)[] payload() const pure nothrow {
          immutable(ubyte)[] buffer;
          buffer~=cast(immutable(ubyte[]))type;
          buffer~=signature.buffer;
      }
      uint number_of_elements() const pure nothrow {
          void local_count(immutable(Node) node) {
              if ( node !is null ) {
                  count++;
                  local_count(node.left);
                  local_count(node.right);
              }
          }
          uint count = 0;
          local_count(this);
          return count;
      }
      static immutable(H) cHash(const(Node) A, const(Node) B) const pure nothrow
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
      sigType type;
      H signature; // signature of the node
      Node left;
      Node right;

  }

  /**
   * Big-endian conversion
   */
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
}
