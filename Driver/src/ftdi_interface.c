#include "ftdi_interface.h"
#include "ftdi_interface_constants.h"

#include <linux/jiffies.h>
#include <linux/slab.h>
#include <linux/termios.h>

#define MIN(a,b) (((a)<(b))?(a):(b))


FTDI_OP_RESULT ftdi_initialize(puf_data_t* data, const unsigned int puf_frequencies) {
    unsigned int storable_per_page;
    unsigned int needed_pages;

    // Init spinlock
    spin_lock_init(&data->data_lock);
    // Initialize writing buffer
    data->out_buffer = kzalloc(FTDI_MAX_PACKET_SIZE, GFP_KERNEL);
    if (!data->out_buffer) {
        return FTDI_ERROR;
    }
    // Initialize reading buffers
    data->in_buffer = kzalloc(FTDI_MAX_PACKET_SIZE, GFP_KERNEL);
    if (!data->in_buffer) {
        kfree(data->out_buffer);
		return FTDI_ERROR;
	}
    data->in_async_buffer = kzalloc(FTDI_MAX_PACKET_SIZE, GFP_KERNEL);
    if (!data->in_async_buffer) {
        kfree(data->out_buffer);
        kfree(data->in_buffer);
		return FTDI_ERROR;
	}
    // Create read fifo
    // PAGE_SIZE = 4096 bytes
    // 1280 int32 (4 bytes): 1280*4=5120 -> 2 pages (8192 bytes)
    // 160  int32 (4 bytes):  160*4=640 -> 1 page (4096 bytes)
    storable_per_page = PAGE_SIZE / 4; // 1024
    needed_pages = DIV_ROUND_UP(puf_frequencies, storable_per_page);

    if (kfifo_alloc(&data->data_fifo, needed_pages*PAGE_SIZE, GFP_KERNEL)) { // the number of elements in the fifo, this must be a power of 2
        kfree(data->out_buffer);
        kfree(data->in_buffer);
        kfree(data->in_async_buffer);
        return FTDI_ERROR;
    }
    // Allocate async reading urb
    data->in_urb = usb_alloc_urb(0, GFP_KERNEL);
    if (!data->in_urb) {
        kfree(data->out_buffer);
        kfree(data->in_buffer);
        kfree(data->in_async_buffer);
        kfifo_free(&data->data_fifo);
        return FTDI_ERROR;
    }
    return FTDI_SUCCESS;
}

void ftdi_destroy(puf_data_t* data){
    unsigned long flags;
    // Stop async reading
    usb_kill_urb(data->in_urb);
    // Destroy urb
    usb_free_urb(data->in_urb);
    data->in_urb = NULL;
    // Free fifo content
    spin_lock_irqsave(&data->data_lock, flags);
	    kfifo_reset_out(&data->data_fifo);
	spin_unlock_irqrestore(&data->data_lock, flags);
    // Free fifo
    kfifo_free(&data->data_fifo);
    // Free input buffers
    kfree(data->in_buffer);
    kfree(data->in_async_buffer);
    // Free output buffer
    kfree(data->out_buffer);
}   

/*
 * Port setup
 * -----------------------
 */
static u32 ftdi_2232h_baud_base_to_divisor(int baud, int base) {
	static const unsigned char divfrac[8] = { 0, 3, 2, 4, 1, 5, 6, 7 };
	u32 divisor;
	int divisor3;

	/* As freq = 120Mhz, seems a prescaler exists to have base = 12Mhz. So / 10 the current base */
	divisor3 = DIV_ROUND_CLOSEST(8 * base, 10 * baud); // (12 000 000 * 8) / baud to keep the first 3 decimal bits in the integer part

	divisor = divisor3 >> 3; // Recover the actual division, truncated (int division)
	divisor |= (u32)divfrac[divisor3 & 0x7] << 14;
	/* Deal with special cases for highest baud rates. */
	if (divisor == 1)		/* 1.0 */
		divisor = 0;
	else if (divisor == 0x4001)	/* 1.5 */
		divisor = 1;
	/*
	 * This enables baud rates up to 12Mbaud but cannot reach below 1200
	 * baud with this bit set
	 */
	divisor |= 0x00020000;
	return divisor;
}
static u32 ftdi_232bm_baud_base_to_divisor(int baud, int base) {
	static const unsigned char divfrac[8] = { 0, 3, 2, 4, 1, 5, 6, 7 };
    /*
        000 = 0.0​      (0)
        011 = 0.125​    (3)
        010 = 0.25     (2)​
        100 = 0.375​    (4)
        001 = 0.5​      (1)
        101 = 0.625​    (5)
        110 = 0.75​     (6)
        111 = 0.875    (7)
    */
	u32 divisor;
	/* divisor shifted 3 bits to the left */
	int divisor3 = DIV_ROUND_CLOSEST(base, 2 * baud); // (12 000 000 / 2) / baud = 12 000 000 / (2*baud)
	divisor = divisor3 >> 3;    // = / 8, division of base by 16 at the end of this line
	divisor |= (u32)divfrac[divisor3 & 0x7] << 14;  // Divisor 3 is used to extract the fractional bits
	/* Deal with special cases for highest baud rates. */
	if (divisor == 1)		/* 1.0 */
		divisor = 0;
	else if (divisor == 0x4001)	/* 1.5 */
		divisor = 1;
	return divisor;
}
static FTDI_OP_RESULT set_baudrate(struct usb_device *udev, unsigned int baudrate) {
    u16 value;
	u16 index;
	u32 div_value = 0;
	int rv;

    // Calculate settings
    if ((baudrate <= 12000000) && (baudrate >= 1200)) {
        div_value = ftdi_2232h_baud_base_to_divisor(baudrate, 120000000);
    } else if (baudrate < 1200) {
        div_value = ftdi_232bm_baud_base_to_divisor(baudrate, 48000000);
    } else {
        // Value too high, override
        div_value = ftdi_232bm_baud_base_to_divisor(9600, 48000000);
        baudrate = 9600;
    }
	value = (u16)div_value;
	index = (u16)(div_value >> 16);
	index = (u16)((index << 8) | INTERFACE_B);
    // Apply settings
	rv = usb_control_msg(udev,
			usb_sndctrlpipe(udev, 0), // First output endpoint number, unsigned int usb_sndctrlpipe(struct usb_device *dev, unsigned int endpoint)
			FTDI_SIO_SET_BAUDRATE_REQUEST,
			FTDI_SIO_SET_BAUDRATE_REQUEST_TYPE,
			value, index,
			NULL, 0, WDR_SHORT_TIMEOUT);
    return (rv < 0) ? FTDI_ERROR : FTDI_SUCCESS;
}

FTDI_OP_RESULT ftdi_setup_parameters(puf_data_t* data, 
                                     PUF_BAUDRATE baudrate, 
                                     PUF_DATABITS data_bits, 
                                     PUF_STOPBITS stop_bits, 
                                     PUF_PARITY parity) {
    int result;
    u16 value;
    struct usb_device *udev = data->udev;
    // Set the baudrate
    if (set_baudrate(udev, baudrate) == FTDI_ERROR){
        return FTDI_ERROR;
    }
	value = 0;
    // Set the stop bits
    switch (stop_bits) {
        case STOP_BITS_1:
            value |= FTDI_SIO_SET_DATA_STOP_BITS_1;
            break;
        case STOP_BITS_15:
            value |= FTDI_SIO_SET_DATA_STOP_BITS_15;
            break;
        case STOP_BITS_2:
            value |= FTDI_SIO_SET_DATA_STOP_BITS_2;
            break;
    }
	// Set the parity
    switch(parity) {
        case PARITY_NONE:
            value |= FTDI_SIO_SET_DATA_PARITY_NONE;
            break;
        case PARITY_EVEN:
            value |= FTDI_SIO_SET_DATA_PARITY_EVEN;
            break;
        case PARITY_ODD:
            value |= FTDI_SIO_SET_DATA_PARITY_ODD;
            break;
        case PARITY_MARK:
            value |= FTDI_SIO_SET_DATA_PARITY_MARK;
            break;
        case PARITY_SPACE:
            value |= FTDI_SIO_SET_DATA_PARITY_SPACE;
            break;
    }
    // Set data bits
    value |= data_bits;
    // Apply
	result = usb_control_msg(udev, usb_sndctrlpipe(udev, 0),
			    FTDI_SIO_SET_DATA_REQUEST,
			    FTDI_SIO_SET_DATA_REQUEST_TYPE,
			    value, 0,
			    NULL, 0, WDR_SHORT_TIMEOUT);
    return (result < 0) ? FTDI_ERROR : FTDI_SUCCESS;
}

/*
 * Port open
 * -----------------------
 */
static void clear_rx_buffer(puf_data_t* data){
    // As for https://bugzilla.kernel.org/show_bug.cgi?id=5730
    // manually clear the buffer
    int retval;
    int actual_length; 
    do {
        retval = usb_bulk_msg(data->udev,
                    usb_rcvbulkpipe(data->udev, FTDI_PIPE_IN),
                    data->in_buffer,
                    FTDI_MAX_PACKET_SIZE,
                    &actual_length, HZ/10);
    } while(actual_length > 2 || retval < 0);
}
FTDI_OP_RESULT ftdi_open_port(puf_data_t* data) {
    int rv;
    // Reset port status
    rv = usb_control_msg(data->udev, usb_sndctrlpipe(data->udev, 0),
			FTDI_SIO_RESET_REQUEST, FTDI_SIO_RESET_REQUEST_TYPE,
			FTDI_SIO_RESET_SIO, 0, 
            NULL, 0, WDR_TIMEOUT);
    if (rv < 0){
        return FTDI_ERROR;
    }
    clear_rx_buffer(data);
    return FTDI_SUCCESS;
}

/*
 * Data sync send
 * -----------------------
 */
FTDI_OP_RESULT ftdi_sync_send(puf_data_t* data, 
                              char* buffer, 
                              char length,
                              unsigned int timeout){
    int retval;
    int buff_index, i;
    int scheduled_length, sent_length;

    buff_index = 0;
    do{
        // Place data in output buffer
        for(i=0;i<FTDI_MAX_PACKET_SIZE && buff_index < length;++i,++buff_index){
            data->out_buffer[i] = buffer[buff_index];
        }
        scheduled_length = MIN(i, FTDI_MAX_PACKET_SIZE);
        // Send data
        retval = usb_bulk_msg(data->udev,
                    usb_sndbulkpipe(data->udev, FTDI_PIPE_OUT),
                    data->out_buffer,
                    scheduled_length,
                    &sent_length, timeout);
        if (retval < 0 || scheduled_length != sent_length){
            return FTDI_ERROR;
        }
        // Continue until all buffer processed
    }while(buff_index < length);
    return FTDI_SUCCESS;
}

/*
 * Data sync receive
 * -----------------------
 */
#define FTDI_RS_ERR_MASK (FTDI_RS_BI | FTDI_RS_PE | FTDI_RS_FE | FTDI_RS_OE)
FTDI_OP_RESULT ftdi_sync_receive(puf_data_t* data, 
                                 char* buffer, 
                                 char length, 
                                 unsigned int timeout){
    int retval;
    int read_length;
    int bytes_read, i;
    unsigned long end_jiffies;
    bytes_read = 0;
    end_jiffies = jiffies + timeout;
    do{
        // Read data
        retval = usb_bulk_msg(data->udev,
                    usb_rcvbulkpipe(data->udev, FTDI_PIPE_IN),
                    data->in_buffer,
                    FTDI_MAX_PACKET_SIZE,
                    &read_length, timeout);
        if (read_length <= 2){
            continue; // Broken/empty packet
        }
        /*
        * The device reserves the first two bytes of data on this endpoint to contain
        * the current values of the modem and line status registers. In the absence of
        * data, the device generates a message consisting of these two status bytes
        * every 40 ms
        *
        * Byte 0: Modem Status
        *
        * Offset	Description
        * B0	Reserved - must be 1
        * B1	Reserved - must be 0
        * B2	Reserved - must be 0
        * B3	Reserved - must be 0
        * B4	Clear to Send (CTS)
        * B5	Data Set Ready (DSR)
        * B6	Ring Indicator (RI)
        * B7	Receive Line Signal Detect (RLSD)
        *
        * Byte 1: Line Status
        *
        * Offset	Description
        * B0	Data Ready (DR)
        * B1	Overrun Error (OE)
        * B2	Parity Error (PE)
        * B3	Framing Error (FE)
        * B4	Break Interrupt (BI)
        * B5	Transmitter Holding Register (THRE)
        * B6	Transmitter Empty (TEMT)
        * B7	Error in RCVR FIFO
        */ 
        // Check if data packet is valid
        if (data->in_buffer[1] & FTDI_RS_ERR_MASK){
            continue;  // Corrupted packet
        }
        // Move data to the buffer
        for(i=2;i<read_length && bytes_read < length;++i,++bytes_read){
            buffer[bytes_read] = data->in_buffer[i];
        }
        // Check if operation completed
        if (bytes_read >= length){
            return FTDI_SUCCESS;
        }
    }while(time_before(jiffies, end_jiffies));
    // Timeout error
    return FTDI_ERROR;
}

/*
 * Data async receive
 * -----------------------
 */
void read_bulk_callback(struct urb *);

FTDI_OP_RESULT ftdi_start_async_receive(puf_data_t* data, void (*on_data_callback)(puf_data_t* data)){
    // Initialize async reading urb
    data->on_data_callback = on_data_callback;
    usb_fill_bulk_urb(data->in_urb, data->udev,
		usb_rcvbulkpipe(data->udev, FTDI_PIPE_IN),
		data->in_async_buffer, FTDI_MAX_PACKET_SIZE,
		read_bulk_callback, data);
    // Send urb to the subsystem
    return usb_submit_urb(data->in_urb, GFP_KERNEL) < 0 ? FTDI_ERROR : FTDI_SUCCESS;
}

void ftdi_stop_async_receive(puf_data_t* data){
    usb_kill_urb(data->in_urb);
}

void read_bulk_callback(struct urb *urb) {
    // INTERRUPT CONTEXT: do not sleep
    unsigned long flags;
    puf_data_t* data = urb->context;
    int read_length;
    //unsigned int i;

    // Process incoming data
    // (see sync read for info on the first two bytes)
    read_length = urb->actual_length;
    if (read_length > 2) { // Packet not malformed, and containing data
        // Check if is valid
        if (!(data->in_async_buffer[1] & FTDI_RS_ERR_MASK)){ // Valid packet
            // Store data in the fifo
            spin_lock_irqsave(&data->data_lock, flags);
                // Check enough space in the fifo
                if (kfifo_avail(&data->data_fifo) - read_length + 2 >= 0) {
                    // Put data inside
                    kfifo_in(&data->data_fifo, &data->in_async_buffer[2], read_length-2);
                }
            spin_unlock_irqrestore(&data->data_lock, flags);
            // Print for debug purposes
            //for (i = 2; i < read_length; ++i){
            //    printk("%02X: %c\n", data->in_async_buffer[i], data->in_async_buffer[i]);
            //}
            // Signal data received
            data->on_data_callback(data);
        }
    }

    // Start next urb
    usb_submit_urb(urb, GFP_ATOMIC);   //ATOMIC needed to avoid blocking for cascaded allocations
}