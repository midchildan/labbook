// Based on
// - https://wiki.openssl.org/index.php/Simple_TLS_Server
// -
// https://github.com/apache/trafficserver/blob/9.2.3/iocore/net/TLSSessionResumptionSupport.cc

// Copyright OpenSSL 2024
// Contents licensed under the terms of the OpenSSL license
// See https://www.openssl.org/source/license.html for details

// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <arpa/inet.h>
#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/ssl.h>
#include <openssl/tls1.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#if OPENSSL_VERSION_MAJOR >= 3
#include <openssl/core_names.h>
#else
#define LEGACY
#endif

typedef struct {
  unsigned char name[16];
  unsigned char aes_key[16];
  unsigned char hmac_key[16];
} stek_t;

stek_t STEK;

char *MD_NAME = "sha256";
const EVP_MD *(*EVP_MD_FUNC)(void) = EVP_sha256;

bool read_stek(const char *path, stek_t *stek) {
  FILE *f = fopen(path, "r");
  if (!f) {
    return false;
  }

  bool is_read_complete = false;

  if (fread(stek->name, sizeof(stek->name), 1, f) != 1) {
    perror("Unable to read STEK name");
    goto cleanup;
  }

  if (fread(stek->aes_key, sizeof(stek->aes_key), 1, f) != 1) {
    perror("Unable to read STEK AES key");
    goto cleanup;
  }

  if (fread(stek->hmac_key, sizeof(stek->hmac_key), 1, f) != 1) {
    perror("Unable to read STEK HMAC key");
    goto cleanup;
  }

  is_read_complete = true;

cleanup:
  if (f) {
    fclose(f);
  }
  return is_read_complete;
}

int create_socket(int port) {
  struct sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(port);
  addr.sin_addr.s_addr = inet_addr("127.0.0.1");

  int s = socket(AF_INET, SOCK_STREAM, 0);
  if (s < 0) {
    perror("Unable to create socket");
    return -1;
  }

  if (bind(s, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
    perror("Unable to bind");
    return -1;
  }

  if (listen(s, 1) < 0) {
    perror("Unable to listen");
    return -1;
  }

  return s;
}

#ifndef LEGACY
int on_ticket_encrypt(SSL *ssl, unsigned char *keyname, unsigned char *iv,
                      EVP_CIPHER_CTX *cipher_ctx, EVP_MAC_CTX *hctx)
#else
int on_ticket_encrypt(SSL *ssl, unsigned char *keyname, unsigned char *iv,
                      EVP_CIPHER_CTX *cipher_ctx, HMAC_CTX *hctx)
#endif
{
  memcpy(keyname, STEK.name, sizeof(STEK.name));

  if (RAND_bytes(iv, EVP_MAX_IV_LENGTH) != 1) {
    return -1;
  }

  if (EVP_EncryptInit_ex(cipher_ctx, EVP_aes_128_cbc(), NULL, STEK.aes_key,
                         iv) != 1) {
    return -2;
  }

#ifndef LEGACY
  const OSSL_PARAM params[] = {
      OSSL_PARAM_construct_octet_string(
          OSSL_MAC_PARAM_KEY, (void *)STEK.hmac_key, sizeof(STEK.hmac_key)),
      OSSL_PARAM_construct_utf8_string(OSSL_MAC_PARAM_DIGEST, (void *)MD_NAME,
                                       0),
      OSSL_PARAM_construct_end(),
  };

  if (EVP_MAC_CTX_set_params(hctx, params) != 1) {
    return -3;
  }
#else
  if (HMAC_Init_ex(hctx, STEK.hmac_key, sizeof(STEK.hmac_key), EVP_MD_FUNC(),
                   NULL) != 1) {
    return -3;
  }
#endif

  return 1;
}

#ifndef LEGACY
int on_ticket_decrypt(SSL *ssl, unsigned char *keyname, unsigned char *iv,
                      EVP_CIPHER_CTX *cipher_ctx, EVP_MAC_CTX *hctx)
#else
int on_ticket_decrypt(SSL *ssl, unsigned char *keyname, unsigned char *iv,
                      EVP_CIPHER_CTX *cipher_ctx, HMAC_CTX *hctx)
#endif
{

  if (memcmp(keyname, STEK.name, sizeof(STEK.name)) == 0) {
    if (EVP_DecryptInit_ex(cipher_ctx, EVP_aes_128_cbc(), NULL, STEK.aes_key,
                           iv) != 1) {
      return -2;
    }

#ifndef LEGACY
    const OSSL_PARAM params[] = {
        OSSL_PARAM_construct_octet_string(
            OSSL_MAC_PARAM_KEY, (void *)STEK.hmac_key, sizeof(STEK.hmac_key)),
        OSSL_PARAM_construct_utf8_string(OSSL_MAC_PARAM_DIGEST, MD_NAME, 0),
        OSSL_PARAM_construct_end(),
    };
    if (EVP_MAC_CTX_set_params(hctx, params) != 1) {
      return -3;
    }
#else
    if (HMAC_Init_ex(hctx, STEK.hmac_key, sizeof(STEK.hmac_key), EVP_MD_FUNC(),
                     NULL) != 1) {
      return -3;
    }
#endif

#ifdef TLS1_3_VERSION
    if (SSL_version(ssl) >= TLS1_3_VERSION) {
      return 2;
    }
#endif

    return 1;
  }

  return 0;
}

#ifndef LEGACY
int on_ticket(SSL *ssl, unsigned char *keyname, unsigned char *iv,
              EVP_CIPHER_CTX *cipher_ctx, EVP_MAC_CTX *hctx, int enc)
#else
int on_ticket(SSL *ssl, unsigned char *keyname, unsigned char *iv,
              EVP_CIPHER_CTX *cipher_ctx, HMAC_CTX *hctx, int enc)
#endif
{
  if (enc) {
    return on_ticket_encrypt(ssl, keyname, iv, cipher_ctx, hctx);
  }
  return on_ticket_decrypt(ssl, keyname, iv, cipher_ctx, hctx);
}

SSL_CTX *create_context(const char *cert_path, const char *key_path) {
  const SSL_METHOD *method = TLS_server_method();
  SSL_CTX *ctx = SSL_CTX_new(method);

  if (!ctx) {
    goto error;
  }

  if (SSL_CTX_use_certificate_file(ctx, cert_path, SSL_FILETYPE_PEM) <= 0) {
    goto error;
  }

  if (SSL_CTX_use_PrivateKey_file(ctx, key_path, SSL_FILETYPE_PEM) <= 0) {
    goto error;
  }

#ifndef LEGACY
  if (SSL_CTX_set_tlsext_ticket_key_evp_cb(ctx, on_ticket) <= 0) {
    goto error;
  }
#else
  if (SSL_CTX_set_tlsext_ticket_key_cb(ctx, on_ticket) <= 0) {
    goto error;
  }
#endif

  return ctx;

error:
  ERR_print_errors_fp(stderr);
  if (!ctx) {
    SSL_CTX_free(ctx);
  }
  return NULL;
}

int main(int argc, char **argv) {
  signal(SIGPIPE, SIG_IGN);

  if (argc != 5) {
    fprintf(stderr, "ERROR: Wrong number of arguments.\n");
    return EXIT_FAILURE;
  }

  int port = atoi(argv[1]);
  const char *stek_path = argv[2];
  const char *cert_path = argv[3];
  const char *key_path = argv[4];

  if (!read_stek(stek_path, &STEK)) {
    return EXIT_FAILURE;
  }

  SSL_CTX *ctx = create_context(cert_path, key_path);
  if (!ctx) {
    return EXIT_FAILURE;
  }

  int sock = create_socket(port);
  if (sock < 0) {
    return EXIT_FAILURE;
  }

  while (true) {
    struct sockaddr_in addr;
    socklen_t len = sizeof(addr);

    int client = accept(sock, (struct sockaddr *)&addr, &len);
    if (client < 0) {
      perror("Unable to accept");
      return EXIT_FAILURE;
    }

    SSL *ssl = SSL_new(ctx);
    SSL_set_fd(ssl, client);
    SSL_set_num_tickets(ssl, 1);

    if (SSL_accept(ssl) > 0) {
      const char *reply = "Glory to mankind!\n";
      SSL_write(ssl, reply, strlen(reply));
    } else {
      ERR_print_errors_fp(stderr);
    }

    SSL_shutdown(ssl);
    SSL_free(ssl);
    close(client);
  }

  close(sock);
  SSL_CTX_free(ctx);
  return EXIT_SUCCESS;
}
