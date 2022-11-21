<a href="https://tagion.org"><img alt="tagion logo" src="https://github.com/tagion/resources/raw/master/branding/logomark.svg?sanitize=true" alt="tagion.org" height="60"></a>
# tagionevilwallet v.0.x.x
> This tool is used for creating evil hibon files.

- [tagionevilwallet v.0.x.x](#tagionevilwallet-v0xx)
- [General](#general)
- [amount on invoice](#amount-on-invoice)
- [setfee and fee](#setfee-and-fee)
- [invalid signature](#invalid-signature)
- [0x00 public key on invoice](#0x00-public-key-on-invoice)


# General
In general all checks with amount have been removed from the wallet binary. Therefore you are able to create invoices with negative amounts or zero amount. Remember that all of these can also be combined.

# amount on invoice
You can specify any amount also negative when creating a invoice. For an example:

`tagionevilwallet --create-invoice TEST:-1000 -x 1111 --invoice invoicefile.hibon`

`tagionevilwallet --create-invoice TEST:0 -x 1111 --invoice invoicefile.hibon`


# setfee and fee
Set the desired fee you want to pay with:

`tagionevilwallet -x 0000 --pay invoicefile.hibon --port 10801 --send --setfee --fee N` 

Where N can be negative, zero or positive. 

# invalid signature
Make the signature invalid:

`tagionevilwallet -x 0000 --pay invoicefile.hibon --port 10801 --send --invalid-signature`

# 0x00 public key on invoice
Set the public key to be `0x00...`.

`tagionevilwallet -x 0000 --pay invoicefile.hibon --port 10801 --send --zero-pubkey`
