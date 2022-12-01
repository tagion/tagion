
EXTRAS_CERT?=mycert.pem
BIN?=$(DBIN)

EXTRAS_SSL?=$(BDD)/extras/ssl/

sslextras: $(DBIN)/ssl_client $(DBIN)/ssl_server 

$(DBIN)/%: $(BDD)/extras/ssl/%.c
	gcc -g -o $@ $< -lssl -lcrypto

cert: $(EXTRAS_CERT)

%.pem:
	openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout $(EXTRAS_CERT) -out $(EXTRAS_CERT)

clean-sslextras:
	rm -f ssl_client ssl_server



