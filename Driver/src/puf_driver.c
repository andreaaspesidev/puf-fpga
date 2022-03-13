#include <linux/kernel.h>
#include <linux/errno.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/workqueue.h>

#include "ftdi_interface.h"

MODULE_AUTHOR("Andrea Aspesi <andrea1.aspesi@mail.polimi.it>");
MODULE_DESCRIPTION("TERO PUF Driver");
MODULE_LICENSE("GPL");

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
static int __init puf_driver_init(void) {
    int result;
    /* register this driver with the USB subsystem */
    result = usb_register(&puf_driver);
    if (result)
        printk("usb_register failed. Error number %d", result);
    return result;
}
module_init(puf_driver_init);

static void __exit puf_driver_exit(void) {
    /* deregister this driver with the USB subsystem */
    usb_deregister(&puf_driver);
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

static int puf_valid(puf_data_t*);
static int ask_frequencies(puf_data_t*, unsigned int);


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
    // Configure FTDI parameters
    if (ftdi_setup_parameters(data, BAUD_9600, DATA_BITS_8, STOP_BITS_1, PARITY_NONE) == FTDI_ERROR){
        clear_driver_structure(interface);
        return -ENODEV;
    }
    // Open serial port
    if (ftdi_open_port(data) == FTDI_ERROR) {
        clear_driver_structure(interface);
        return -ENODEV;
    }
    // Check if puf is valid
    if (!puf_valid(data)){
        clear_driver_structure(interface);
        return -ENODEV;
    }
    // Ask frequencies
    ask_frequencies(data, 1);

    // Claim the device
    printk("[PUF Driver] Device claimed!\n");
    return 0;
}

static void puf_disconnect(struct usb_interface *interface) {
    // Cleanup
    clear_driver_structure(interface);
    printk("[PUF Driver] Device deattached!\n");
}

/**
 * PUF Communication
 * --------------------------------
 */
#define PUF_AUTH_REQUEST    '\xAA'
#define PUF_AUTH_RESPONSE   '\xAB'
static int puf_valid(puf_data_t* data){
    char buff[2];
    // Send auth id
    buff[0] = PUF_AUTH_REQUEST;
    buff[1] = 0;
    ftdi_sync_send(data, buff, 1, HZ*5);
    data->status = DRIVER_AUTH_SENT;
    // Read auth response
    ftdi_sync_receive(data, buff, 1, HZ*5);
    if (buff[0] == PUF_AUTH_RESPONSE){
        data->status = DRIVER_AUTH_OK;
        printk("[PUF Driver] PUF detected!\n");
        return 1;
    }
    printk("[PUF Driver] Wrong puf response\n");
    return 0;
}

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
static void generate_response(puf_data_t* data) {
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
    get_2comp_indices(data->selected_challenge, &i, &j);
    printk("[PUF Driver] Generating using i=%d, j=%d\n", i,j);
    // Generate unique id, by comparing for each batch the freq in position i and j
    for (curr_bit=0;curr_bit<BATCHES_NUM;++curr_bit){
        data->response_id[curr_bit] = (data->batches[curr_bit][i] > data->batches[curr_bit][j]) ? '1' : '0';
    }
    data->response_id[curr_bit] = '\0'; // Add the terminator
    printk("[PUF Driver] Challenge: %d, Unique ID: %s\n", data->selected_challenge, data->response_id);
}

static void process_frequencies(struct work_struct *work){
    unsigned long flags;
    puf_data_t* data;
    int i;
    // Recover parent structure from work pointer (math on memory addresses)
    data = container_of(work, puf_data_t, worker_freqs);
    printk("[PUF Driver] Begin processing frequencies: \n");
    spin_lock_irqsave(&data->data_lock, flags);
        // Move data to local buffer for direct access
        if (kfifo_out(&data->data_fifo, data->freq_bytes, PUF_FREQUENCIES*4) != PUF_FREQUENCIES*4) {
            data->status = DRIVER_ERROR;
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
        printk("[PUF Freq #%d] %02x %02x %02x %02x: %d\n", 
                i / 4, 
                data->freq_bytes[i] & 0xff, 
                data->freq_bytes[i+1] & 0xff, 
                data->freq_bytes[i+2] & 0xff, 
                data->freq_bytes[i+3] & 0xff, 
                data->freqs[i/4]);
    }
    // Process frequencies
    generate_response(data);
}

void on_puf_data(puf_data_t* data){
    //INTERRUPT_CONTEXT
    unsigned long flags;
    int bytes_received;
    // Check if the driver is waiting for data
    if (data->status != DRIVER_WAITING_FREQS){
        return; // Ignore data
    }
    // Check fifo size
    spin_lock_irqsave(&data->data_lock, flags);
        bytes_received = kfifo_len(&data->data_fifo);
    spin_unlock_irqrestore(&data->data_lock, flags);
    printk("[PUF Driver] FIFO_SIZE: %d\n", bytes_received);
    // Is all the data arrived?
    if (bytes_received == PUF_FREQUENCIES*4){
        data->status = DRIVER_PROCESSING_FREQS;
        // Initialize work
        INIT_WORK(&data->worker_freqs, process_frequencies);
        // Schedule work
        schedule_work(&data->worker_freqs);
        printk("[PUF Driver] Scheduled frequencies processing\n");
    }
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
    data->status = DRIVER_WAITING_FREQS;
    ftdi_sync_send(data, buff, 1, HZ*5);
    printk("[PUF Driver] Waiting frequencies\n");
    return 0;
}

/**
 * Hardware checks
 * --------------------------------
 */
static int check_puf_jtag(struct usb_interface *interface) {
    int ifnum = interface->cur_altsetting->desc.bInterfaceNumber;
    printk("[PUF Driver] Checking interface number: %d\n", ifnum);
	
    if (ifnum == 0) {
		printk("[PUF Driver] Ignoring interface reserved for JTAG\n");
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
    struct usb_endpoint_descriptor *ep_desc;
    unsigned num_endpoints;
	unsigned i;

	num_endpoints = interface->cur_altsetting->desc.bNumEndpoints;
	if (!num_endpoints)
		return 1;
	for (i = 0; i < num_endpoints; ++i) {
		ep_desc = &interface->cur_altsetting->endpoint[i].desc;
        printk("Endpoint [%d]: Max packet size %d, DirIN: %d, DirOUT: %d", 
            usb_endpoint_num(ep_desc), 
            usb_endpoint_maxp(ep_desc), 
            usb_endpoint_dir_in(ep_desc), 
            usb_endpoint_dir_out(ep_desc));
	}
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
    data->status = DRIVER_INITIALIZING;
    // Save a reference to this usb device struct
	data->udev = usb_get_dev(udev);  // increments the reference count of the usb device structure
    // Init FTDI interface
    if (ftdi_initialize(data) != FTDI_SUCCESS){
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
    usb_set_intfdata (interface, NULL);
    usb_put_dev(data->udev);
    ftdi_destroy(data);
    kfree(data);
}

