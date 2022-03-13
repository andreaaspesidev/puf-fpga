#include <linux/spinlock.h>
#include <linux/kfifo.h>
#include <linux/kernel.h>
#include <linux/usb.h>

// Defines
#define PUF_FREQUENCIES     1280
#define LOOP_TYPES  8
#define BATCHES_NUM 80

// Enums
typedef enum PUF_DRIVER_STATUS {
    DRIVER_INITIALIZING = 0,
    DRIVER_AUTH_SENT = 1,
    DRIVER_AUTH_OK = 2,
    DRIVER_WAITING_FREQS = 3,
    DRIVER_PROCESSING_FREQS = 4,
    DRIVER_ERROR = 5
} PUF_DRIVER_STATUS;

// Structures
typedef struct puf_data {
    /* Driver status */
    PUF_DRIVER_STATUS status;                       // Driver FSM status
    unsigned int selected_challenge;                // Active challenge
    char response_id[BATCHES_NUM+1]; // Add 1 bit for the terminator

    /* Useful pointers */
    struct usb_device *	udev;
    
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
    unsigned int batches[BATCHES_NUM][PUF_FREQUENCIES/BATCHES_NUM]; // Buffer for second conversion
} puf_data_t;