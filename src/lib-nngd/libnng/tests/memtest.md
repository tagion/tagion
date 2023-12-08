
# how to reproduce the memory leak test

- make all NNG_WITH_MBEDTLS=OFF
- ./build/test/memtest > /dev/null 2>&1 &
- check the PID and run htop -p {PID}
- in another tty use curl for massive fllod of http requests to the http://localhost:8088/api/v1/time
  you may use tests/testbench.sh in parallel instances
- check the RSS memory - it shoud be stable if no leak appear

