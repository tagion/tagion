#include "openssl/err.h"
#include "openssl/ssl.h"
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <unistd.h>

#include <arpa/inet.h>
#include <malloc.h>
#include <resolv.h>
#include <string.h>
#include <sys/types.h>

int guard(int n, char *err) {
  if (n == -1) {
    perror(err);
    exit(1);
  }
  return n;
}

void perror_die(char *msg) {
  perror(msg);
  exit(EXIT_FAILURE);
}

void make_socket_non_blocking(int sockfd) {
  int flags = fcntl(sockfd, F_GETFL, 0);
  if (flags == -1) {
    perror_die("fcntl F_GETFL");
  }

  if (fcntl(sockfd, F_SETFL, flags | O_NONBLOCK) == -1) {
    perror_die("fcntl F_SETFL O_NONBLOCK");
  }
}


int verbose = 0;
long select_timeout = 5; // seconds
/// host, port, keyfile containing pub and priv key
int main(int count, char *Argc[]) {
  printf("host: %s, port: %s, cert: %s", Argc[1], Argc[2], Argc[3]);
  SSL_CTX *ctx;
  int server;
  char *portnum;
  fd_set set;
  struct timeval timeout;
  //  int client_socket_fd;
  //  struct sockaddr client_name;
  //  int client_name_len;
  if (count < 2) {
    printf("Usage: %s <portnum> [<cert-file>]\n", Argc[1]);
    exit(0);
  }
  SSL_library_init();
  portnum = Argc[2];

  // initserver ctx
//  SSL_METHOD *method;
  OpenSSL_add_all_algorithms();     /* load & register all cryptos, etc. */
  SSL_load_error_strings();         /* load all error messages */
  const SSL_METHOD* method = TLS_server_method(); /* create new server-method instance */
  ctx = SSL_CTX_new(method);        /* create new context from method */
  if (ctx == NULL) {
    ERR_print_errors_fp(stderr);
    abort();
  }
  // load certificates

  /* set the local certificate from CertFile */
  if (SSL_CTX_use_certificate_file(ctx, Argc[3], SSL_FILETYPE_PEM) <= 0) {
    ERR_print_errors_fp(stderr);
    abort();
  }
  /* set the private key from KeyFile (may be the same as CertFile) */
  if (SSL_CTX_use_PrivateKey_file(ctx, Argc[3], SSL_FILETYPE_PEM) <= 0) {
    ERR_print_errors_fp(stderr);
    abort();
  }
  /* verify private key */
  if (!SSL_CTX_check_private_key(ctx)) {
    fprintf(stderr, "Private key does not match the public certificate\n");
    abort();
  }

  int listen_socket_fd = guard(socket(AF_INET, SOCK_STREAM, 0),
                               "could not create TCP listening socket");
  int flags = guard(fcntl(listen_socket_fd, F_GETFL),
                    "could not get flags on TCP listening socket");
  char buf[1024];
  int size; // size of message
  int fdset_max = listen_socket_fd;

  guard(fcntl(listen_socket_fd, F_SETFL, flags | O_NONBLOCK),
        "could not set TCP listening socket to be non-blocking");
  //  make_socket_non_blocking(listen_socket_fd);

  struct sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(atoi(Argc[2]));
  addr.sin_addr.s_addr = htonl(INADDR_ANY);
  guard(bind(listen_socket_fd, (struct sockaddr *)&addr, sizeof(addr)),
        "could not bind port");
  guard(listen(listen_socket_fd, 5), "could not listen");

  fd_set readfds_master;
  FD_ZERO(&readfds_master); /* clear the set */

  fd_set writefds_master;
  FD_ZERO(&writefds_master); /* clear the set */

  FD_SET(listen_socket_fd,
         &readfds_master); /* add our file descriptor to the set */

  for (;;) {
    fd_set readfds = readfds_master;
    fd_set writefds = writefds_master;

    int rv;

    timeout.tv_sec = select_timeout;
    timeout.tv_usec = 0;

    int nready = select(fdset_max + 1, &readfds, NULL, NULL, &timeout);
    if (nready > 1) {
      printf("nready=%d\n", nready);
    }
    if (rv == -1) {
      perror_die("Error and die"); /* an error occurred */
    } else if (rv == 0) {
      printf("timeout occurred (%ld second) \n",
             select_timeout); /* a timeout occurred */
      return 1;
    }

    for (int fd = 0; fd <= fdset_max && (nready > 0); fd++) {
      char buf[1024] = {0};
      if (FD_ISSET(fd, &readfds)) {
        nready--;
        if (fd == listen_socket_fd) {
          struct sockaddr_in peer_addr;
          socklen_t peer_addr_len = sizeof(peer_addr);
          int new_fd = accept(listen_socket_fd, (struct sockaddr *)&peer_addr,
                              &peer_addr_len);
          if (new_fd < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
              // This can happen due to the nonblocking socket mode; in this
              // case don't do anything, but print a notice (since these events
              // are extremely rare and interesting to observe...)
              printf("accept returned EAGAIN or EWOULDBLOCK\n");
            } else {
              perror_die("Error accept");
            }
          } else {
            // make_socket_non_blocking(new_fd);
            if (new_fd > fdset_max) {
              if (new_fd >= FD_SETSIZE) {
                printf("socket fd (%d) >= FD_SETSIZE (%d)", new_fd, FD_SETSIZE);
                return 1;
              }
              fdset_max = new_fd;
            }
            SSL *ssl;
            ssl = SSL_new(ctx);      /* get new SSL state with context */
            SSL_set_fd(ssl, new_fd); /* set connection socket to SSL state */
            int bytes;
            rv = SSL_accept(ssl);
            if (rv < 0) {
              ERR_print_errors_fp(stderr);
              continue;
            } else {
              bytes = SSL_read(ssl, buf, sizeof(buf)); /* get request */
              buf[bytes] = '\0';
              if (verbose) printf("Client msg: \"%s\"\n", buf);
              if (bytes > 0) {
                SSL_write(ssl, buf, strlen(buf)); /* send reply */
              } else {
                ERR_print_errors_fp(stderr);
              }
            }
            SSL_shutdown(ssl);
            SSL_free(ssl); /* release SSL state */
            FD_CLR(fd, &readfds);

            close(new_fd);
            // if the message from client was EOC we break loop and
            if (strcmp(buf, "EOC") == 0) {
              goto END;
            }
            // send(client_socket_fd, &buf, size, 0);
          }
        }
      }
    }
  }
END:
  printf("Shutdown!");

  SSL_CTX_free(ctx); /* release context */
  shutdown(server, SHUT_RDWR);
  close(server); /* close server socket */
  return 0;
}
