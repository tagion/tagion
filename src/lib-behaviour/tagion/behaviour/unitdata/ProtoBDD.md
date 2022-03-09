## Feature: Some awesome feature should print some cash out of the blue

`tagion.behaviour.unittest.ProtoBDD`

### Scenario: Some awesome money printer

​    *Given* the card is valid

`is_valid`
      *And* the account is in credit

`in_credit`
      *And* the dispenser contains cash

`contains_cash`
    *Then* the account is debited

`is_debited`
      *And* the cash is dispensed

`is_dispensed`
    *When* the Customer request cash

`request_cash`

