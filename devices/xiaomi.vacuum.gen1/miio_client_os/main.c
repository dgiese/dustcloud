/*
 * miio_client_os
 * An open source implementation of the miio_client, which is used by
 * the xiaomi vaccum robots
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#include <gcrypt.h>

#include "lib/cJSON/cJSON.h"

#define COUNT_OF(x)                                                            \
  ((sizeof(x) / sizeof(0 [x])) / ((size_t)(!(sizeof(x) % sizeof(0 [x])))))

int main(void);
void accept_local_server(void);
int calc_key_id(unsigned char *key, unsigned char *iv);
int decrypt_payload_inplace(const unsigned char *const key, size_t key_size,
                            const unsigned char *const iv, size_t iv_size,
                            unsigned char *payload, size_t payload_size);
int encrypt_payload_inplace(const unsigned char *const key, size_t key_size,
                            const unsigned char *const iv, size_t iv_size,
                            unsigned char *payload, size_t payload_size);
void exit_programm(void);
uint32_t get_robot_stamp(void);
bool is_provisioned(void);
void print_bin_array(unsigned char *var, size_t length);
void print_gcry_error(gcry_error_t e);
void process_global_message(void);
void process_local_client(size_t client_socket_idx);
int read_internal_info(cJSON *payload_json);
int read_token(cJSON *payload_json);
int read_device_id(cJSON *payload_json);
int request_device_id(void);
int request_token(void);
void setup_server_sockets(void);
void signalhandler(int signum);

// save the last ids and addresses in a map
struct socketaddr_map_item {
  int id;
  struct sockaddr_in address;
};
struct socketaddr_map_item socketaddr_map[10];
size_t socketaddr_map_newest_item = 0;

// todo use real token an device id
static unsigned char robot_token[16] = {0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f,
                                        0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f,
                                        0x7f, 0x7f, 0x7f, 0x7f};
static bool robot_token_valid = true; // todo
static uint32_t robot_device_id = 0xafafafaf;
static bool robot_device_id_valid = false;

// sockets
static int local_server_socket;
static int global_server_socket;
static int local_client_sockets[10];
static size_t local_client_sockets_in_use = 0;
static int local_client_socket_internal = -1;

// local pipe file handler
static int pipefd[2];

unsigned char buffer[1024];

int main(void) {
  // signal handler for sigint
  signal(SIGINT, signalhandler);
  signal(SIGTERM, signalhandler);

  // "self-pipe trick"
  // create pipe to be used to interrupt select call incase of a signal
  if (pipe(pipefd) == -1) {
    printf("Failed to create pipe.");
  }

  // create server sockets, bind and listen
  setup_server_sockets();

  for (size_t i = 0; i < COUNT_OF(local_client_sockets); i++) {
    local_client_sockets[i] = -1;
  }

  // handle acitivity
  while (1) {
    if (!robot_device_id_valid && local_client_socket_internal > -1) {
      printf("Requesting device id.\n");
      request_device_id();
    } else if (!robot_token_valid && local_client_socket_internal > -1) {
      printf("Requesting token.\n");
      // request_token();
    }

    // file discriptor set for the sockets and the pipe
    fd_set readfds;

    // highest-numbered file descriptor
    int maxfd = local_server_socket;
    if (global_server_socket > maxfd) {
      maxfd = local_server_socket;
    }
    if (local_client_socket_internal > maxfd) {
      maxfd = local_client_socket_internal;
    }
    if (pipefd[0] > maxfd) {
      maxfd = pipefd[0];
    }

    // reset the file discriptor set and add file discriptors
    FD_ZERO(&readfds);
    FD_SET(pipefd[0], &readfds);
    FD_SET(local_server_socket, &readfds);
    FD_SET(global_server_socket, &readfds);
    FD_SET(local_client_socket_internal, &readfds);
    for (size_t i = 0; i < COUNT_OF(local_client_sockets); i++) {
      int client_socket = local_client_sockets[i];
      if (client_socket >= 0) {
        FD_SET(client_socket, &readfds);
      }
      // update heighest file discriptor
      if (client_socket > maxfd) {
        maxfd = client_socket;
      }
    }

    // wait for activity
    select(maxfd + 1, &readfds, NULL, NULL, NULL);
    if (FD_ISSET(pipefd[0], &readfds)) {
      // self pipe handler was called (signal received)
      break;
    }
    if (FD_ISSET(local_server_socket, &readfds)) {
      accept_local_server();
    }
    if (FD_ISSET(global_server_socket, &readfds)) {
      process_global_message();
    }
    if (FD_ISSET(local_client_socket_internal, &readfds)) {
      ssize_t ret =
          read(local_client_socket_internal, buffer, sizeof(buffer) - 1);
      if (ret < 0) {
        perror("Couldn't read client socket");
        close(local_client_socket_internal);
        local_client_socket_internal = -1;
      } else if (ret == 0) {
        // client disconnected
        printf("local client internal disconnected.\n");
        close(local_client_socket_internal);
        local_client_socket_internal = -1;
      } else {
        // ignore
        if (buffer[ret - 1] != '\0') {
          buffer[ret] = '\0';
        }
        printf("Ingoring message from internal:\n");
        printf("%s\n", buffer);
      }
    }
    for (size_t i = 0; i < COUNT_OF(local_client_sockets); i++) {
      if (FD_ISSET(local_client_sockets[i], &readfds)) {
        // activity on client socket
        process_local_client(i);
      }
    }
  }

  exit_programm();
}

void accept_local_server(void) {
  struct sockaddr_in new_socket_addr;
  socklen_t sockaddr_in_size = sizeof(struct sockaddr_in);
  int new_socket =
      accept(local_server_socket, (struct sockaddr *)&new_socket_addr,
             &sockaddr_in_size);
  if (new_socket == -1) {
    perror("Couldn't accept socket");
    return;
  }

  // add new socket to client sockets if free space
  if (local_client_sockets_in_use < COUNT_OF(local_client_sockets)) {
    for (size_t i = 0; i < COUNT_OF(local_client_sockets); i++) {
      if (local_client_sockets[i] == -1) {
        local_client_sockets[i] = new_socket;
        local_client_sockets_in_use++;
        printf("Local client connected\n");
        break;
      }
    }
  } else {
    // can't handle new socket
    if (close(new_socket) == -1) {
      perror("Couldn't close socket");
    }
  }
}

int calc_key_id(unsigned char *key, unsigned char *iv) {
  size_t md5size = gcry_md_get_algo_dlen(GCRY_MD_MD5);
  gcry_md_hd_t hd;
  gcry_error_t e;
  e = gcry_md_open(&hd, GCRY_MD_MD5, 0);
  if (e) {
    print_gcry_error(e);
    return -1;
  }
  gcry_md_write(hd, robot_token, sizeof(robot_token));
  memcpy(key, gcry_md_read(hd, 0), gcry_md_get_algo_dlen(GCRY_MD_MD5));
  gcry_md_close(hd);

  char key_and_token[md5size + sizeof(robot_token)];
  memcpy(key_and_token, key, md5size);
  memcpy(&key_and_token[md5size], robot_token, sizeof(robot_token));

  e = gcry_md_open(&hd, GCRY_MD_MD5, 0);
  if (e) {
    print_gcry_error(e);
    return -1;
  }
  gcry_md_write(hd, key_and_token, sizeof(key_and_token));
  memcpy(iv, gcry_md_read(hd, 0), gcry_md_get_algo_dlen(GCRY_MD_MD5));
  gcry_md_close(hd);

  return 0;
}

int decrypt_payload_inplace(const unsigned char *const key, size_t key_size,
                            const unsigned char *const iv, size_t iv_size,
                            unsigned char *payload, size_t payload_size) {
  gcry_error_t e;
  gcry_cipher_hd_t cipher_h;
  e = gcry_cipher_open(&cipher_h, GCRY_CIPHER_AES128, GCRY_CIPHER_MODE_CBC, 0);
  if (e) {
    print_gcry_error(e);
    return -1;
  }
  e = gcry_cipher_setkey(cipher_h, key, key_size);
  if (e) {
    print_gcry_error(e);
    return -1;
  }
  e = gcry_cipher_setiv(cipher_h, iv, iv_size);
  if (e) {
    print_gcry_error(e);
    return -1;
  }
  e = gcry_cipher_decrypt(cipher_h, payload, payload_size, NULL, 0);
  if (e) {
    print_gcry_error(e);
    return -1;
  }
  gcry_cipher_close(cipher_h);

  return 0;
}

int encrypt_payload_inplace(const unsigned char *const key, size_t key_size,
                            const unsigned char *const iv, size_t iv_size,
                            unsigned char *payload, size_t payload_size) {
  gcry_error_t e;
  gcry_cipher_hd_t cipher_h;
  e = gcry_cipher_open(&cipher_h, GCRY_CIPHER_AES128, GCRY_CIPHER_MODE_CBC, 0);
  if (e) {
    print_gcry_error(e);
    return -1;
  }
  e = gcry_cipher_setkey(cipher_h, key, key_size);
  if (e) {
    print_gcry_error(e);
    return -1;
  }
  e = gcry_cipher_setiv(cipher_h, iv, iv_size);
  if (e) {
    print_gcry_error(e);
    return -1;
  }
  e = gcry_cipher_encrypt(cipher_h, payload, payload_size, NULL, 0);
  if (e) {
    print_gcry_error(e);
    return -1;
  }
  gcry_cipher_close(cipher_h);
  return 0;
}

void exit_programm(void) {
  printf("Closing all sockets.\n");

  close(local_server_socket);
  close(global_server_socket);
  for (size_t i = 0; i < COUNT_OF(local_client_sockets); i++) {
    int client_socket = local_client_sockets[i];
    if (client_socket > -1) {
      close(client_socket);
    }
  }

  exit(EXIT_SUCCESS);
}

int request_device_id(void) {
  char command[] =
      "{\"method\":\"_internal.request_dinfo\",\"params\":\"/mnt/data/miio/\"}";
  printf("sending: %s\n", command);
  if (send(local_client_socket_internal, command, sizeof(command), 0) == -1) {
    perror("Couldn't request internal info");
    close(local_client_socket_internal);
    local_client_socket_internal = -1;
    return -1;
  }
  return 0;
}

int request_token(void) {
  // not sure how this is supposed to work
  char command[] = "{\"method\":\"_internal.request_dtoken\",\"params\":{"
                   "\"dir\":\"/mnt/data/miio/"
                   "\",\"ntoken\":\"0000000000000000\"}";
  printf("sending: %s\n", command);
  if (send(local_client_socket_internal, command, sizeof(command), 0) == -1) {
    perror("Couldn't request token");
    close(local_client_socket_internal);
    local_client_socket_internal = -1;
    return -1;
  }
  return 0;
}

int read_internal_info(cJSON *payload_json) {
  if (read_device_id(payload_json) == 0) {
    return 0;
  } else if (read_token(payload_json) == 0) {
    return 0;
  }
  return -1;
}

int read_device_id(cJSON *payload_json) {
  // read json
  cJSON *method = cJSON_GetObjectItemCaseSensitive(payload_json, "method");
  if (cJSON_IsString(method) && (method->valuestring != NULL)) {
    char value[] = "_internal.response_dinfo";
    if (strncmp(method->valuestring, value, strlen(value)) != 0) {
      fprintf(stderr, "Received method is not _internal.response_dinfo\n.");
      return -1;
    }
  }
  cJSON *params = cJSON_GetObjectItemCaseSensitive(payload_json, "params");
  if (!cJSON_IsObject(params)) {
    fprintf(stderr, "No params\n.");
    return -1;
  }
  cJSON *did = cJSON_GetObjectItemCaseSensitive(params, "did");
  if (!cJSON_IsNumber(did)) {
    fprintf(stderr, "Device id wasn't a numer.\n");
    return -1;
  }
  printf("Device id received\n");
  robot_device_id = did->valueint;
  robot_device_id_valid = true;
  return 0;
}

int read_token(cJSON *payload_json) {
  // read json
  cJSON *method = cJSON_GetObjectItemCaseSensitive(payload_json, "method");
  if (cJSON_IsString(method) && (method->valuestring != NULL)) {
    char value[] = "_internal.response_dtoken";
    if (strncmp(method->valuestring, value, strlen(value)) != 0) {
      fprintf(stderr, "Received method is not _internal.response_dtoken.\n");
      return -1;
    }
  }
  cJSON *params = cJSON_GetObjectItemCaseSensitive(payload_json, "params");
  if (cJSON_IsString(method) && (method->valuestring != NULL)) {
    fprintf(stderr, "No device token received\n.");
    return -1;
  }
  if (strlen(params->valuestring) != 16) {
    fprintf(stderr, "Received wrong token size\n.");
    return -1;
  }
  printf("Token received\n");
  memcpy(robot_token, params->valuestring, COUNT_OF(robot_token));
  robot_token_valid = true;
  return 0;
}

uint32_t get_robot_stamp(void) { return (uint32_t)time(NULL); }

bool is_provisioned(void) {
  return (access("/mnt/data/miio/wifi.conf", F_OK) == 0);
}

void print_bin_array(unsigned char *var, size_t length) {
  for (size_t i = 0; i < length; i++) {
    printf("%02x", var[i]);
  }
  printf("\n");
}

void print_gcry_error(gcry_error_t e) {
  fprintf(stderr, "Failure: %s/%s\n", gcry_strsource(e), gcry_strerror(e));
}

void process_global_message(void) {
  struct sockaddr_in addr;

  socklen_t sockaddr_in_size = sizeof(struct sockaddr_in);
  ssize_t length = recvfrom(global_server_socket, buffer, sizeof(buffer), 0,
                            (struct sockaddr *)&addr, &sockaddr_in_size);
  if (length < 0) {
    perror("Couldn't receive from socket");
    return;
  } else if (length < 0x20) {
    fprintf(stderr, "Received package is too small!\n");
    return;
  }
  if ((size_t)length > sizeof(buffer)) {
    fprintf(stderr, "Received package is too big!\n");
    return;
  }

  if (!robot_device_id_valid) {
    fprintf(stderr, "No valid robot device id!\n");
    return;
  }

  if (!robot_token_valid) {
    fprintf(stderr, "No valid robot token!\n");
    return;
  }

  // decode package
  if ((buffer[0] != 0x21) || (buffer[1] != 0x31)) {
    fprintf(stderr, "Magic number is wrong!\n");
    return;
  }

  uint16_t packet_length = ntohs(*((uint16_t *)&buffer[2]));
  if (packet_length != length) {
    fprintf(stderr, "Package length is wrong!\n");
    return;
  }

  unsigned char *unknown1_loc = &buffer[4];
  uint32_t unknown1 = ntohl(*((uint32_t *)unknown1_loc));

  unsigned char *device_id_loc = &buffer[8];
  uint32_t device_id = ntohl(*((uint32_t *)device_id_loc));

  unsigned char *stamp_loc = &buffer[12];
  uint32_t stamp = ntohl(*((uint32_t *)stamp_loc));

  unsigned char *md5_loc = &buffer[16];

  unsigned char *payload_loc = &buffer[0x20];
  size_t payload_size = length - 0x20;

  if ((packet_length == 0x0020) && (unknown1 == 0xffffffff) &&
      (device_id == 0xffffffff) && (stamp == 0xffffffff)) {
    // must be a discover package
    printf("Received discovery package.\n");

    // insert data into buffer
    if (!is_provisioned()) {
      memcpy(md5_loc, robot_token, sizeof(robot_token));
    }
    uint32_t robot_device_id_n = htonl(robot_device_id);
    memcpy(device_id_loc, &robot_device_id_n, sizeof(robot_device_id));
    uint32_t stamp = htonl(get_robot_stamp());
    memcpy(stamp_loc, &stamp, sizeof(stamp));
    memset(unknown1_loc, 0, 4);

    // send answer
    if (sendto(global_server_socket, buffer, packet_length, 0,
               (struct sockaddr *)&addr, sizeof(struct sockaddr)) == -1) {
      perror("Failed to send handshake answer");
      return;
    }
  } else {
    // received normal package
    // check stamp if timestamp is close enough
    uint32_t robot_stamp = get_robot_stamp();
    if (stamp + 2 <= robot_stamp || stamp - 2 >= robot_stamp) {
      fprintf(stderr, "Package time stamp is wrong!\n");
      return;
    }

    // check device_id
    if (device_id != robot_device_id) {
      fprintf(stderr, "Package device id is wrong (received: %" PRIu16
                      ", should be: %" PRIu16 ")!\n",
              device_id, robot_device_id);
      return;
    }

    // check md5
    gcry_error_t e;
    gcry_md_hd_t hd;
    e = gcry_md_open(&hd, GCRY_MD_MD5, 0);
    if (e) {
      print_gcry_error(e);
      return;
    }
    gcry_md_write(hd, buffer, 16);
    gcry_md_write(hd, robot_token, sizeof(robot_token));
    gcry_md_write(hd, payload_loc, payload_size);
    if (memcmp(md5_loc, gcry_md_read(hd, 0),
               gcry_md_get_algo_dlen(GCRY_MD_MD5))) {
      fprintf(stderr, "MD5 wrong!");
      gcry_md_close(hd);
      return;
    }
    gcry_md_close(hd);

    // get key and initialization vector
    unsigned char key[gcry_md_get_algo_dlen(GCRY_MD_MD5)];
    unsigned char iv[gcry_md_get_algo_dlen(GCRY_MD_MD5)];
    if (calc_key_id(key, iv) == -1) {
      return;
    }

    // print_bin_array(key, sizeof(key));
    // print_bin_array(iv, sizeof(iv));

    // decrypt payload
    decrypt_payload_inplace(key, sizeof(key), iv, sizeof(iv), payload_loc,
                            payload_size);

    // unpad
    payload_size -= payload_loc[payload_size - 1];

    // ensure that string is terminated
    if (payload_loc[payload_size - 1] != '\0') {
      payload_size++;
      payload_loc[payload_size - 1] = '\0';
    }

    cJSON *payload_json = cJSON_Parse((char *)payload_loc);
    if (payload_json == NULL) {
      fprintf(stderr, "JSON parse error.\n");
      return;
    }
    cJSON *method = cJSON_GetObjectItemCaseSensitive(payload_json, "method");
    if (cJSON_IsString(method) && (method->valuestring != NULL)) {
      char internal[] = "_internal.";
      if (strncmp(method->valuestring, internal, strlen(internal)) == 0) {
        fprintf(stderr, "Skipping _internal messages from global client.\n");
        return;
      }
    }
    cJSON *id = cJSON_GetObjectItemCaseSensitive(payload_json, "id");
    if (!cJSON_IsNumber(id)) {
      fprintf(stderr, "Invalid Payload id.\n");
      return;
    }
    int payload_id = id->valueint;
    if (payload_id < 0) {
      fprintf(stderr, "Payload id is negative.\n");
      return;
    }
    cJSON_Delete(payload_json);

    // add address to map
    if (socketaddr_map_newest_item == 0) {
      socketaddr_map_newest_item = COUNT_OF(socketaddr_map) - 1;
    } else {
      socketaddr_map_newest_item--;
    }
    socketaddr_map[socketaddr_map_newest_item].id = payload_id;
    socketaddr_map[socketaddr_map_newest_item].address = addr;

    // send to all local clients
    for (size_t i = 0; i < COUNT_OF(local_client_sockets); i++) {
      int client_socket = local_client_sockets[i];
      if (client_socket > 0) {
        if (send(client_socket, payload_loc, payload_size, 0) == -1) {
        }
      }
    }
  }
}

void process_local_client(size_t client_socket_idx) {
  int client_socket = local_client_sockets[client_socket_idx];
  unsigned char *payload_loc = &buffer[0x20];
  ssize_t payload_size = sizeof(buffer) - 0x20;
  payload_size = read(client_socket, payload_loc, payload_size - 1);
  if (payload_size < 0) {
    perror("Couldn't read client socket");
    close(client_socket);
    local_client_sockets[client_socket_idx] = -1;
    local_client_sockets_in_use--;
    return;
  } else if (payload_size == 0) {
    // client disconnected
    printf("Local client disconnected.\n");
    close(client_socket);
    local_client_sockets[client_socket_idx] = -1;
    local_client_sockets_in_use--;
    return;
  }

  // ensure zero padding
  if (payload_loc[payload_size] != '\0') {
    payload_loc[payload_size] = '\0';
    payload_size++;
  }

  printf("Received from local client:\n");
  printf("%s\n", payload_loc);

  // read payload
  cJSON *payload_json = cJSON_Parse((char *)payload_loc);
  if (payload_json == NULL) {
    fprintf(stderr, "JSON parse error\n");
    return;
  }
  cJSON *method = cJSON_GetObjectItemCaseSensitive(payload_json, "method");

  if (cJSON_IsString(method) && (method->valuestring != NULL)) {
    char value[] = "_internal.hello";
    if (strncmp(method->valuestring, value, strlen(value)) == 0) {
      printf("got _internal.hello\n");
      // move this socket
      local_client_socket_internal = client_socket;
      local_client_sockets[client_socket_idx] = -1;
      local_client_sockets_in_use--;
      return;
    }
  }
  if (cJSON_IsString(method) && (method->valuestring != NULL)) {
    char internal[] = "_internal.";
    if (strncmp(method->valuestring, internal, strlen(internal)) == 0) {
      printf("Reading _internal message\n");
      if (read_internal_info(payload_json) != 0) {
        fprintf(stderr, "Error reading _internal message!\n");
      }
      return;
    }
  }
  cJSON *id = cJSON_GetObjectItemCaseSensitive(payload_json, "id");
  if (!cJSON_IsNumber(id)) {
    fprintf(stderr, "Invalid payload id.\n");
    return;
  }
  int payload_id = id->valueint;
  if (payload_id < 0) {
    fprintf(stderr, "Payload id is negative.\n");
    return;
  }
  cJSON_Delete(payload_json);

  // build package
  // magic bytes
  buffer[0] = 0x21;
  buffer[1] = 0x31;

  // package size
  uint16_t packet_size = payload_size + 0x20;
  *((uint16_t *)&buffer[2]) = htons(packet_size);

  // unknown
  *((uint32_t *)&buffer[4]) = htonl(0);

  *((uint32_t *)&buffer[8]) = htonl(robot_device_id);

  // stamp
  *((uint32_t *)&buffer[12]) = htonl(get_robot_stamp());

  // padding
  size_t to_pad = 16 - ((packet_size + 1) % 16) + 1;
  if (to_pad > sizeof(buffer) - packet_size) {
    fprintf(stderr, "buffer too small to add padding");
    return;
  }
  for (size_t i = packet_size; i < packet_size + to_pad; i++) {
    buffer[i] = to_pad;
  }
  packet_size += to_pad;
  payload_size += to_pad;

  // get key and iv
  unsigned char key[gcry_md_get_algo_dlen(GCRY_MD_MD5)];
  unsigned char iv[gcry_md_get_algo_dlen(GCRY_MD_MD5)];
  if (calc_key_id(key, iv) == -1) {
    return;
  }

  // print_bin_array(key, sizeof(key));
  // print_bin_array(iv, sizeof(iv));

  // encrypt
  if (encrypt_payload_inplace(key, sizeof(key), iv, sizeof(iv), payload_loc,
                              payload_size) == -1) {
    return;
  }

  // calculate md5
  gcry_error_t e;
  unsigned char *md5_loc = &buffer[16];
  gcry_md_hd_t hd;
  e = gcry_md_open(&hd, GCRY_MD_MD5, 0);
  if (e) {
    print_gcry_error(e);
    return;
  }
  gcry_md_write(hd, buffer, 16);
  gcry_md_write(hd, robot_token, sizeof(robot_token));
  gcry_md_write(hd, payload_loc, payload_size);
  memcpy(md5_loc, gcry_md_read(hd, 0), gcry_md_get_algo_dlen(GCRY_MD_MD5));
  gcry_md_close(hd);

  // send to newest client with matching id
  size_t socketaddr_map_oldest_item =
      (socketaddr_map_newest_item + 1) % COUNT_OF(socketaddr_map);
  for (size_t i = socketaddr_map_newest_item; i != socketaddr_map_oldest_item;
       i = (i + 1) % COUNT_OF(socketaddr_map)) {
    if (socketaddr_map[i].id == payload_id) {
      if (sendto(global_server_socket, buffer, packet_size, 0,
                 (struct sockaddr *)&socketaddr_map[i].address,
                 sizeof(struct sockaddr)) == -1) {
        perror("Couldn't forward local client package");
      }
    }
  }
}

void setup_server_sockets(void) {
  local_server_socket = socket(AF_INET, SOCK_STREAM, 0);
  struct sockaddr_in local_server_addr = {.sin_family = AF_INET,
                                          .sin_addr.s_addr =
                                              htonl(INADDR_LOOPBACK),
                                          .sin_port = htons(54322)};
  global_server_socket = socket(AF_INET, SOCK_DGRAM, 0);
  struct sockaddr_in global_server_addr = {.sin_family = AF_INET,
                                           .sin_addr.s_addr = htonl(INADDR_ANY),
                                           .sin_port = htons(54321)};

  if (bind(local_server_socket, (struct sockaddr *)&local_server_addr,
           sizeof(struct sockaddr)) != 0) {
    perror("Couldn't bind local server socket");
    exit_programm();
  }
  if (bind(global_server_socket, (struct sockaddr *)&global_server_addr,
           sizeof(struct sockaddr)) != 0) {
    perror("Couldn't bind global server socket");
    exit_programm();
  }

  if (listen(local_server_socket, 3) != 0) {
    perror("Can't listen to local socket");
    exit_programm();
  }
}

void signalhandler(int signum) {
  (void)signum;
  printf("SIGINT or SIGTERM received.\n");
  write(pipefd[1], "x", 1);
}
