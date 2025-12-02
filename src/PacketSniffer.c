#include "../include/PacketSniffer.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <errno.h>

// Thread-safe state management
static pcap_t *handle = NULL;
static PacketHandler globalHandler = NULL;
static pthread_mutex_t state_mutex = PTHREAD_MUTEX_INITIALIZER;
static volatile bool is_running = false;

// Validate packet length to prevent buffer overflows
static inline bool is_valid_packet_length(int length) {
	return length > 0 && length <= MAX_PACKET_SIZE;
}

// Secure packet callback with bounds checking
static void packet_callback(u_char *args __attribute__((unused)), const struct pcap_pkthdr *header, const u_char *packet) {
	// Validate header pointer
	if (header == NULL || packet == NULL) {
		return;
	}
	
	// Validate packet length to prevent buffer overflows
	if (!is_valid_packet_length(header->len)) {
		fprintf(stderr, "Warning: Invalid packet length %d (max: %d)\n", 
			header->len, MAX_PACKET_SIZE);
		return;
	}
	
	// Validate captured length matches header length
	if (header->caplen < header->len) {
		fprintf(stderr, "Warning: Captured length %u < packet length %u\n",
			header->caplen, header->len);
		// Use captured length to avoid reading beyond buffer
	}
	
	// Thread-safe handler access
	pthread_mutex_lock(&state_mutex);
	PacketHandler handler = globalHandler;
	pthread_mutex_unlock(&state_mutex);
	
	if (handler != NULL) {
		// Pass the captured length (safe) instead of full length
		handler(packet, (int)header->caplen);
	}
}

// Validate device name to prevent injection attacks
static bool is_valid_device_name(const char *device) {
	if (device == NULL) {
		return false;
	}
	
	size_t len = strlen(device);
	
	// Device names should be reasonable length (max 64 chars)
	if (len == 0 || len > 64) {
		return false;
	}
	
	// Device names should only contain alphanumeric, dots, dashes, underscores
	// This prevents command injection
	for (size_t i = 0; i < len; i++) {
		char c = device[i];
		if (!((c >= 'a' && c <= 'z') ||
		      (c >= 'A' && c <= 'Z') ||
		      (c >= '0' && c <= '9') ||
		      c == '.' || c == '-' || c == '_')) {
			return false;
		}
	}
	
	return true;
}

SniffResult start_sniffing(const char *device, PacketHandler handler) {
	// Validate input parameters
	if (device == NULL) {
		fprintf(stderr, "Error: device parameter is NULL\n");
		return SNIFF_ERROR_NULL_PARAM;
	}
	
	if (handler == NULL) {
		fprintf(stderr, "Error: handler parameter is NULL\n");
		return SNIFF_ERROR_NULL_PARAM;
	}
	
	// Validate device name to prevent injection
	if (!is_valid_device_name(device)) {
		fprintf(stderr, "Error: Invalid device name format\n");
		return SNIFF_ERROR_INVALID_DEVICE;
	}
	
	// Thread-safe state check and update
	pthread_mutex_lock(&state_mutex);
	
	if (is_running) {
		pthread_mutex_unlock(&state_mutex);
		fprintf(stderr, "Error: Sniffing already active\n");
		return SNIFF_ERROR_ALREADY_RUNNING;
	}
	
	// Set handler before opening device
	globalHandler = handler;
	
	pthread_mutex_unlock(&state_mutex);
	
	// Open pcap device with error buffer
	char errbuf[PCAP_ERRBUF_SIZE];
	errbuf[0] = '\0'; // Ensure null termination
	
	handle = pcap_open_live(device, BUFSIZ, 1, 1000, errbuf);
	
	if (handle == NULL) {
		// Clean up state on error
		pthread_mutex_lock(&state_mutex);
		globalHandler = NULL;
		is_running = false;
		pthread_mutex_unlock(&state_mutex);
		
		fprintf(stderr, "Error: Couldn't open device %s: %s\n", device, 
			errbuf[0] != '\0' ? errbuf : "Unknown error");
		return SNIFF_ERROR_PCAP_OPEN;
	}
	
	// Mark as running
	pthread_mutex_lock(&state_mutex);
	is_running = true;
	pthread_mutex_unlock(&state_mutex);
	
	// Run capture loop (blocking call - should be run in separate thread)
	// pcap_loop returns 0 on success, -1 on error, -2 if breakloop was called
	int result = pcap_loop(handle, -1, packet_callback, NULL);
	
	// Clean up after loop exits
	pthread_mutex_lock(&state_mutex);
	
	if (result == -1) {
		// Error occurred
		const char *error = pcap_geterr(handle);
		if (error != NULL) {
			fprintf(stderr, "Error in pcap_loop: %s\n", error);
		}
	}
	
	// Close handle
	if (handle != NULL) {
		pcap_close(handle);
		handle = NULL;
	}
	
	globalHandler = NULL;
	is_running = false;
	
	pthread_mutex_unlock(&state_mutex);
	
	return (result == 0 || result == -2) ? SNIFF_OK : SNIFF_ERROR_PCAP_OPEN;
}

SniffResult stop_sniffing(void) {
	pthread_mutex_lock(&state_mutex);
	
	if (!is_running || handle == NULL) {
		pthread_mutex_unlock(&state_mutex);
		return SNIFF_ERROR_NOT_RUNNING;
	}
	
	// Break the loop (thread-safe)
	pcap_breakloop(handle);
	
	// Note: pcap_close will be called when pcap_loop returns
	// We don't close here to avoid race conditions
	
	pthread_mutex_unlock(&state_mutex);
	
	return SNIFF_OK;
}

bool is_sniffing_active(void) {
	pthread_mutex_lock(&state_mutex);
	bool active = is_running && handle != NULL;
	pthread_mutex_unlock(&state_mutex);
	return active;
}
