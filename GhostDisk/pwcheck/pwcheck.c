#define _XOPEN_SOURCE
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <crypt.h>

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <password> <hash>\n", argv[0]);
        return 1;
    }

    const char *pass = argv[1];
    const char *hash = argv[2];

    // Extract salt from hash (everything up to 3rd $)
    char salt[128];
    const char *p = hash;
    int dollar_count = 0;
    size_t i = 0;

    while (*p && dollar_count < 3 && i < sizeof(salt)-1) {
        salt[i++] = *p;
        if (*p == '$') dollar_count++;
        p++;
    }
    salt[i] = '\0';

    char *crypt_result = crypt(pass, salt);
    if (!crypt_result) {
        perror("crypt");
        return 1;
    }

    if (strcmp(crypt_result, hash) == 0) {
        return 0; // password correct
    } else {
        return 1; // password incorrect
    }
}

