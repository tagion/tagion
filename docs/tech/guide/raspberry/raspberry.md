## Tagion om Raspberry Pi

This describes how to compile and install a Tagion test network on a Raspberry Pi.

The Pi version used in this example is a Pi-5 with 8GB RAM and it is setup to boot from a 256G USB-stick.

The system installed on the PI system is Ubuntu release 24.10.

![Tagion PI5](/img/raspberry_5.jpg)

## Preparation.
The swap partition needs to be increased to at least 8GB.
This can be done as follows.

First disable the swap.
```
sudo swapoff -a
Create a swapfile
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
```

* Enable the swap.
```
sudo swapon /swapfile
```

* Compile the tagion software.
```
mkdir work
cd work
cd tagion/
git clone git@github.com:tagion/tagion.git
```

* Install the tools.
```
sudo apt install perl autoconf g++ make
```

* Install the compile
```
cd /tmp
wget https://github.com/ldc-developers/ldc/releases/download/v1.40.0/ldc2-1.40.0-linux-aarch64.tar.xz

cd .local
cd share
tar -xJvf /tmp/ldc2-1.40.0-linux-aarch64.tar.xz
```

* Create a link to compiler.
```
cd
cd .local
mkdir bin
ls -s ../share/ldc2-1.40.0-linux-aarch64/bin/ldc2
```

* Setup the path to the compiler.
```
export PATH $HOME/.local/bin:$PATH
```

* Check the compiler version.
```
ldc2 –version
```
* Compile the tagion node program.
```
cd
cd work/tagion
make install
```

## Run a test network.

* Setup the test wallets.
```
scripts/create_wallets.sh -b ~/.local/bin/
```
Start the network in mode0.
```
~/.local/bin/neuewelle ./mode0/tagionwave.json --keys $PWD/mode0/ < keys
```

Now the test network should start in mode0.






