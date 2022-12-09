
EXTRAS_CERT?=mycert.pem
BIN?=$(DBIN)

EXTRAS_SSL?=$(BDD)/extras/ssl/

sslextras: ssl_client ssl_server ssl_test_server

#ssl_server: $(DBIN)/ssl_server

%: $(BDD)/extras/ssl/%.c
	echo $(DBIN)
	echo $@
	gcc -g -o $(DBIN)/$@ $< -lssl -lcrypto

cert: $(EXTRAS_CERT)

%.pem:
	openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout $(EXTRAS_CERT) -out $(EXTRAS_CERT)

clean-sslextras:
	rm -f ssl_client ssl_server ssl_test_server

clean: clean-sslextras


