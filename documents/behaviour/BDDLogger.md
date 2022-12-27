## BDD Logger

The purpose of the BDD Logger is to produces a visual representation of BDD logs in HTML or Markdown.

When a BDD is executed it should produce a HiBON log file, this log-file contains all the information of the BDD including the result of the BDD. The result contains information about if the test has passed or failed.

The hibonutil should be used to convert the log-files into a JSON file.

Here is an example of an BDD log files as JSON.
Sample a feature which fails all tests.
```

{
    "info": {
        "name": "tagion.behaviour.BehaviourUnittestWithCtor",
        "property": {
            "$@": "Feature",
            "comments": {},
            "description": "Some awesome feature should print some cash out of the blue"
        },
        "result": {}
    },
    "scenarios": [
        {
            "but": {
                "infos": [
                    {
                        "name": "swollow_the_card",
                        "property": {
                            "comments": {},
                            "description": "if the Customer does not take his card, then the card must be swollowed"
                        },
                        "result": {}
                    }
                ]
            },
            "given": {
                "infos": [
                    {
                        "name": "is_valid",
                        "property": {
                            "comments": {},
                            "description": "the card is valid"
                        },
                        "result": {}
                    },
                    {
                        "name": "in_credit",
                        "property": {
                            "comments": {},
                            "description": "the account is in credit"
                        },
                        "result": {}
                    },
                    {
                        "name": "contains_cash",
                        "property": {
                            "comments": {},
                            "description": "the dispenser contains cash"
                        },
                        "result": {}
                    }
                ]
            },
            "info": {
                "name": "Some_awesome_feature",
                "property": {
                    "comments": {},
                    "description": "Some awesome money printer"
                },
                "result": {
                    "$@": "BDDResult",
                    "outcome": {
                        "end": true
                    }
                }
            },
            "then": {
                "infos": [
                    {
                        "name": "is_debited",
                        "property": {
                            "comments": {},
                            "description": "the account is debited"
                        },
                        "result": {}
                    },
                    {
                        "name": "is_dispensed",
                        "property": {
                            "comments": {},
                            "description": "the cash is dispensed"
                        },
                        "result": {}
                    }
                ]
            },
            "when": {
                "infos": [
                    {
                        "name": "request_cash",
                        "property": {
                            "comments": {},
                            "description": "the Customer request cash"
                        },
                        "result": {}
                    }
                ]
            }
        },
        {
            "but": {
                "infos": {}
            },
            "given": {
                "infos": [
                    {
                        "name": "is_valid",
                        "property": {
                            "comments": {},
                            "description": "the card is valid"
                        },
                        "result": {}
                    }
                ]
            },
            "info": {
                "name": "Some_awesome_feature_bad_format_double_property",
                "property": {
                    "comments": {},
                    "description": "Some money printer which is controlled by a bankster"
                },
                "result": {
                    "$@": "BDDResult",
                    "outcome": {
                        "end": true
                    }
                }
            },
            "then": {
                "infos": [
                    {
                        "name": "is_debited",
                        "property": {
                            "comments": {},
                            "description": "the account is debited"
                        },
                        "result": {}
                    },
                    {
                        "name": "is_dispensed",
                        "property": {
                            "comments": {},
                            "description": "the cash is dispensed"
                        },
                        "result": {}
                    }
                ]
            },
            "when": {
                "infos": [
                    {
                        "name": "request_cash",
                        "property": {
                            "comments": {},
                            "description": "the Customer request cash"
                        },
                        "result": {}
                    }
                ]
            }
        }
    ]
}
```

Sample of feature which passes all tests.
```

{
    "info": {
        "name": "tagion.behaviour.BehaviourUnittestWithCtor",
        "property": {
            "$@": "Feature",
            "comments": {},
            "description": "Some awesome feature should print some cash out of the blue"
        },
        "result": {}
    },
    "scenarios": [
        {
            "but": {
                "infos": [
                    {
                        "name": "swollow_the_card",
                        "property": {
                            "comments": {},
                            "description": "if the Customer does not take his card, then the card must be swollowed"
                        },
                        "result": {
                            "$@": "BDDResult",
                            "outcome": {
                                "test": "tagion.behaviour.BehaviourUnittestWithCtor.Some_awesome_feature.swollow_the_card"
                            }
                        }
                    }
                ]
            },
            "given": {
                "infos": [
                    {
                        "name": "is_valid",
                        "property": {
                            "comments": {},
                            "description": "the card is valid"
                        },
                        "result": {
                            "$@": "BDDResult",
                            "outcome": {
                                "test": "tagion.behaviour.BehaviourUnittestWithCtor.Some_awesome_feature.is_valid"
                            }
                        }
                    },
                    {
                        "name": "in_credit",
                        "property": {
                            "comments": {},
                            "description": "the account is in credit"
                        },
                        "result": {
                            "$@": "BDDResult",
                            "outcome": {
                                "test": "tagion.behaviour.BehaviourUnittestWithCtor.Some_awesome_feature.in_credit"
                            }
                        }
                    },
                    {
                        "name": "contains_cash",
                        "property": {
                            "comments": {},
                            "description": "the dispenser contains cash"
                        },
                        "result": {
                            "$@": "BDDResult",
                            "outcome": {
                                "test": "tagion.behaviour.BehaviourUnittestWithCtor.Some_awesome_feature.contains_cash"
                            }
                        }
                    }
                ]
            },
            "info": {
                "name": "Some_awesome_feature",
                "property": {
                    "comments": {},
                    "description": "Some awesome money printer"
                },
                "result": {
                    "$@": "BDDResult",
                    "outcome": {
                        "end": true
                    }
                }
            },
            "then": {
                "infos": [
                    {
                        "name": "is_debited",
                        "property": {
                            "comments": {},
                            "description": "the account is debited"
                        },
                        "result": {
                            "$@": "BDDResult",
                            "outcome": {
                                "test": "tagion.behaviour.BehaviourUnittestWithCtor.Some_awesome_feature.is_debited"
                            }
                        }
                    },
                    {
                        "name": "is_dispensed",
                        "property": {
                            "comments": {},
                            "description": "the cash is dispensed"
                        },
                        "result": {
                            "$@": "BDDResult",
                            "outcome": {
                                "test": "tagion.behaviour.BehaviourUnittestWithCtor.Some_awesome_feature.is_dispensed"
                            }
                        }
                    }
                ]
            },
            "when": {
                "infos": [
                    {
                        "name": "request_cash",
                        "property": {
                            "comments": {},
                            "description": "the Customer request cash"
                        },
                        "result": {
                            "$@": "BDDResult",
                            "outcome": {
                                "test": "tagion.behaviour.BehaviourUnittestWithCtor.Some_awesome_feature.request_cash"
                            }
                        }
                    }
                ]
            }
        },
        {
            "but": {
                "infos": {}
            },
            "given": {
                "infos": [
                    {
                        "name": "is_valid",
                        "property": {
                            "comments": {},
                            "description": "the card is valid"
                        },
                        "result": {
                            "$@": "BDDResult",
                            "outcome": {
                                "test": "tagion.behaviour.BehaviourUnittestWithCtor.Some_awesome_feature_bad_format_double_property.is_valid"
                            }
                        }
                    }
                ]
            },
            "info": {
                "name": "Some_awesome_feature_bad_format_double_property",
                "property": {
                    "comments": {},
                    "description": "Some money printer which is controlled by a bankster"
                },
                "result": {
                    "$@": "BDDResult",
                    "outcome": {
                        "end": true
                    }
                }
            },
            "then": {
                "infos": [
                    {
                        "name": "is_debited",
                        "property": {
                            "comments": {},
                            "description": "the account is debited"
                        },
                        "result": {
                            "$@": "BDDResult",
                            "outcome": {
                                "test": "tagion.behaviour.BehaviourUnittestWithCtor.Some_awesome_feature_bad_format_double_property.is_debited"
                            }
                        }
                    },
                    {
                        "name": "is_dispensed",
                        "property": {
                            "comments": {},
                            "description": "the cash is dispensed"
                        },
                        "result": {
                            "$@": "BDDResult",
                            "outcome": {
                                "test": "tagion.behaviour.BehaviourUnittestWithCtor.Some_awesome_feature_bad_format_double_property.is_dispensed"
                            }
                        }
                    }
                ]
            },
            "when": {
                "infos": [
                    {
                        "name": "request_cash",
                        "property": {
                            "comments": {},
                            "description": "the Customer request cash"
                        },
                        "result": {
                            "$@": "BDDResult",
                            "outcome": {
                                "test": "tagion.behaviour.BehaviourUnittestWithCtor.Some_awesome_feature_bad_format_double_property.request_cash"
                            }
                        }
                    }
                ]
            }
        }
    ]
}
```

