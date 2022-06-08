## Feature: Some awesome feature should print some cash out of the blue
    Some addtion notes
`tagion.behaviour.unittest.ProtoBDD_nofunc_name`

### Scenario: Some awesome money printer

​    *Given* the card is valid
      *And* the account is in credit
      *And* the dispenser contains cash
    *When* the Customer request cash
    *Then* the account is debited
      *And* the cash is dispensed
