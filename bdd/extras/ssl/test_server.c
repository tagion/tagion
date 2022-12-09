#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>
#include <stdio.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <errno.h>

int guard(int n, char * err) { if (n == -1) { perror(err); exit(1); } return n; }

int main() {
  int listen_socket_fd = guard(socket(AF_INET, SOCK_STREAM, 0), "could not create TCP listening socket");
  int flags = guard(fcntl(listen_socket_fd, F_GETFL), "could not get flags on TCP listening socket");
  char buf[1024];
  int size;

  guard(fcntl(listen_socket_fd, F_SETFL, flags | O_NONBLOCK), "could not set TCP listening socket to be non-blocking");
  struct sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(8080);
  addr.sin_addr.s_addr = htonl(INADDR_ANY);
  guard(bind(listen_socket_fd, (struct sockaddr *) &addr, sizeof(addr)), "could not bind");
  guard(listen(listen_socket_fd, 100), "could not listen");
  
  for (;;) {
    int client_socket_fd = accept(listen_socket_fd, NULL, NULL);
    if (client_socket_fd == -1) {
      if (errno == EWOULDBLOCK) {
        printf("No pending connections; sleeping for one second.\n");
        sleep(1);
      } else {
        perror("error when accepting connection");
        exit(1);
      }
    } else {      
      size = recv(client_socket_fd, &buf, sizeof(buf), 0);
      buf[size] = '\0';    
      printf("Got a connection; writing '%s' then closing.\n", &buf);
      send(client_socket_fd, &buf, size, 0);
      close(client_socket_fd);
    }
  }
  return EXIT_SUCCESS;
}