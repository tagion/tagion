module tagion.behaviour.Behaviour;

import std.traits;
import std.meta : AliasSeq, Filter;
import std.format;
import std.typecons;

struct Feature {
    string description;
    string[] comments;
}

struct Given {
    string description;
}

struct And {
    string description;
}

struct When {
    string description;
}

struct Then {
    string description;
}

alias BehaviourProperties = AliasSeq!(Given, And, When, Then);

alias MemberSequency=Tuple!(string, "member", string, "goal");
alias PropertyFormat(T)=format!(T.stringof~".%s", string);

const(MemberSequency[]) memberSequency(T)() if (is(T==class) || is(T==struct)) {
    MemberSequency[] result;
    static foreach(name; __traits(allMembers, T)) {{
            enum code=format!q{alias member=%s.%s;}(T.stringof, name);
            //pragma(msg,code);
            mixin(code);
            //T elem;
            static if (__traits(compiles, typeof(member))) {
                alias hasProperty(Property) =hasUDA!(member, Property);
                alias filterProperty=Filter!(hasProperty, BehaviourProperties);
                static if (filterProperty.length == 1) {
                    result~=MemberSequency(
                        PropertyFormat!T(name),
                        filterProperty[0].stringof);
                }
            }
        }}
    return result;
}

version(unittest) {
    // Behavioral examples
    @Feature("Some awesome feature should print some cash out of the blue")
        class Some_awesome_feature {
            @Given("the card is valid")
            bool is_valid() {
                return false;
            }
            @And("the account is in credit")
            bool in_credit() {
                return false;
            }
            @And("the dispenser contains cash")
            bool contains_cash() {
                return false;
            }
            @When("the Customer request cash")
            bool request_cash() {
                return false;
            }
            @Then("the account is debited")
            bool is_debited() {
                return false;
            }
            @And("the cash is dispensed")
            bool is_dispensed() {
                return false;
            }
        }

    @Feature("Some awesome feature should print some cash out of the blue")
        class Some_awesome_feature_not_ordered {
            @Then("the account is debited")
            bool is_debited() {
                return false;
            }
            @And("the cash is dispensed")
            bool is_dispensed() {
                return false;
            }
            @When("the Constumer request cash")
            bool request_cash() {
                return false;
            }
            @Given("that the card is valid")
            bool is_valid() {
                return false;
            }
            @And("the account is in credit")
            bool in_credit() {
                return false;
            }
            @And("the dispenser contains cash")
            bool contains_cash() {
                return false;
            }
        }
}

version(unittest) {
    import std.stdio;
    import std.algorithm.iteration : map, joiner;
    import std.algorithm.comparison : equal;
    import std.range : zip, only;
    import std.typecons;
    import std.array;
}


unittest {
    alias SomeFormat=format!(Some_awesome_feature.stringof~".%s", string);

    const expected=
        zip(
            ["is_valid", "in_credit", "contains_cash", "request_cash", "is_debited", "is_dispensed"],
            ["Given", "And", "And", "When", "Then", "And"]
        )
        .map!(a => tuple(SomeFormat(a[0]), a[1]))
        .array;

    assert(equal(memberSequency!Some_awesome_feature,
            expected));
}
