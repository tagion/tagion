module tagion.tools.collider.BehaviourOptions;
import std.array : join, split, array;
import tagion.basic.Types : FileExtension;
import tagion.utils.JSONCommon;
import std.process : execute, environment;

enum ONE_ARGS_ONLY = 2;
enum DFMT_ENV = "DFMT"; /// Set the path and argument d-format including the flags
enum ICONV = "iconv"; /// Character format converter  

/** 
 * Option setting for the optarg and behaviour.json config file
 */
struct BehaviourOptions {
    /** Include paths for the BDD source files */
    string[] paths;
    /** BDD extension (default markdown .md) */
    string bdd_ext;
    /** Extension for d-source files (default .d) */
    string d_ext;
    /** Regex filter for the files to be incl */
    string regex_inc;
    /** Regex for the files to be excluded */
    string regex_exc;
    /** Extension for the generated BDD-files */
    string bdd_gen_ext;
    /** D source formater (default dfmt) */
    string dfmt;
    /** Command line flags for the dfmt */
    string[] dfmt_flags;

    /** Character converter (default iconv) */
    string iconv;
    /** Command line flags for the iconv */
    string[] iconv_flags;

    string importfile; /// Import file which are included into the generated skeleton
    bool enable_package; /// This produce the package
    bool silent;
    /** 
     * Used to set default options if config file not provided
     */
    //    string test_stage_env;
    //    string dbin_env;
    string schedule_file; /// Schedule filename
    string collider_root;
    void setDefault() {
        const gen = "gen";
        bdd_ext = FileExtension.markdown;
        bdd_gen_ext = [gen, FileExtension.markdown].join;
        d_ext = [gen, FileExtension.dsrc].join;
        regex_inc = `/testbench/`;
        //      test_stage_env = "TEST_STAGE";
        if (!(DFMT_ENV in environment)) {
            const which_dfmt = execute(["which", "dfmt"]);
            if (which_dfmt.status is 0) {
                dfmt = which_dfmt.output;
                dfmt_flags = ["-i"];
            }
        }
        const which_iconv = execute(["which", "iconv"]);
        iconv = which_iconv.output;
        iconv_flags = ["-t", "utf-8", "-f", "utf-8", "-c"];
        //        dbin_env = "DBIN";
    }

    mixin JSONCommon;
    mixin JSONConfig;
}
