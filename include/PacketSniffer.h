#ifndef PacketSniffer_h
#define PacketSniffer_h

#include <pcap/pcap.h>
#include <stdbool.h>

// Type alias for Swift callback: pointer to function receiving packet bytes + length
typedef void (*PacketHandler)(const u_char *packet, int length);

// Return codes for operations
typedef enum {
	SNIFF_OK = 0,
	SNIFF_ERROR_NULL_PARAM = -1,
	SNIFF_ERROR_INVALID_DEVICE = -2,
	SNIFF_ERROR_ALREADY_RUNNING = -3,
	SNIFF_ERROR_PCAP_OPEN = -4,
	SNIFF_ERROR_NOT_RUNNING = -5
} SniffResult;

// Maximum packet size to prevent buffer overflows (64KB)
#define MAX_PACKET_SIZE (64 * 1024)

// Starts sniffing on the given device (e.g., "en0") and calls handler on each packet
// Returns SNIFF_OK on success, negative error code on failure
// Thread-safe: can be called from multiple threads
SniffResult start_sniffing(const char *device, PacketHandler handler);

// Stops sniffing and closes the pcap handle
// Returns SNIFF_OK on success, SNIFF_ERROR_NOT_RUNNING if not running
// Thread-safe: can be called from multiple threads
SniffResult stop_sniffing(void);

// Checks if sniffing is currently active
// Thread-safe
bool is_sniffing_active(void);

#endif /* PacketSniffer_h */
