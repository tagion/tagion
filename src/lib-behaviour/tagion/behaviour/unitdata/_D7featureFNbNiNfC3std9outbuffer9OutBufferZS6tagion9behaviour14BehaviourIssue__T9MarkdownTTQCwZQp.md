## Feature: Some awesome feature should print some cash out of the blue

`tagion.behaviour.BehaviourUnittest`
### Scenario: Some awesome money printer

`Some_awesome_feature`
    *Given* the card is valid

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

### Scenario: Some money printer which is controlled by a bankster

`Some_awesome_feature_bad_format_double_property`
    *Given* the card is valid

`is_valid`
    *Then* the account is debited

`is_debited`
      *And* the cash is dispensed

`is_dispensed`
    *When* the Customer request cash

`request_cash`

### Scenario: Some money printer which has run out of paper

`Some_awesome_feature_bad_format_missing_given`
    *Then* the account is debited 

`is_debited_bad_one`
      *And* the cash is dispensed

`is_dispensed`

### Scenario: Some money printer which is gone wild and prints toilet paper

`Some_awesome_feature_bad_format_missing_then`
    *Given* the card is valid

`is_valid`

