#include "PacketSniffer.h"
#include <stdio.h>
#include <stdlib.h>

static pcap_t *handle = NULL;
static PacketHandler globalHandler = NULL;

static void packet_callback(u_char *args, const struct pcap_pkthdr *header, const u_char *packet) {
	if(globalHandler != NULL) {
		globalHandler(packet, header->len);
	}
}

void start_sniffing(const char *device, PacketHandler handler) {
	char errbuf[PCAP_ERRBUF_SIZE];
	globalHandler = handler;

	handle = pcap_open_live(device, BUFSIZ, 1, 1000, errbuf);
	if (handle == NULL) {
		fprintf(stderr, "Couldn't open device %s: %s\n", device, errbuf);
		return;
	}

	// Run capture loop in a separate thread (blocking)
	pcap_loop(handle, -1, packet_callback, NULL);
}

void stop_sniffing(void) {
	if(handle != NULL) {
		pcap_breakloop(handle);
		pcap_close(handle);
		handle = NULL;
	}
}