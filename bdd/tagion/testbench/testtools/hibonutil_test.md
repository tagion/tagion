Feature: hibonutil scenarios

Scenario: FormatHex
Given input hibon file
When hibonutil is called with given input file in format hex
Then the output should be as expected
