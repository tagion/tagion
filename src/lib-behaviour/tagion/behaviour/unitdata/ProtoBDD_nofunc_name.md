## Feature: Some awesome feature should print some cash out of the blue
    Some addtion notes
`tagion.behaviour.unittest.ProtoBDD_nofunc_name`

### Scenario: Some awesome money printer

*Given* the card is valid
      *Given* the account is in credit
      *Given* the dispenser contains cash
    *When* the Customer request cash
    *Then* the account is debited
      *Then* the cash is dispensed
	  *But* if the card is not in credit

