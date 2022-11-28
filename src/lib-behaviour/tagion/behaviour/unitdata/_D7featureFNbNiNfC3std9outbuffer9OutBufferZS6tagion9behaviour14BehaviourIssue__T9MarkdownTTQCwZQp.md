## Feature: Some awesome feature should print some cash out of the blue

`tagion.behaviour.BehaviourUnittest`

### Scenario: Some awesome money printer

`Some_awesome_feature`

*Given* the card is valid

`is_valid`

*Given* the account is in credit

`in_credit`

*Given* the dispenser contains cash

`contains_cash`

*When* the Customer request cash

`request_cash`

*Then* the account is debited

`is_debited`

*Then* the cash is dispensed

`is_dispensed`

*But* if the Customer does not take his card, then the card must be swollowed

`swollow_the_card`


### Scenario: Some money printer which is controlled by a bankster

`Some_awesome_feature_bad_format_double_property`

*Given* the card is valid

`is_valid`

*When* the Customer request cash

`request_cash`

*Then* the account is debited

`is_debited`

*Then* the cash is dispensed

`is_dispensed`


### Scenario: Some money printer which has run out of paper

`Some_awesome_feature_bad_format_missing_given`

*Then* the account is debited 

`is_debited_bad_one`

*Then* the cash is dispensed

`is_dispensed`


### Scenario: Some money printer which is gone wild and prints toilet paper

`Some_awesome_feature_bad_format_missing_then`

*Given* the card is valid

`is_valid`


