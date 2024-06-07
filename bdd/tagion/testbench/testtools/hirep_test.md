Feature: hirep scenarios

Scenario: No filters
Given initial hibon file with several records
When hirep run without filters
Then the output should be as initial hibon

Scenario: No filters with not
Given initial hibon file with several records
When hirep run without filters with not
Then the output should be empty

Scenario: List filtering
Given initial hibon file with several records
When hirep filter several specific items in list
When hirep filter the same with range in list
Then both outputs should be the same and as expected

Scenario: List filtering mixed
Given initial hibon file with several records
When hirep filter items in list mixed with name specified
Then filtered records should match both filters

Scenario: Test output and stdout
Given initial hibon file with several records
When hirep run with output specified
When hirep run with stdout
Then the output file should be equal to stdout

Scenario: Test name
Given initial hibon file with several records with name
When hirep run with name specified
Then the output should contain only records with given name

Scenario: Test recordtype
Given initial hibon file with several records with recordtype
When hirep run with recordtype specified
Then the output should contain only records with given recordtype

Scenario: Test type
Given initial hibon file with several records with type
When hirep run with type specified
Then the output should contain only records with given type

Scenario: Test name and type
Given initial hibon file with several records with name and type
When hirep run with name and type specified
Then filtered records should match both filters

Scenario: Test recursive
Given initial hibon file with records with subhibon
When hirep run with args specified
Then the output should contain both records with match in top level and nested levels

Scenario: Test recursive with not
Given initial hibon file with records with subhibon
When hirep run with args specified
Then the output should filter out both records with match in top level and nested levels

Scenario: Test subhibon
Given initial hibon file with records with subhibon
When hirep run with args specified
Then the output should contain only subhibon that matches filter

Scenario: Test subhibon with not
Given hirep tool
When hirep run with subhibon and not flag
Then hirep should fail with error message
