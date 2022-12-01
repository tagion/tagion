
CERT?=mycert.pem
PORT?= 8081
URL?=172.0.0.1

all: ssl_client ssl_server $(CERT)

ssl_server:
	gcc -g -o ssl_server ssl_server.c -lssl -lcrypto

ssl_client:
	gcc -g -o ssl_client ssl_client.c -lssl -lcrypto

%.pem:
	openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout mycert.pem -out mycert.pem

start:
	./ssl_server $(PORT)

test:
	./ssl_client $(URL) $(PORT)

clean:
	rm -f ssl_client ssl_server

proper: clean
	rm -f $(CERT)


#openssl req -x509 -nodes -days 365 -newkey rsa:1024 -keyout mycert.pem -out mycert.pem

#Compile the ssl_client : gcc -Wall -o ssl_client  ssl_client.c -L/usr/lib -lssl -lcrypto
#Run :   ./ssl_client <host_name> <port_number>

#sudo ./ssl_server  8081

#Note: In above command 8081 is the port number.

#After that, we will run ssl_client using the below command and send the XML request.

#./ssl_client  127.0.0.1 8081


