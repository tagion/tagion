#!/bin/bash
# for (( c=1; c<5; c++ ))
# do
#     gnome-terminal -- docker run --net=no_masquerade -it --ip="123.1.1.$c" -p "400$c:400$c" dtest --port=400$c -l
# done
docker run --net=no_masquerade -it --ip="123.1.1.20" -p "4020:4020" dtest --port=4020 -l

/ip4/0.0.0.0/tcp/4001/p2p/Qmdbom4fWmz5Ax5asDKV6VK7k1S11ukBhMU6WgK66Z2ufX
/ip4/0.0.0.0/tcp/4003/p2p/QmQH37bqXUYC47sZyi7yQGQCePb239b5qfgRHjndqxN8sN
/ip4/0.0.0.0/tcp/4002/p2p/QmdZQ7YWosHDZS7u4dZN4VDWJGPdBaZLJFPmm1iBBJghMH
/ip4/0.0.0.0/tcp/4000/p2p/QmRL1Ux8G2BpGUQdXtjzzubNwqpLSimSpDN9NS7TzsNDhq

13.95.3.250
104.46.59.133
51.144.176.126
51.144.75.34