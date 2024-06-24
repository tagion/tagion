./bin/subscriber --tag=node_action -o nodeevents.hibon \
--address abstract://Mode1_0_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_1_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_2_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_3_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_4_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_5_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_6_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_7_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_8_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_9_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_10_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_11_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_12_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_13_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_14_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_15_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_16_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_17_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_18_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_19_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_20_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_21_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_22_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_23_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_24_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_25_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_26_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_27_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_28_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_29_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_30_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_31_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_32_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_33_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_34_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_35_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_36_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_37_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_38_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_39_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_40_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_41_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_42_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_43_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_44_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_45_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_46_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_47_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_48_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_49_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_50_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_51_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_52_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_53_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_54_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_55_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_56_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_57_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_58_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_59_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_60_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_61_SUBSCRIPTION_NEUEWELLE  \
--address abstract://Mode1_62_SUBSCRIPTION_NEUEWELLE  \
#!/usr/bin/env bash

if [ -z "$1" ]; then
    echo "Usage: $0 <num_addresses>"
    exit 1
fi

num_addresses=$1

subscribe_command="./bin/subscriber --tag=node_action -o nodeevents.hibon"

for ((i=0; i<$num_addresses; i++))
do
    address="abstract://Mode1_${i}_SUBSCRIPTION_NEUEWELLE"
    subscribe_command="$subscribe_command --address $address"
done

eval $subscribe_command

