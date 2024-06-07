# Testing

Testing is a big part of our development flow.
It prevents regressions and allows a developer to make big changes with confidence that they'll not break things.

All tests are run automatically in our CI flow.

The most common command to use, to know that you did not break everything.  
This will run the unittest and the commit stage tests
```bash
make test
```

## Stages

To keep development process lean and to help know where a breaking change occurs.
The tests are broken up into different stages.

### Unittest

Unittest tests on a function level. Meaning that the behaviour of individual functions are tested independently.

```bash
make unittest
```

### Commit stage

The commit stage tests larger components like individual services.
Or simply tests which are too complex to keep in a unittest.

```bash
make bddtest
```

### Acceptance stage

The acceptance stage tests, are high level integration tests.

```bash
make bddtest TEST_STAGE=acceptance
```

### Operational stage

:::warning
The operation tests will override any network data that you've stored from running a node.
:::

The operational tests check that everything works as expected under sustained load over a long period of time.

Delete old data
```bash
rm -r ~/.local/share/tagion ./logs/ops/
```

Run the test
```bash
./scripts/run_ops -i
```
