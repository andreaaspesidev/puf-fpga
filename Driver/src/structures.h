#include <linux/spinlock.h>
#include <linux/mutex.h>
#include <linux/kfifo.h>
#include <linux/kernel.h>
#include <linux/usb.h>
#include <linux/cdev.h>

// Defines
#define PUF_FREQUENCIES     160     // Number of frequencies coming from the device
//#define LOOP_TYPES  8
#define BATCHES_NUM 80              // = PUF_FREQUENCIES / 2 in this case
#define MIN_CHALLENGE 0             // Minimum challenge number. Cannot be changed as hardcoded in the device
#define MAX_CHALLENGE 119           // Maximum challenge number. Cannot be changed as hardcoded in the device
#define CHALLENGE_CHARS_SIZE 3      // Maximum length of the challenge number converted to string (log_10(119) + 1)

#define DRIVER_RESPONSE_SIZE    CHALLENGE_CHARS_SIZE + 1 + BATCHES_NUM + 2  // <challenge_num><space><challenge_response><new_line>\0

// Enums
typedef enum PUF_DRIVER_STATUS {
    DRIVER_INITIALIZING = 0,
    DRIVER_AUTH_SENT = 1,
    DRIVER_AUTH_OK = 2,
    DRIVER_WAITING_FREQS = 3,
    DRIVER_PROCESSING_FREQS = 4,
    DRIVER_RESPONSE_OK = 5,
    DRIVER_ERROR = 6
} PUF_DRIVER_STATUS;

// Structures
typedef struct puf_data {
    /* Driver status */
    atomic_t status;                       // Driver FSM status
    unsigned int selected_challenge;       // Current selected challenge

    /* Useful pointers */
    struct usb_device *	udev;

    /* Character device */
    struct mutex lock;                   // Lock used to avoid sync problems between reading/writing data on this structure
    struct cdev cdev;               // Structure used for the associated character device
    unsigned int minor;             // Minor number assigned to this device

    /* Buffers for urbs */
    char * in_buffer;               // Buffer used for sync reading
    char * out_buffer;              // Buffer used for sync writing
    
    /* Async read */
    spinlock_t  data_lock;                              // Lock used to access fifo-queues
    struct kfifo data_fifo;                             // FIFO used when reading data async
    void (*on_data_callback)(struct puf_data* data);    // Callback used when data is received async
    struct urb* in_urb;                                 // Urb used for reading (async)
    char * in_async_buffer;                             // Buffer used for async reading

    /* Worker data */
    struct work_struct worker_freqs;                                // Contains the data for controlling the worker
    unsigned char freq_bytes[PUF_FREQUENCIES*4];                    // Buffer for flushing the fifo data
    unsigned int freqs[PUF_FREQUENCIES];                            // Buffer for first conversion

    /* PUF response */
    int response_challenge;             // Challenge of the generated response (-1 when no response generated yet)
    char response_id[BATCHES_NUM+1];    // Add 1 bit for the terminator
} puf_data_t;