
alpha-mode1: HOSTPORT=4020
alpha-mode1: TRANSACTIONPORT=10810
alpha-mode1: MONITORPORT=10820
alpha-mode1: SYNC=false
${call MODE1,alpha}

beta-mode1: HOSTPORT=4021
beta-mode1: TRANSACTIONPORT=10811
beta-mode1: MONITORPORT=10821
beta-mode1: SYNC=true
${call MODE1,beta}

gamma-mode1: HOSTPORT=4022
gamma-mode1: TRANSACTIONPORT=10812
gamma-mode1: MONITORPORT=10822
gamma-mode1: SYNC=true
${call MODE1,gamma}

delta-mode1: HOSTPORT=4023
delta-mode1: TRANSACTIONPORT=10813
delta-mode1: MONITORPORT=10823
delta-mode1: SYNC=true
${call MODE1,delta}

epsilon-mode1: HOSTPORT=4024
epsilon-mode1: TRANSACTIONPORT=10814
epsilon-mode1: MONITORPORT=10824
epsilon-mode1: SYNC=true
${call MODE1,epsilon}

zeta-mode1: HOSTPORT=4025
zeta-mode1: TRANSACTIONPORT=10815
zeta-mode1: MONITORPORT=10825
zeta-mode1: SYNC=true
${call MODE1,zeta}


eta-mode1: HOSTPORT=4026
eta-mode1: TRANSACTIONPORT=10816
eta-mode1: MONITORPORT=10826
eta-mode1: SYNC=true
${call MODE1,eta}
