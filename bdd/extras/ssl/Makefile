
CERT?=mycert.pem
PORT?= 8081
URL?=172.0.0.1

all: ssl_c_client ssl_c_server test_server ssl_c_test_server $(CERT)

ssl_c_server:
	gcc -g -o ssl_c_server ssl_c_server.c -lssl -lcrypto

ssl_c_client:
	gcc -g -o ssl_c_client ssl_c_client.c -lssl -lcrypto

test_server:
	gcc -g -o test_server test_server.c 

ssl_c_test_server:
	gcc -g -o ssl_c_test_server ssl_c_test_server.c -lssl -lcrypto 

%.pem:
	openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout mycert.pem -out mycert.pem

start:
	./ssl_c_server $(PORT)

test:
	./ssl_c_client $(URL) $(PORT)

clean:
	rm -f ssl_c_client ssl_c_server test_server ssl_c_test_server


proper: clean
	rm -f $(CERT)


#openssl req -x509 -nodes -days 365 -newkey rsa:1024 -keyout mycert.pem -out mycert.pem

#Compile the ssl_c_client : gcc -Wall -o ssl_c_client  ssl_c_client.c -L/usr/lib -lssl -lcrypto
#Run :   ./ssl_c_client <host_name> <port_number>

#sudo ./ssl_c_server  8081

#Note: In above command 8081 is the port number.

#After that, we will run ssl_c_client using the below command and send the XML request.

#./ssl_c_client  127.0.0.1 8081


