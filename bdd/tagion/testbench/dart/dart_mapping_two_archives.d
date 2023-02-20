module tagion.testbench.dart.dart_mapping_two_archives;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import std.path : setExtension, buildPath;
import std.file : mkdirRecurse;
import std.stdio : writefln;
import std.format : format;

import tagion.dart.DARTFakeNet;
import tagion.dart.DART : DART;
import tagion.basic.Types : Buffer, FileExtension;
import tagion.testbench.tools.BDDOptions;
import tagion.testbench.tools.Environment;


enum feature = Feature(
        "Dart mapping of two archives",
        ["All test in this bdd should use dart fakenet."]);

alias FeatureContext = Tuple!(
    AddOneArchive, "AddOneArchive",
    AddAnotherArchive, "AddAnotherArchive",
    RemoveArchive, "RemoveArchive",
    FeatureGroup*, "result"
);

@safe @Scenario("Add one archive.",
    ["mark #one_archive"])
class AddOneArchive {
    BDDOptions bdd_options;
    string module_path;
    string dartfilename;
    auto net = new DARTFakeNet("very_secret");

    this(BDDOptions bdd_options) {
        this.bdd_options = bdd_options;
        this.module_path = env.bdd_log.buildPath(bdd_options.scenario_name);
    }

    @Given("I have a dartfile.")
    Document dartfile() {
        // create the directory to store the DART in.
        mkdirRecurse(module_path);
        dartfilename = buildPath(module_path, "default".setExtension(FileExtension.dart));
        // create the dartfile
        DART.create(dartfilename);

        // Exception dart_exception;
        // auto db = new DART(net, dartfilename, dart_exception);
        // check(!(dart_exception is null), format("Failed to open DART: %s", dart_exception.msg));
        

        return result_ok;
    }

    @Given("I add one archive1 in sector A.")
    Document a() {
        return Document();
    }

    @Then("the archive should be read and checked.")
    Document checked() {
        return Document();
    }

}

@safe @Scenario("Add another archive.",
    ["mark #two_archives"])
class AddAnotherArchive {

    @Given("#one_archive")
    Document onearchive() {
        return Document();
    }

    @Given("i add another archive2 in sector A.")
    Document inSectorA() {
        return Document();
    }

    @Then("both archives should be read and checked.")
    Document readAndChecked() {
        return Document();
    }

    @Then("check the branch of sector A.")
    Document ofSectorA() {
        return Document();
    }

    @Then("check the bullseye.")
    Document checkTheBullseye() {
        return Document();
    }

}

@safe @Scenario("Remove archive",
    [])
class RemoveArchive {

    @Given("#two_archives")
    Document twoarchives() {
        return Document();
    }

    @Given("i remove archive1.")
    Document archive1() {
        return Document();
    }

    @Then("check that archive2 has been moved from the branch in sector A.")
    Document a() {
        return Document();
    }

    @Then("check the bullseye.")
    Document bullseye() {
        return Document();
    }

}
