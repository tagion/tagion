## Feature: Implement secure key generation at network startup. 
This feature supplies the secrete key for the network node, which is used as the master key to sign consensus for the nodes.

`tagion.testbench.NetworwKeyGeneration`

### Scenario: Command line pass-phase switch 

*Given* the pass-phrase is generated from the tagionwallet.

The correct pass-phase is and it present to the tagionwallet command line.

`apply_passphase`

*When* the pass-phase is correct 
`is_passphase_correct`

*Then* the start the tagionwave program.

`is_running`
*Then* stop the program.

`is_stopped`

*Then*  check that the program returns no errors.

`noerror`

### Scenario: Command line incorrect pass-phase switch 

*Given* the pass-phrase is generated from the tagionwallet.

The correct pass-phase is and it present to the tagionwallet command line.

`apply_passphase`

*When* the pass-phase is correct 
`is_passphase_incorrect`
*Then* stop the program.

`is_stopped`
 *Then*  check that the program return fail.

`failed`
