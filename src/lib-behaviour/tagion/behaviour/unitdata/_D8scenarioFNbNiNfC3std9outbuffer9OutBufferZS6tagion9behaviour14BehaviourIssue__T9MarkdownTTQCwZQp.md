### Scenario: Some awesome money printer

`Some_awesome_feature`
  *Given* the card is valid

`is_valid`
    *And* the account is in credit

`in_credit`
    *And* the dispenser contains cash

`contains_cash`
  *When* the Customer request cash

`request_cash`
  *Then* the account is debited

`is_debited`
    *And* the cash is dispensed

`is_dispensed`
