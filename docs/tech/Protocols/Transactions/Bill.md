# Tagion Bill

A tagion bill must contain the value `$V`, time of creation `$t` and the owner key `$Y`.

[TagionBill](https://ddoc.tagion.org/tagion.script.common.TagionBill)
| Name    | D-Type          | Description            | Required |
| :-----: | --------------- | ---------------------- | :------: |
| `$@`    | TGN             | Record type name       |   Yes    |
| `$V`    | TagionCurrency  | Tagion Currency        |   Yes    |
| `$t`    | sdt_t           | Timestamp              |   Yes    |
| `$Y`    | Pubkey          | Owner key              |   Yes    |
| `$x`    | Buffer          | Nonce, usually 4 bytes |   No     |
