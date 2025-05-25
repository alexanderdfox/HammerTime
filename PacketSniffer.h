#ifndef PacketSniffer_h
#define PacketSniffer_h

#include <pcap/pcap.h>

// Type alias for Swift callback: pointer to function receiving packet bytes + length
typedef void (*PacketHandler)(const u_char *packet, int length);

// Starts sniffing on the given device (e.g., "en0") and calls handler on each packet
void start_sniffing(const char *device, PacketHandler handler);

// Stops sniffing and closes the pcap handle
void stop_sniffing(void);

#endif /* PacketSniffer_h */