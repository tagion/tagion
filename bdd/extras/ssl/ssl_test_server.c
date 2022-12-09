#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>
#include <stdio.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <errno.h>
#include "openssl/ssl.h"
#include "openssl/err.h"

#include <malloc.h>
#include <string.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <resolv.h>



int guard(int n, char *err)
{
	if (n == -1)
	{
		perror(err);
		exit(1);
	}
	return n;
}

/// host, port, keyfile containing pub and priv key
int main(int count, char *Argc[])
{
	printf("host: %s, port: %s, cert: %s", Argc[1], Argc[2], Argc[3]);
	SSL_CTX *ctx;
	int server;
	char *portnum;

	if (count < 2)
	{
		printf("Usage: %s <portnum> [<cert-file>]\n", Argc[1]);
		exit(0);
	}
	SSL_library_init();
	portnum = Argc[2];

	// initserver ctx
	SSL_METHOD *method;
	OpenSSL_add_all_algorithms();     /* load & register all cryptos, etc. */
	SSL_load_error_strings();         /* load all error messages */
	method = TLSv1_2_server_method(); /* create new server-method instance */
	ctx = SSL_CTX_new(method);        /* create new context from method */
	if (ctx == NULL)
	{
		ERR_print_errors_fp(stderr);
		abort();
	}
	// load certificates

	/* set the local certificate from CertFile */
	if (SSL_CTX_use_certificate_file(ctx, Argc[3], SSL_FILETYPE_PEM) <= 0)
	{
		ERR_print_errors_fp(stderr);
		abort();
	}
	/* set the private key from KeyFile (may be the same as CertFile) */
	if (SSL_CTX_use_PrivateKey_file(ctx, Argc[3], SSL_FILETYPE_PEM) <= 0)
	{
		ERR_print_errors_fp(stderr);
		abort();
	}
	/* verify private key */
	if (!SSL_CTX_check_private_key(ctx))
	{
		fprintf(stderr, "Private key does not match the public certificate\n");
		abort();
	}

	int listen_socket_fd = guard(socket(AF_INET, SOCK_STREAM, 0), "could not create TCP listening socket");
	int flags = guard(fcntl(listen_socket_fd, F_GETFL), "could not get flags on TCP listening socket");
	char buf[1024];
	int size; // size of message

	guard(fcntl(listen_socket_fd, F_SETFL, flags | O_NONBLOCK), "could not set TCP listening socket to be non-blocking");
	struct sockaddr_in addr;
	addr.sin_family = AF_INET;
	addr.sin_port = htons(atoi(Argc[2]));
	addr.sin_addr.s_addr = htonl(INADDR_ANY);
	guard(bind(listen_socket_fd, (struct sockaddr *)&addr, sizeof(addr)), "could not bind port");
	guard(listen(listen_socket_fd, 100), "could not listen");

	for (;;)
	{
		int client_socket_fd = accept(listen_socket_fd, NULL, NULL);
		SSL *ssl;

		if (client_socket_fd == -1)
		{
			if (errno == EWOULDBLOCK)
			{
				printf("No pending connections; sleeping for one second.\n");
				sleep(1);
			}
			else
			{
				perror("error when accepting connection");
				exit(1);
			}
		}
		else
		{

			ssl = SSL_new(ctx);                /* get new SSL state with context */
			SSL_set_fd(ssl, client_socket_fd); /* set connection socket to SSL state */
			char buf[1024] = {0};
			int sd, bytes;
			// size = recv(client_socket_fd, &buf, sizeof(buf), 0);
			// buf[size] = '\0';
			if (SSL_accept(ssl) == -1)
			{
				ERR_print_errors_fp(stderr);
			}
			else
			{
				// X509 *cert;
				// char *line;
				// cert = SSL_get_peer_certificate(ssl); /* Get certificates (if available) */
				// if (cert != NULL)
				// {
				//   printf("Server certificates:\n");
				//   line = X509_NAME_oneline(X509_get_subject_name(cert), 0, 0);
				//   printf("Subject: %s\n", line);
				//   free(line);
				//   line = X509_NAME_oneline(X509_get_issuer_name(cert), 0, 0);
				//   printf("Issuer: %s\n", line);
				//   free(line);
				//   X509_free(cert);
				// }
				// else {
				//   printf("No certificates.\n");
				// }

				bytes = SSL_read(ssl, buf, sizeof(buf)); /* get request */
				buf[bytes] = '\0';
				printf("Client msg: \"%s\"\n", buf);
				if (bytes > 0)
				{
					SSL_write(ssl, buf, strlen(buf)); /* send reply */
				}
				else
				{
					ERR_print_errors_fp(stderr);
				}
			}
			SSL_shutdown(ssl);
			SSL_free(ssl); /* release SSL state */

			// if the message from client was EOC we break loop and
			if (strcmp(buf, "EOC")) {
				break;
			}
			// send(client_socket_fd, &buf, size, 0);
			close(client_socket_fd);
		}
	}

	printf("Shutdown!");

	SSL_CTX_free(ctx); /* release context */
	shutdown(server, SHUT_RDWR);
	close(server); /* close server socket */
	return 0;
}