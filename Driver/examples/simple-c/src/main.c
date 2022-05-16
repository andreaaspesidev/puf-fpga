#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/**
 * Reads a challenge from the tero device, then asks another challenge and read again
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

int change_challenge(unsigned int new_challenge_num) {
    FILE* device;
    unsigned int written = 0;
    if ((device = fopen(TERO_DEVICE, "w"))) {
        written = fprintf(device, "%d", new_challenge_num);
        fclose(device);
    }
    return written > 0;
}

int wait_for_challenge_num(unsigned int challenge_num, char* challenge_id) {
    unsigned int current_num = 0;
    // Very poor implementation, just for demostration purposes
    while(read_challenge(&current_num, challenge_id)) {
        if (current_num == challenge_num) {
            return 1;
        }
        // If data not ready, force sleep
        sleep(1);
    }
    return 0;
}

int main(int argc, char * argv[]) {
    unsigned int challenge_number = 0;
    unsigned int requested_number = 0;
    char buffer[MAX_BUFFER_SIZE];
    // Read the current challenge
    if (!read_challenge(&challenge_number, buffer)){
        return 1;
    }
    printf("Current Challenge: %d\n", challenge_number);
    printf("Associated ID: %s\n", buffer);

    printf("Insert a challenged to be requested: ");
    scanf("%d", &requested_number);
    // Requeste the challenge
    if (!change_challenge(requested_number)){
        return 1;
    }
    // Wait for the new data
    if (wait_for_challenge_num(requested_number, buffer)){
        printf("Challenge: %d\n", requested_number);
        printf("Associated ID: %s\n", buffer);
    }
    return 0;
}