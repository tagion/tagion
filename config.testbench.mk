
WALLET_SUFFIX=$(TESTBENCH_BIN)/wallet
MASTER_WALLETS=${wildcard $(WALLET_SUFFIX)*}

WALLET_SUFFIX_LIST=${subst ${WALLET_SUFFIX},,${MASTER_WALLETS}}

#DARTBOOTRECORDER:=$(TEST_DIR)/dart.hibon

WALLETS+=zero
zero-wallet: PINCODE=01234
zero-wallet: NAME=zero
zero-wallet: AMOUNT=100000

WALLETS+=first
first-wallet: PINCODE=1234
first-wallet: NAME=first
first-wallet: AMOUNT=100000

WALLETS+=second
second-wallet: PINCODE=23456
second-wallet: NAME=second
second-wallet: AMOUNT=100000


WALLETS+=third
third-wallet: PINCODE=34567
third-wallet: NAME=third
third-wallet: AMOUNT=100000

WALLETS+=fourth
fourth-wallet: PINCODE=45678
fourth-wallet: NAME=fourth
fourth-wallet: AMOUNT=100000

WALLETS+=fifth
fifth-wallet: PINCODE=56789
fifth-wallet: NAME=fourth
fifth-wallet: AMOUNT=100000

WALLETS+=sixth
sixth-wallet: PINCODE=67890
sixth-wallet: NAME=sixth
sixth-wallet: AMOUNT=100000
