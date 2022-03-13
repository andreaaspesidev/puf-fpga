#ifndef PUF_FTDI_INTERFACE
#define PUF_FTDI_INTERFACE
    #include "structures.h"
    // Constants
    #define FTDI_BAUD_RATE_BASE 120000000 / 2 // FT2232H, ftdi_sio.c:1562
    #define FTDI_MAX_PACKET_SIZE 512
    #define FTDI_PIPE_IN 3
    #define FTDI_PIPE_OUT 4

    // Define enums
    typedef enum PUF_BAUDRATE {
        BAUD_9600 = 9600,
        BAUD_19200 = 19200,
        BAUD_38400 = 38400,
        BAUD_57600 = 57600,
        BAUD_115200 = 115200
    } PUF_BAUDRATE;
    typedef enum PUF_DATABITS {
        DATA_BITS_7 = 7,
        DATA_BITS_8 = 8,
    } PUF_DATABITS;
    typedef enum PUF_STOPBITS {
        STOP_BITS_1 = 1,
        STOP_BITS_15 = 15,
        STOP_BITS_2 = 2
    } PUF_STOPBITS;
    typedef enum PUF_PARITY {
        PARITY_NONE = 0,
        PARITY_EVEN = 1,
        PARITY_ODD = 2,
        PARITY_MARK = 3,
        PARITY_SPACE = 4
    } PUF_PARITY;
    typedef enum FTDI_OP_RESULT {
        FTDI_SUCCESS = 1,
        FTDI_ERROR = 0
    } FTDI_OP_RESULT;
    
    // Define prototypes
    /**
     * @brief Initialize used structures for FTDI
     * 
     * @return FTDI_OP_RESULT 
     */
    FTDI_OP_RESULT ftdi_initialize(puf_data_t* data);

    /**
     * @brief Clear structures used for FTDI
     * 
     */
    void ftdi_destroy(puf_data_t* data);

    /**
     * @brief Setup the serial port
     * 
     * @param baudrate baudrate of the port
     * @param data_bits data bits of the port
     * @param stop_bits stop bits of the port
     * @param parity parity of the port
     * @return FTDI_OP_RESULT
     */
    FTDI_OP_RESULT ftdi_setup_parameters(puf_data_t* data, 
                                        PUF_BAUDRATE baudrate, 
                                        PUF_DATABITS data_bits, 
                                        PUF_STOPBITS stop_bits, 
                                        PUF_PARITY parity);
        
    /**
     * @brief Opens the port, clearing the FTDI buffers
     * 
     * @return FTDI_OP_RESULT 
     */
    FTDI_OP_RESULT ftdi_open_port(puf_data_t* data);
    
    /**
     * @brief Sends data length bytes from the supplied buffer (blocking call)
     * 
     * @param buffer pointer to supplied data buffer
     * @param length length of the buffer
     * @param timeout timeout for the operation, in jiffies
     * @return FTDI_OP_RESULT 
     */
    FTDI_OP_RESULT ftdi_sync_send(puf_data_t* data, 
                                char* buffer, 
                                char length,
                                unsigned int timeout);
    
    /**
     * @brief Block for timeout, while waiting for length data from the device.
     *        When data is received, is placed in the supplied buffer.
     *        If more data arrives, is discarded.
     * 
     * @param buffer pointer to supplied data buffer
     * @param length number of bytes to read
     * @param timeout timeout, in jiffies, before returing even with no data
     * @return FTDI_OP_RESULT Error if no data is arrived in the interval
     */
    FTDI_OP_RESULT ftdi_sync_receive(puf_data_t* data, 
                                    char* buffer, 
                                    char length, 
                                    unsigned int timeout);
    
    /**
     * @brief Enable async reception of data. Data is placed in the data_fifo.
     *        If fifo is full, incoming data is discarded.
     *        When data arrives, the callback on_data_callback is fired.
     *        WARNING: the callback can be called in INTERRUPT context, do not block
     * 
     * @param on_data_callback is the callback to be executed when new data is received
     * @return FTDI_OP_RESULT 
     */
    FTDI_OP_RESULT ftdi_start_async_receive(puf_data_t* data, void (*on_data_callback)(puf_data_t* data));
    
    /**
     * @brief Stops the async reception of data. If not started, no op.
     * 
     */
    void ftdi_stop_async_receive(puf_data_t* data);
#endif