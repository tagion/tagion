module tagion.testbench.services.DARTService;

import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import tagion.actor;
import tagion.services.DARTService;

enum feature = Feature(
"see if we can read and write trough the dartservice",
[]);

alias FeatureContext = Tuple!(
    WriteAndReadFromDartDb, "WriteAndReadFromDartDb",
    FeatureGroup*, "result"
);

@safe @Scenario("write and read from dart db",
[])
class WriteAndReadFromDartDb {
    enum dart_task = "dart_service_task";
    DARTServiceHandle handle;

    @Given("I have a dart db")
    Document dartDb() {
        return Document();
    }

    @Given("I have an dart actor with said db")
    Document saidDb() {
        handle = spawn!DARTService(dart_task, "/tmp/dart_service_test.drt", "verysecret");
        return result_ok;
    }

    @When("I send a dartModify command with a recorder containing changes to add")
    Document toAdd() {
        return Document();
    }

    @When("I send a dartRead command to see if it has the changed")
    Document theChanged() {
        return Document();
    }
}
