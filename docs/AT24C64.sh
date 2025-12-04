#!/bin/bash

# Ensure PC/SC daemon is running
pcscd_status=$(pgrep pcscd)
if [[ -z "$pcscd_status" ]]; then
    echo "PC/SC daemon not running. Starting it..."
    sudo systemctl start pcscd
fi

# Function to send an APDU command to the card
send_apdu() {
    local apdu=$1
    response=$(echo -n "$apdu" | xxd -r -p | ccid-tool /dev/pcsc /dev/null)
    echo "APDU Response: $response"
    return 0
}

# Function to write the encrypted blob (keys + counter + HMAC) to the card
write_to_card() {
    # Prepare data (this is a placeholder; you'll need to replace it with actual data)
    # Example: send first 32 bytes (1 page of data for AT24C64)
    encrypted_data=$(xxd -p -c 32 <<< "0102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F20")

    # APDU command to write to card (this needs to be specific to your card's write method)
    # Example: 0xFF, 0xD6 (Write data to the card)
    # APDU format: CLA, INS, P1, P2, Length (LC) of Data, Data bytes (the encrypted data)
    apdu="FF D6 00 00 20 $encrypted_data" # Adjust this for your specific case (e.g., page size)

    # Send the APDU command
    send_apdu "$apdu"

    echo "Write operation completed."
}

# Function to read data from the card (e.g., verify or check the counter)
read_from_card() {
    # APDU to read data (for example, read a block of data)
    # Example: 0xFF, 0xCA (Read data from the card)
    apdu="FF CA 00 00 00"  # Adjust this based on your card's protocol

    response=$(send_apdu "$apdu")
    echo "Read response: $response"

    # Process the response (e.g., check counter, HMAC validation)
}

# Check if card is present
pcsc_scan

# Start the write operation
write_to_card

# Optionally, read from the card for verification
# read_from_card

echo "Smartcard interaction completed."

