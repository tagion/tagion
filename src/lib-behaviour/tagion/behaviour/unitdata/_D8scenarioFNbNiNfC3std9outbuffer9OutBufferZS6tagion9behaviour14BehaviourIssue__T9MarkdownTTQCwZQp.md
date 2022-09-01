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

