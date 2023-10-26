module tagion.crypto.secp256k1.c.secp256k1_surjectionproof;

extern (C):
nothrow:
@nogc:

/** Maximum number of inputs that may be given in a surjection proof */
enum SECP256K1_SURJECTIONPROOF_MAX_N_INPUTS = 256;

/** Maximum number of inputs that may be used in a surjection proof */
enum SECP256K1_SURJECTIONPROOF_MAX_USED_INPUTS = 256;

/** Number of bytes a serialized surjection proof requires given the
 *  number of inputs and the number of used inputs.
 */
extern (D) auto SECP256K1_SURJECTIONPROOF_SERIALIZATION_BYTES(T0, T1)(auto ref T0 n_inputs, auto ref T1 n_used_inputs)
{
    return 2 + (n_inputs + 7) / 8 + 32 * (1 + n_used_inputs);
}

/** Maximum number of bytes a serialized surjection proof requires. */
enum SECP256K1_SURJECTIONPROOF_SERIALIZATION_BYTES_MAX = SECP256K1_SURJECTIONPROOF_SERIALIZATION_BYTES(SECP256K1_SURJECTIONPROOF_MAX_N_INPUTS, SECP256K1_SURJECTIONPROOF_MAX_USED_INPUTS);

/** Opaque data structure that holds a parsed surjection proof
 *
 *  The exact representation of data inside is implementation defined and not
 *  guaranteed to be portable between different platforms or versions. Nor is
 *  it guaranteed to have any particular size, nor that identical proofs
 *  will have identical representation. (That is, memcmp may return nonzero
 *  even for identical proofs.)
 *
 *  To obtain these properties, instead use secp256k1_surjectionproof_parse
 *  and secp256k1_surjectionproof_serialize to encode/decode proofs into a
 *  well-defined format.
 *
 *  The representation is exposed to allow creation of these objects on the
 *  stack; please *do not* use these internals directly.
 */
struct secp256k1_surjectionproof
{
    /** Mark whether this proof has gone through `secp256k1_surjectionproof_initialize` */

    /** Total number of input asset tags */
    size_t n_inputs;
    /** Bitmap of which input tags are used in the surjection proof */
    ubyte[32] used_inputs;
    /** Borromean signature: e0, scalars */
    ubyte[8224] data;
}

/** Parse a surjection proof
 *
 *  Returns: 1 when the proof could be parsed, 0 otherwise.
 *  Args: ctx:    a secp256k1 context object
 *  Out:  proof:  a pointer to a proof object
 *  In:   input:  a pointer to the array to parse
 *        inputlen: length of the array pointed to by input
 *
 *  The proof must consist of:
 *    - A 2-byte little-endian total input count `n`
 *    - A ceil(n/8)-byte bitmap indicating which inputs are used.
 *    - A big-endian 32-byte borromean signature e0 value
 *    - `m` big-endian 32-byte borromean signature s values, where `m`
 *      is the number of set bits in the bitmap
 */
int secp256k1_surjectionproof_parse (
    const(secp256k1_context)* ctx,
    secp256k1_surjectionproof* proof,
    const(ubyte)* input,
    size_t inputlen);

/** Serialize a surjection proof
 *
 *  Returns: 1 if enough space was available to serialize, 0 otherwise
 *  Args:   ctx:        a secp256k1 context object
 *  Out:    output:     a pointer to an array to store the serialization
 *  In/Out: outputlen:  a pointer to an integer which is initially set to the
 *                      size of output, and is overwritten with the written
 *                      size.
 *  In:     proof:      a pointer to an initialized proof object
 *
 *  See secp256k1_surjectionproof_parse for details about the encoding.
 */
int secp256k1_surjectionproof_serialize (
    const(secp256k1_context)* ctx,
    ubyte* output,
    size_t* outputlen,
    const(secp256k1_surjectionproof)* proof);

/** Data structure that holds a fixed asset tag.
 *
 * This data type is *not* opaque. It will always be 32 bytes of whatever
 * data the API user wants to use as an asset tag. Its contents have no
 * semantic meaning to libsecp whatsoever.
 */
struct secp256k1_fixed_asset_tag
{
    ubyte[32] data;
}

/** Returns the total number of inputs a proof expects to be over.
 *
 * Returns: the number of inputs for the given proof
 * In:   ctx: pointer to a context object
 *     proof: a pointer to a proof object
 */
size_t secp256k1_surjectionproof_n_total_inputs (
    const(secp256k1_context)* ctx,
    const(secp256k1_surjectionproof)* proof);

/** Returns the actual number of inputs that a proof uses
 *
 * Returns: the number of inputs for the given proof
 * In:   ctx: pointer to a context object
 *     proof: a pointer to a proof object
 */
size_t secp256k1_surjectionproof_n_used_inputs (
    const(secp256k1_context)* ctx,
    const(secp256k1_surjectionproof)* proof);

/** Returns the total size this proof would take, in bytes, when serialized
 *
 * Returns: the total size
 * In:   ctx: pointer to a context object
 *     proof: a pointer to a proof object
 */
size_t secp256k1_surjectionproof_serialized_size (
    const(secp256k1_context)* ctx,
    const(secp256k1_surjectionproof)* proof);

/** Surjection proof initialization function; decides on inputs to use
 *  To be used to initialize stack-allocated secp256k1_surjectionproof struct
 * Returns 0: inputs could not be selected
 *         n: inputs were selected after n iterations of random selection
 *
 * In:               ctx: pointer to a context object
 *      fixed_input_tags: fixed input tags `A_i` for all inputs. (If the fixed tag is not known,
 *                        e.g. in a coinjoin with others' inputs, an ephemeral tag can be given;
 *                        this won't match the output tag but might be used in the anonymity set.)
 *          n_input_tags: the number of entries in the fixed_input_tags array
 *   n_input_tags_to_use: the number of inputs to select randomly to put in the anonymity set
 *                        Must be <= SECP256K1_SURJECTIONPROOF_MAX_USED_INPUTS
 *      fixed_output_tag: fixed output tag
 *      max_n_iterations: the maximum number of iterations to do before giving up. Because the
 *                        maximum number of inputs (SECP256K1_SURJECTIONPROOF_MAX_N_INPUTS) is
 *                        limited to 256 the probability of giving up is smaller than
 *                        (255/256)^(n_input_tags_to_use*max_n_iterations).
 *
 *         random_seed32: a random seed to be used for input selection
 * Out:            proof: The proof whose bitvector will be initialized. In case of failure,
 *                        the state of the proof is undefined.
 *          input_index: The index of the actual input that is secretly mapped to the output
 */
int secp256k1_surjectionproof_initialize (
    const(secp256k1_context)* ctx,
    secp256k1_surjectionproof* proof,
    size_t* input_index,
    const(secp256k1_fixed_asset_tag)* fixed_input_tags,
    const size_t n_input_tags,
    const size_t n_input_tags_to_use,
    const(secp256k1_fixed_asset_tag)* fixed_output_tag,
    const size_t n_max_iterations,
    const(ubyte)* random_seed32);

/** Surjection proof allocation and initialization function; decides on inputs to use
 * Returns 0: inputs could not be selected, or malloc failure
 *         n: inputs were selected after n iterations of random selection
 *
 * In:               ctx: pointer to a context object
 *           proof_out_p: a pointer to a pointer to `secp256k1_surjectionproof*`.
 *                        the newly-allocated struct pointer will be saved here.
 *      fixed_input_tags: fixed input tags `A_i` for all inputs. (If the fixed tag is not known,
 *                        e.g. in a coinjoin with others' inputs, an ephemeral tag can be given;
 *                        this won't match the output tag but might be used in the anonymity set.)
 *          n_input_tags: the number of entries in the fixed_input_tags array
 *      n_input_tags_to_use: the number of inputs to select randomly to put in the anonymity set
 *      fixed_output_tag: fixed output tag
 *      max_n_iterations: the maximum number of iterations to do before giving up. Because the
 *                        maximum number of inputs (SECP256K1_SURJECTIONPROOF_MAX_N_INPUTS) is
 *                        limited to 256 the probability of giving up is smaller than
 *                        (255/256)^(n_input_tags_to_use*max_n_iterations).
 *
 *         random_seed32: a random seed to be used for input selection
 * Out:      proof_out_p: The pointer to newly-allocated proof whose bitvector will be initialized.
 *                        In case of failure, the pointer will be NULL.
 *          input_index: The index of the actual input that is secretly mapped to the output
 */
int secp256k1_surjectionproof_allocate_initialized (
    const(secp256k1_context)* ctx,
    secp256k1_surjectionproof** proof_out_p,
    size_t* input_index,
    const(secp256k1_fixed_asset_tag)* fixed_input_tags,
    const size_t n_input_tags,
    const size_t n_input_tags_to_use,
    const(secp256k1_fixed_asset_tag)* fixed_output_tag,
    const size_t n_max_iterations,
    const(ubyte)* random_seed32);

/** Surjection proof destroy function
 *  deallocates the struct that was allocated with secp256k1_surjectionproof_allocate_initialized
 *
 * In:               proof: pointer to secp256k1_surjectionproof struct
 */
void secp256k1_surjectionproof_destroy (secp256k1_surjectionproof* proof);

/** Surjection proof generation function
 * Returns 0: proof could not be created
 *         1: proof was successfully created
 *
 * In:                   ctx: pointer to a context object (not secp256k1_context_static)
 *      ephemeral_input_tags: the ephemeral asset tag of all inputs
 *    n_ephemeral_input_tags: the number of entries in the ephemeral_input_tags array
 *      ephemeral_output_tag: the ephemeral asset tag of the output
 *               input_index: the index of the input that actually maps to the output
 *        input_blinding_key: the blinding key of the input
 *       output_blinding_key: the blinding key of the output
 * In/Out: proof: The produced surjection proof. Must have already gone through `secp256k1_surjectionproof_initialize`
 */
int secp256k1_surjectionproof_generate (
    const(secp256k1_context)* ctx,
    secp256k1_surjectionproof* proof,
    const(secp256k1_generator)* ephemeral_input_tags,
    size_t n_ephemeral_input_tags,
    const(secp256k1_generator)* ephemeral_output_tag,
    size_t input_index,
    const(ubyte)* input_blinding_key,
    const(ubyte)* output_blinding_key);

/** Surjection proof verification function
 * Returns 0: proof was invalid
 *         1: proof was valid
 *
 * In:     ctx: pointer to a context object (not secp256k1_context_static)
 *         proof: proof to be verified
 *      ephemeral_input_tags: the ephemeral asset tag of all inputs
 *    n_ephemeral_input_tags: the number of entries in the ephemeral_input_tags array
 *      ephemeral_output_tag: the ephemeral asset tag of the output
 */
int secp256k1_surjectionproof_verify (
    const(secp256k1_context)* ctx,
    const(secp256k1_surjectionproof)* proof,
    const(secp256k1_generator)* ephemeral_input_tags,
    size_t n_ephemeral_input_tags,
    const(secp256k1_generator)* ephemeral_output_tag);

