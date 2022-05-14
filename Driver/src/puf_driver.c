#include <linux/kernel.h>
#include <linux/errno.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/workqueue.h>
#include <linux/bitops.h>
#include <linux/fs.h>

#include "ftdi_interface.h"

MODULE_AUTHOR("Andrea Aspesi <andrea1.aspesi@mail.polimi.it>");
MODULE_DESCRIPTION("TERO PUF Driver");
MODULE_LICENSE("GPL");

#define DEBUG  0   // Turn off to avoid printing

/**
 * Register driver for the device
 * --------------------------------
 */
// Defines
#define PUF_VENDOR_ID   0x0403  //FTDI_VID
#define PUF_PRODUCT_ID  0x6010  //FTDI_8U2232C_PID
// Prototypes
static int puf_probe(struct usb_interface *, const struct usb_device_id *);
static void puf_disconnect(struct usb_interface *);

// Register this driver for such vendor and product
static struct usb_device_id id_table [] = {
	{ USB_DEVICE(PUF_VENDOR_ID, PUF_PRODUCT_ID) }, //creates a struct usb_device_id that can be used to match only the specified vendor and product ID values.
	{ }                                            
};
MODULE_DEVICE_TABLE(usb, id_table);

// Register driver entry-points
static struct usb_driver puf_driver = {
	.name =		    "tero_puf_driver",
    .id_table =	    id_table,
	.probe =	    puf_probe,
	.disconnect =	puf_disconnect,
};

/**
 * Entry-points
 * --------------------------------
 */
// Prototypes
static int init_character_device(void);
static void destroy_character_device(void);

static int __init puf_driver_init(void) {
    int result;
    // Create character device setup
    result = init_character_device();
    if (!result){
        return 1;
    }
    // Register this driver with the USB subsystem
    result = usb_register(&puf_driver);
#if DEBUG
    if (result)
        printk("usb_register failed. Error number %d", result);
#endif
    return result;
}
module_init(puf_driver_init);

static void __exit puf_driver_exit(void) {
    // Deregister this driver with the USB subsystem
    usb_deregister(&puf_driver);
    // Deregister char device
    destroy_character_device();
}
module_exit(puf_driver_exit);


/**
 * Probe and disconnect function
 * --------------------------------
 */
// Prototypes
static int check_puf_jtag(struct usb_interface *);
static int check_wrong_chip_type(struct usb_device *);
static int check_wrong_endpoints(struct usb_interface *);

static puf_data_t * init_driver_structure(struct usb_interface *, struct usb_device *);
static void clear_driver_structure(struct usb_interface *);

static int puf_auth(puf_data_t*);
static int ask_frequencies(puf_data_t*, unsigned int);

static int add_character_device(puf_data_t* data);
static int remove_character_device(puf_data_t* data);


static int puf_probe(struct usb_interface *interface, const struct usb_device_id *id) {
    struct usb_device *udev = interface_to_usbdev(interface);   // Get the structure from the interface.
    puf_data_t *data = NULL;                                    // Pointer to driver data for this device
    // Ignore JTAG port
    if (check_puf_jtag(interface)){
        return -ENODEV;
    }
    // Check FTDI chip
    if (check_wrong_chip_type(udev)){
        return -ENODEV;
    }
    // Check endpoints
    if (check_wrong_endpoints(interface)){
        return -ENODEV;
    }
    // Init driver structures
    data = init_driver_structure(interface, udev);
    if (!data){
        return -ENOMEM;
    }
#if DEBUG
    printk("[PUF Driver] Data allocated!\n");
#endif
    // Configure FTDI parameters
    if (ftdi_setup_parameters(data, BAUD_115200, DATA_BITS_8, STOP_BITS_1, PARITY_NONE) == FTDI_ERROR){
        clear_driver_structure(interface);
        return -ENODEV;
    }
#if DEBUG
    printk("[PUF Driver] Port configured!\n");
#endif
    // Open serial port
    if (ftdi_open_port(data) == FTDI_ERROR) {
        clear_driver_structure(interface);
        return -ENODEV;
    }
#if DEBUG
    printk("[PUF Driver] Port opened!\n");
#endif
    // Check if puf is valid
    if (!puf_auth(data)){
        clear_driver_structure(interface);
        return -ENODEV;
    }
#if DEBUG
    printk("[PUF Driver] PUF auth ok!\n");
#endif
    // Register device pipe
    if (!add_character_device(data)){
        clear_driver_structure(interface);
        return -EFAULT;
    }
#if DEBUG
    printk("[PUF Driver] Created device for this puf!\n");
#endif
    // Ask first challenge
    ask_frequencies(data, 0);
    // Claim the device
#if DEBUG
    printk("[PUF Driver] Device claimed!\n");
#endif
    return 0;
}

static void puf_disconnect(struct usb_interface *interface) {
    // Cleanup
    puf_data_t *data = usb_get_intfdata(interface);
    remove_character_device(data);
    clear_driver_structure(interface);
#if DEBUG
    printk("[PUF Driver] Device detached!\n");
#endif
}

/**
 * PUF Communication
 * --------------------------------
 */
#define PUF_AUTH_REQUEST    '\xAA'
#define PUF_AUTH_RESPONSE   '\xAB'
static int puf_auth(puf_data_t* data){
    char buff[2];
    // Stop async receive
    ftdi_stop_async_receive(data);
    // Send auth id
    buff[0] = PUF_AUTH_REQUEST;
    buff[1] = 0;
    ftdi_sync_send(data, buff, 1, HZ*5);
    atomic_set(&data->status, DRIVER_AUTH_SENT);
    // Read auth response
    ftdi_sync_receive(data, buff, 1, HZ*5);
    if (buff[0] == PUF_AUTH_RESPONSE){
        atomic_set(&data->status, DRIVER_AUTH_OK);
        return 1;
    }
    return 0;
}

/*
static void get_2comp_indices(unsigned int challenge_num, int *i, int *j){
    // 0,1
    // ...
    // 0,15
    // 1,2
    // ...
    // 1,15
    // ...
    // 14,15
    int i_tmp, j_tmp, count;
    count = 0;
    for (i_tmp=0;i_tmp<PUF_FREQUENCIES/BATCHES_NUM;++i_tmp){
        for (j_tmp=i_tmp+1;j_tmp<PUF_FREQUENCIES/BATCHES_NUM;++j_tmp){
            ++count;
            if (count == challenge_num){
                break;
            }
        }
        if (count == challenge_num){
            break;
        } 
    }
    *i = i_tmp;
    *j = j_tmp;
}

static void generate_response_old(puf_data_t* data) {
    // Start by grouping frequencies in batches.
    // In each batch, put frequencies coming from the same type of TERO loop (8 types)
    // Split batches in order to have a total of BATCHES_NUM, but by keeping the same
    // type of loop for each batch
    int curr_type, curr_freq, curr_batch, batch_index;
    int i,j, curr_bit;
    curr_batch = 0;
    batch_index = 0;
    for (curr_type = 0; curr_type < LOOP_TYPES; ++curr_type){
        // Sample a frequency every LOOP_TYPES frequencies to stay in the same type
        for (curr_freq=curr_type; curr_freq < PUF_FREQUENCIES; curr_freq+=LOOP_TYPES){
            // freqs[curr_freq] is the next frequency of the same type of loop to add
            data->batches[curr_batch][batch_index] = data->freqs[curr_freq]; // Add this frequency
            ++batch_index;
            if (batch_index == PUF_FREQUENCIES/BATCHES_NUM) {    // Batch completed
                ++curr_batch;       // Move to next batch
                batch_index = 0;    // Restart from the beginning
            }
        }
    }
    printk("[PUF Driver] Grouped frequencies in batches\n");
    // Convert the challenge in the two compare indexes i,j for 2Comp
    data->response_challenge = data->selected_challenge;
    get_2comp_indices(data->response_challenge, &i, &j);
    printk("[PUF Driver] Generating using i=%d, j=%d\n", i,j);
    // Generate unique id, by comparing for each batch the freq in position i and j
    for (curr_bit=0;curr_bit<BATCHES_NUM;++curr_bit){
        data->response_id[curr_bit] = (data->batches[curr_bit][i] > data->batches[curr_bit][j]) ? '1' : '0';
    }
    data->response_id[curr_bit] = '\0'; // Add the terminator
    data->status = DRIVER_RESPONSE_OK;
    printk("[PUF Driver] Challenge: %d, Unique ID: %s\n", data->response_challenge, data->response_id);
}
*/

static void generate_response(puf_data_t* data) {
    // Frequencies are already grouped by hardware.
    // Here the first 160/2 frequencies must be considered as left side in the > operation, while
    // the second half are right side of the > operation.
    int curr_bit;

    // Generate response
    mutex_lock(&data->lock);
        data->response_challenge = data->selected_challenge;
        for (curr_bit=0;curr_bit<BATCHES_NUM;++curr_bit){
            data->response_id[curr_bit] = (data->freqs[curr_bit] > data->freqs[curr_bit + BATCHES_NUM]) ? '1' : '0';
        }
        data->response_id[curr_bit] = '\0'; // Add the terminator
        atomic_set(&data->status, DRIVER_RESPONSE_OK);
#if DEBUG
        printk("[PUF Driver] Challenge: %d, Unique ID: %s\n", data->response_challenge, data->response_id);
#endif
    mutex_unlock(&data->lock);
}

static void process_frequencies(struct work_struct *work){
    unsigned long flags;
    puf_data_t* data;
    int i;
    // Recover parent structure from work pointer (math on memory addresses)
    data = container_of(work, puf_data_t, worker_freqs);
#if DEBUG
    printk("[PUF Driver] Begin processing frequencies\n");
#endif
    spin_lock_irqsave(&data->data_lock, flags);
        // Move data to local buffer for direct access
        if (kfifo_out(&data->data_fifo, data->freq_bytes, PUF_FREQUENCIES*4) != PUF_FREQUENCIES*4) {
            atomic_set(&data->status, DRIVER_ERROR);
            return; // Device error
        }
    spin_unlock_irqrestore(&data->data_lock, flags);
    // Convert frequencies (big endian encoded)
    for (i = 0; i < PUF_FREQUENCIES*4; i+=4) {
        data->freqs[i/4] = 0;
        data->freqs[i/4] |= data->freq_bytes[i]    << 3*8;
        data->freqs[i/4] |= data->freq_bytes[i+1]  << 2*8;
        data->freqs[i/4] |= data->freq_bytes[i+2]  << 1*8;
        data->freqs[i/4] |= data->freq_bytes[i+3];
        //printk("[PUF Freq #%d] %02x %02x %02x %02x: %d\n", 
        //        i / 4, 
        //        data->freq_bytes[i] & 0xff, 
        //        data->freq_bytes[i+1] & 0xff, 
        //        data->freq_bytes[i+2] & 0xff, 
        //        data->freq_bytes[i+3] & 0xff, 
        //        data->freqs[i/4]);
    }
    // Process frequencies
    generate_response(data);
}

void on_puf_data(puf_data_t* data){
    //INTERRUPT_CONTEXT
    unsigned long flags;
    int bytes_received;
    // Check if the driver is waiting for data
    if (atomic_read(&data->status) != DRIVER_WAITING_FREQS){
        return; // Ignore data
    }
    // Critical section useless in this case, but present
    // to prevent possible future bugs. Currently the PUF do not
    // send additional async data apart the one asked.
    spin_lock_irqsave(&data->data_lock, flags);
        // Check fifo size.
        bytes_received = kfifo_len(&data->data_fifo);
        //printk("[PUF Driver] FIFO_SIZE: %d\n", bytes_received);
        // Is all the data arrived?
        if (bytes_received == PUF_FREQUENCIES*4){
            atomic_set(&data->status, DRIVER_PROCESSING_FREQS);
            // Initialize work
            INIT_WORK(&data->worker_freqs, process_frequencies);
            // Schedule work
            schedule_work(&data->worker_freqs);
#if DEBUG
            printk("[PUF Driver] Scheduled frequencies processing\n");
#endif
        }
    spin_unlock_irqrestore(&data->data_lock, flags);
}

static int ask_frequencies(puf_data_t* data, unsigned int challenge) {
    unsigned long flags;
    char buff[2];
    // Flush FIFO data
    spin_lock_irqsave(&data->data_lock, flags);
        kfifo_reset(&data->data_fifo);
    spin_unlock_irqrestore(&data->data_lock, flags);
    // Read response
    ftdi_start_async_receive(data, &on_puf_data);
    // Send challenge number
    data->selected_challenge = challenge;
    buff[0] = data->selected_challenge;
    buff[1] = 0;
    atomic_set(&data->status, DRIVER_WAITING_FREQS);
    ftdi_sync_send(data, buff, 1, HZ*5);
#if DEBUG
    printk("[PUF Driver] Waiting frequencies\n");
#endif
    return 0;
}

static int puf_regenerate_frequencies(puf_data_t* data, unsigned int challenge) {
    // Check not already started
    mutex_lock(&data->lock);
        if (atomic_read(&data->status) != DRIVER_RESPONSE_OK){
            mutex_unlock(&data->lock);
#if DEBUG
            printk("[PUF Driver] Cannot restart the sequence from this state");
#endif
            return 0;
        }
        // First auth again
        if (!puf_auth(data)){
            mutex_unlock(&data->lock);
#if DEBUG
            printk("[PUF Driver] PUF auth failed");
#endif
            return 0;
        }
    mutex_unlock(&data->lock);    // Must unlock after data->status changes, or we could reenter multiple times
    // Then request freqs
    ask_frequencies(data, challenge);
    return 1;
}


/**
 * Hardware checks
 * --------------------------------
 */
static int check_puf_jtag(struct usb_interface *interface) {
    int ifnum = interface->cur_altsetting->desc.bInterfaceNumber;
#if DEBUG    
    printk("[PUF Driver] Checking interface number: %d\n", ifnum);
#endif
    if (ifnum == 0) {
#if DEBUG
		printk("[PUF Driver] Ignoring interface reserved for JTAG\n");
#endif
		return 1;
	}
    return 0;
}
static int check_wrong_chip_type(struct usb_device *udev) {
    // Read chip version
    unsigned version = le16_to_cpu(udev->descriptor.bcdDevice);
    // Check version
    return version != 0x0700; // FT2232H, Hi-speed - baud clock runs at 120MHz
}
static int check_wrong_endpoints(struct usb_interface *interface) {
    unsigned num_endpoints;
#if DEBUG
    struct usb_endpoint_descriptor *ep_desc;
	unsigned i;
#endif

	num_endpoints = interface->cur_altsetting->desc.bNumEndpoints;
	if (!num_endpoints)
		return 1;
#if DEBUG
	for (i = 0; i < num_endpoints; ++i) {
		ep_desc = &interface->cur_altsetting->endpoint[i].desc;
        printk("Endpoint [%d]: Max packet size %d, DirIN: %d, DirOUT: %d", 
            usb_endpoint_num(ep_desc), 
            usb_endpoint_maxp(ep_desc), 
            usb_endpoint_dir_in(ep_desc), 
            usb_endpoint_dir_out(ep_desc));
	}
#endif
    return 0;
}

/**
 * Structure Management
 * ----------------------
 */
static puf_data_t * init_driver_structure(struct usb_interface *interface, struct usb_device *udev) {
    puf_data_t *data = NULL;    // Pointer to driver data for this device
    // Create structure instance
	data = kzalloc(sizeof(puf_data_t), GFP_KERNEL);
	if (!data) {
		return 0;
	}
    atomic_set(&data->status, DRIVER_INITIALIZING);
    data->response_challenge = -1;
    mutex_init(&data->lock);
    // Save a reference to this usb device struct
	data->udev = usb_get_dev(udev);  // increments the reference count of the usb device structure
    // Init FTDI interface
    if (ftdi_initialize(data, PUF_FREQUENCIES) != FTDI_SUCCESS){
        // Clean structures
        usb_put_dev(data->udev);
        kfree(data);
        return 0;
    }
    // Bind the data struct to this interface
	usb_set_intfdata(interface, data);
    return data;
}

static void clear_driver_structure(struct usb_interface *interface) {
    puf_data_t *data = usb_get_intfdata(interface);
    ftdi_stop_async_receive(data);
    mutex_destroy(&data->lock);
    usb_set_intfdata (interface, NULL);
    usb_put_dev(data->udev);
    ftdi_destroy(data);
    kfree(data);
}

/**
 * Character devices
 * Based on: 
 * - https://linux-kernel-labs.github.io/refs/heads/master/labs/device_drivers.html
 * - https://olegkutkov.me/2018/03/14/simple-linux-character-device-driver/#:~:text=A%20character%20device%20is%20one,by%20byte%2C%20like%20a%20stream.
 * --------------------------------
 */
// Defines
#define MAJOR_NUM 200
#define BASE_NAME "teropuf"
#define SUPPORTED_DEVICES 32

// Static vars
static struct class *tero_class = NULL;     // Char device class

DEFINE_SPINLOCK(minor_lock);  // Lock used to protect the minor ops
int minor_mask = 0;           // Mask used to find the next free minor number. Must have bits => SUPPORTED_DEVICES

// Prototypes
static int tero_open(struct inode *, struct file *);
static int tero_release(struct inode *, struct file *);
static ssize_t tero_read(struct file *, char __user *, size_t , loff_t *);
static ssize_t tero_write(struct file *, const char __user *, size_t , loff_t *);

static const struct file_operations tero_fops = {
    .owner          = THIS_MODULE,
    .open           = tero_open,
    .release        = tero_release,
    .read           = tero_read,
    .write          = tero_write
};

static char *tero_devnode(struct device *dev, umode_t *mode) {
        if (!mode)
            return NULL;
        // Read-write permission for root
        // Read permission for everybody
        *mode = 0664;
        return NULL;
}

static int init_character_device(void) {
    int result;
    // Allocate region
    result = register_chrdev_region(MKDEV(MAJOR_NUM, 0), SUPPORTED_DEVICES, BASE_NAME);
    if (result != 0){
        return 0;
    }
    // Prepare sysfs
    tero_class = class_create(THIS_MODULE, BASE_NAME);
    if (!tero_class){
        return 0;
    }
    // Set permissions for the device
    tero_class->devnode = tero_devnode;
    return 1;
}

static void destroy_character_device(void) {
    // Remove class
    class_destroy(tero_class);
    // Remove allocated region
    unregister_chrdev_region(MKDEV(MAJOR_NUM, 0), SUPPORTED_DEVICES);
}

static int add_character_device(puf_data_t* data) {
    int next_free_minor = 0;
    // Init the device, linking the function pointers
    cdev_init(&data->cdev, &tero_fops);
    // Get the next minor
    spin_lock(&minor_lock);
        //  The mask is used to get the lowest minor available
        //  ... 0000 0000 0000 : ffz returns 0, set bit 0: |= 1 << 0, |= 1
        //  ... 0000 0000 0001 : ffz returns 1, set bit 1: |= 1 << 1, |= 10             
        //  ... 0000 0000 0011 : ffz returns 2, set bit 2: |= 1 << 2, |= 100
        if (minor_mask == ~0UL){
            return 0; // Operation failed, no more minors available
        }
        next_free_minor = ffz(minor_mask);  // returns the position of the first (least significant) bit unset in the word i. The least significant bit is position 0 and the most significant position is 31
        minor_mask |= 1 << next_free_minor;
    spin_unlock(&minor_lock);
    // Add the device
    data->minor = next_free_minor;
    cdev_add(&data->cdev, MKDEV(MAJOR_NUM, data->minor), 1);
    // Create sysfs device
    device_create(tero_class, NULL, MKDEV(MAJOR_NUM, data->minor), NULL, "%s-%d", BASE_NAME, data->minor);
    return 1;
}

static int remove_character_device(puf_data_t* data) {
    // Remove sysfs device
    device_destroy(tero_class, MKDEV(MAJOR_NUM, data->minor));
    // Free the minor used
    spin_lock(&minor_lock);
        //  The corresponding bit was set in the mask, now unset
        //  ... 0000 0000 0111: (bit 1 was set), &= ~(1 << minor), &= ~(1 << 1), &= ~(10), &= 1111 1111 1101
        //  ... 0000 0000 0101: (bit 0 was set), &= ~(1 << minor), &= ~(1 << 0), &= ~(1), &= 1111 1111 1110
        minor_mask &= ~(1 << data->minor);
    spin_unlock(&minor_lock);
    // Remove the device
    cdev_del(&data->cdev);
    return 1;
}

/*
    Structures
*/

static int tero_open(struct inode *inode, struct file *file) {
    puf_data_t* data;
    // Retrieve puf context (as cdev is a variable of the structure)
    data = container_of(inode->i_cdev, puf_data_t, cdev);
    // Ref. the structure for easier access in the other methods
    file->private_data = data;
    return 0;
}

static int tero_release(struct inode *inode, struct file *file) {
    file->private_data = NULL;
    return 0;
}

static ssize_t tero_read(struct file *file, char __user *user_buffer, size_t size, loff_t *offset) {
    puf_data_t* data;      
    int copied_bytes;
    char tmp_buffer[DRIVER_RESPONSE_SIZE];

    // Get puf context
    data = (puf_data_t*)file->private_data;
    // Format of the string:    CHALLENGE_NUM RESPONSE_ID\0
    // Check size
    if (size < DRIVER_RESPONSE_SIZE) {
        return 0; // Not enough data requested, do not send a partial result id
    }
    // Check if a response is available
    mutex_lock(&data->lock);
        if (data->response_challenge == -1) {
            mutex_unlock(&data->lock);
            return 0;
        }
        // Create the response on the stack, as __copy_to_user can sleep
        // and so we must release the spinlock before
        copied_bytes = scnprintf(tmp_buffer, DRIVER_RESPONSE_SIZE, "%d %s\n", data->response_challenge, data->response_id);
    mutex_unlock(&data->lock);
    // Copy the response challenge
    // Size of the destination buffer was already checked before
    //printk("[->TERO CHANNEL]%d %s\n", data->response_challenge, data->response_id);
    if (!__copy_to_user(user_buffer, tmp_buffer, copied_bytes + 1)) {  // copy also the terminator \0
        return copied_bytes + 1;
    } else {
        return 0;
    }
}

static ssize_t tero_write(struct file *file, const char __user *user_buffer, size_t count, loff_t *offset) {
    puf_data_t* data;
    int ret;
    unsigned int challenge = 0;
    // Get puf context
    data = (puf_data_t*)file->private_data;
    // Convert number into challenge
    ret = kstrtouint_from_user(user_buffer, count, 10, &challenge);
    if (!ret){
        // Valid number
        if (challenge >= MIN_CHALLENGE && challenge <= MAX_CHALLENGE){
            //printk("[<-TERO CHANNEL]%d\n", challenge);
            // Ask for data
            if (puf_regenerate_frequencies(data, challenge)){
                return count;
            }
        }
    }
    return 0;
}