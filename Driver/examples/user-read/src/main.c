#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/**
 * Reads a challenge from the tero device
 */

#define TERO_DEVICE "/dev/teropuf-0"
#define MAX_BUFFER_SIZE 200

int read_challenge(unsigned int * challenge_num, char* challenge_id) {
    FILE* device;
    unsigned int read = 0;
    if ((device = fopen(TERO_DEVICE, "r"))) {
        read = fscanf(device, "%d %s", challenge_num, challenge_id);
        fclose(device);
    }
    return read > 0;
}

int main(int argc, char * argv[]) {
    char challenge_id_buffer[MAX_BUFFER_SIZE];
    unsigned int challenge_num;

    // First read
    if (!read_challenge(&challenge_num, challenge_id_buffer)) {
        return 1;
    }
    printf("Current Challenge: %d\n", challenge_num);
    printf("Associated ID: %s\n", challenge_id_buffer);
    // Second read
    if (!read_challenge(&challenge_num, challenge_id_buffer)) {
        return 1;
    }
    printf("Current Challenge: %d\n", challenge_num);
    printf("Associated ID: %s\n", challenge_id_buffer);
    return 0;
}