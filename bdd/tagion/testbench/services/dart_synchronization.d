module tagion.testbench.services.dart_synchronization;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.tools.Basic;
import tagion.testbench.tools.Environment;
import tagion.services.DART : DARTOptions;
import std.file;
import tagion.crypto.SecureNet;
import tagion.dart.DART;
import std.exception;
import tagion.crypto.Types : Fingerprint;
import std.format;
import tagion.testbench.tools.Environment;
import std.path : buildPath;

enum feature = Feature(
            "is a service that synchronizes the DART database with another one.",
            [
        "It should be used on node start up to ensure that local database is up-to-date.",
        "In this test scenario we require that the remote database is static (not updated)."
]);

alias FeatureContext = Tuple!(
        IsToConnectToRemoteDatabaseWhichIsUptodateAndReadItsBullseye, "IsToConnectToRemoteDatabaseWhichIsUptodateAndReadItsBullseye",
        IsToSynchronizeTheLocalDatabase, "IsToSynchronizeTheLocalDatabase",
        FeatureGroup*, "result"
);

@safe @Scenario("is to connect to remote database which is up-to-date and read its bullseye.",
        [])
class IsToConnectToRemoteDatabaseWhichIsUptodateAndReadItsBullseye {

    DART local_db;
    DART remote_db;
    Fingerprint remote_b;
    const local_db_name = "local_db.drt";
    const remote_db_name = "remote_db.drt";
    string local_db_path;
    string remote_db_path;

    @Given("we have a local database.")
    Document localDatabase() {
        auto net = new StdSecureNet;
        
        local_db_path = buildPath(env.bdd_log, __MODULE__, local_db_name);

        if(local_db_path.exists){
            local_db_path.remove;
        }
        DART.create(local_db_path, net);
        local_db = new DART(net, local_db_path);
        return result_ok;
    }

    @Given("we have a remote node with a database.")
    Document aDatabase() {
        // Note: Task is to connect to a remote db, but temporary
        // for a test purpose a local filled database will be created.
        import std.random;
        import std.datetime.stopwatch;
        import tagion.hibon.HiBONRecord;
        import tagion.dart.DARTFakeNet : DARTFakeNet;
        import tagion.utils.Term;

        const number_of_archives = 10000;
        const bundle_size = 1000;
        auto net = new StdSecureNet;

        remote_db_path = buildPath(env.bdd_log, __MODULE__, remote_db_name);
        
        if(remote_db_path.exists){
            remote_db_path.remove;
        }
        DART.create(remote_db_path, net);
        remote_db = new DART(net, remote_db_path);

        static struct TestDoc {
            string text;
            mixin HiBONRecord;
        }

        static const(Document) test_doc(const ulong x) {
            TestDoc _test_doc;
            _test_doc.text = format("Test document %d", x);
            return _test_doc.toDoc;
        }

        size_t count;
        auto rnd = Random(unpredictableSeed);

        long prev_dart_time;
        foreach (no; 0 .. (number_of_archives / bundle_size) + 1) {
            count += bundle_size;
            const N = (number_of_archives < count) ? number_of_archives % bundle_size : bundle_size;
            auto recorder = remote_db.recorder;
            foreach (i; 0 .. N) {
                const random_doc_no = uniform(ulong.min, ulong.max, rnd);
                recorder.add(test_doc(random_doc_no));
            }
            remote_db.modify(recorder);
        }
        return result_ok;
    }

    @When("we read the bullseye from the remote database.")
    Document remoteDatabase() {
        remote_b = remote_db.bullseye;
        return result_ok;
    }

    @Then("we check that the remote database is different from the local one.")
    Document localOne() {
        const local_b = local_db.bullseye;
        check(remote_b != local_b, format("bullseyes do not match for remote db %s and local db %s", remote_b, local_b));
        return result_ok;
    }
}

@safe @Scenario("is to synchronize the local database.",
        [])
class IsToSynchronizeTheLocalDatabase {

    @Given("we have the local database.")
    Document localDatabase() {
        return Document();
    }

    @Given("we have the remote database.")
    Document remoteDatabase() {
        return Document();
    }

    @When("the local database is not up-to-date.")
    Document notUptodate() {
        return Document();
    }

    @Then("we run the synchronization.")
    Document theSynchronization() {
        return Document();
    }

    @Then("we check that bullseyes match.")
    Document bullseyesMatch() {
        return Document();
    }

}

mixin Main!(_main);

int _main(string[] args) {
    auto module_path = buildPath(env.bdd_log, __MODULE__);
    mkdirRecurse(module_path);
    auto dart_synchronization_feature = automation!(tagion.testbench.services.dart_synchronization);
    DARTOptions opts; // specify a path.
    dart_synchronization_feature.IsToConnectToRemoteDatabaseWhichIsUptodateAndReadItsBullseye;
    dart_synchronization_feature.run;
    return 0;
}
