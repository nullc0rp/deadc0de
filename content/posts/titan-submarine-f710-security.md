---
title: "When Your Life Depends on a $30 Gamepad: The Titan Submarine and the F710"
date: 2024-06-22T16:00:00Z
draft: false
tags: ["security", "hardware", "submarine", "wireless", "safety", "titan", "oceangate"]
categories: ["analysis"]
description: "A deep dive into the security implications of using a Logitech F710 gamepad to control a deep-sea submersible, and what the Titan tragedy teaches us about engineering hubris"
---

## Introduction: The Depths of Engineering Hubris

On June 18, 2023, five people descended into the North Atlantic aboard the Titan submersible, each having paid $250,000 for the privilege of visiting the Titanic wreck. They never returned. The implosion of OceanGate's experimental deep-sea vessel didn't just claim five lives—it shattered the mythology of "disrupting" industries where physics doesn't care about your pitch deck.

Netflix's recent documentary "The Deepest Breath" brought renewed attention to this tragedy, highlighting a cascade of engineering decisions that prioritized innovation over safety. Among the many troubling details, one caught the attention of the hacker community: the entire submersible was controlled by a modified Logitech F710 wireless gamepad—the same controller gathering dust in countless closets, relegated there after rage-quitting Dark Souls.

As security researchers, we couldn't help but ask: "Wait, wireless? At the bottom of the ocean? How secure could this possibly be?"

## The Titan's Fatal Flaws: A Masterclass in What Not to Do

Before we dive into the gamepad, let's establish the context of OceanGate's approach to engineering:

### 1. **The Carbon Fiber Hull**
- Traditional deep-sea submersibles use titanium or steel spheres—shapes that distribute pressure evenly
- Titan used a carbon fiber cylinder, a material that's great for aerospace but catastrophically unsuitable for repeated compression cycles
- Cost savings: ~$1.5 million vs $4 million for titanium
- Real cost: 5 lives

### 2. **Lack of Certification**
- OceanGate explicitly refused classification by DNV-GL or other maritime authorities
- CEO Stockton Rush called safety regulations "pure waste"
- No third-party inspection of critical systems
- The sub that imploded had made 13 successful dives—Russian roulette with physics

### 3. **Viewport Rated to 1,300 Meters**
- The Titanic lies at 3,800 meters
- The acrylic viewport was only certified to 1/3 of the operating depth
- Manufacturer explicitly warned against this use
- OceanGate's response: "Innovation requires risk"

### 4. **Acoustic Monitoring System**
- Instead of preventing hull failure, they tried to detect it in real-time
- Like installing a smoke detector instead of following fire codes
- By the time carbon fiber fails acoustically, you have milliseconds

### 5. **The Control System**
- Modified Logitech F710 Wireless Gamepad ($29.99 on Amazon, when in stock)
- Running through a custom software stack
- No redundancy for critical controls
- Wireless communication in a metal tube surrounded by salt water

## The Hacker's Perspective: "They Used WHAT?"

When the hacker community learned about the F710 controller, the collective response was somewhere between horror and morbid fascination. Here's what went through our minds:

### Initial Thoughts:
1. "Please tell me they meant wired..."
2. "They didn't."
3. "Oh no."
4. "Time to order an F710 and tear it apart."

As I detailed in my [previous reverse engineering analysis](/posts/joystick-f710/), what we found was worse than expected.

## Technical Deep Dive: The F710 Security Nightmare

### The Protocol Stack

```
Application Layer: DirectInput/XInput Commands
     ↓
HID Layer: Human Interface Device Protocol  
     ↓
Wireless Layer: 2.4GHz Proprietary Protocol
     ↓
Physical Layer: Unencrypted RF Transmission
```

### Critical Vulnerabilities Identified:

#### 1. **No Encryption Whatsoever**
Every command is transmitted in cleartext. Using a $20 RTL-SDR, you can:
```python
# Pseudocode for interception
def intercept_f710_commands():
    sdr = RTLSDRDevice(frequency=2.4e9)
    while True:
        signal = sdr.read_samples()
        packet = demodulate_fsk(signal)
        if is_f710_packet(packet):
            command = parse_hid_command(packet)
            print(f"Intercepted: {command}")
```

#### 2. **No Authentication Mechanism**
The receiver accepts any properly formatted packet:
```c
// Simplified packet structure
struct F710Packet {
    uint8_t device_id;    // Static, easily spoofed
    uint8_t sequence;     // Predictable increment
    uint16_t buttons;     // No signature
    int8_t axes[4];       // No validation
    uint8_t checksum;     // CRC8, not cryptographic
};
```

#### 3. **Replay Attack Vulnerability**
Commands can be captured and replayed:
```bash
# Capture 10 seconds of "surface" commands
hackrf_transfer -r surface_commands.iq -f 2.4e9 -s 20e6

# Replay at will
hackrf_transfer -t surface_commands.iq -f 2.4e9 -s 20e6
```

#### 4. **Frequency Hopping? More Like Frequency Hoping**
The F710 uses basic frequency hopping across 2.4GHz channels:
- Predictable pattern
- No time synchronization required
- Easily jammed with wideband noise

### The Submarine Environment: Making Bad Worse

The underwater environment adds unique challenges:

1. **RF Propagation in Pressure Vessels**
   - Metal hull creates Faraday cage effects
   - Unpredictable reflections and dead zones
   - Potential for standing waves at 2.4GHz

2. **Electromagnetic Interference**
   - Thrusters generating massive EM fields
   - Life support systems
   - Navigation equipment
   - All operating in close proximity

3. **Salt Water and Electronics**
   - 2.4GHz heavily absorbed by water
   - Any hull breach = instant communication loss
   - Corrosion of RF components

## Attack Scenarios: From Theoretical to Theatrical

### Realistic Attack: The Inside Job
The most plausible attack doesn't require James Cameron's submarine:

```python
# Attack deployed via compromised laptop on support vessel
class TitanAttack:
    def __init__(self):
        self.sdr = HackRFDevice()
        self.target_freq = 2.405e9
        
    def jam_controller(self):
        """Denial of Service - Jam the controller frequency"""
        noise = generate_white_noise(bandwidth=2e6)
        self.sdr.transmit(noise, self.target_freq, power=20)
        
    def inject_commands(self, command_sequence):
        """Send malicious commands"""
        for cmd in command_sequence:
            packet = craft_f710_packet(cmd)
            self.sdr.transmit(packet, self.target_freq)
            time.sleep(0.016)  # 60Hz update rate
            
    def execute_spin_cycle(self):
        """Make submersible spin uncontrollably"""
        spin_commands = [
            {"yaw": 127, "pitch": 0, "thrust": 0},  # Full right
            {"yaw": -127, "pitch": 0, "thrust": 0}, # Full left
        ] * 100
        self.inject_commands(spin_commands)
```

### The Hollywood Scenario: Cameron's Revenge

Since we're going theatrical, let's imagine the full scenario:

**Mission: Operation Deep Hack**

*Equipment Required:*
- 1x Modified Deepsea Challenger (thanks, James!)
- 1x Pressure-resistant SDR suite ($2M custom build)
- 1x Quantum entangled communication system (for live streaming the hack)
- 1x Underwater hacker (must have PADI Advanced Open Water + CISSP)

*The Plan:*
1. Descend to 3,800m (2.5 hour journey)
2. Locate Titan using active sonar (alerting every marine biologist in 50 miles)
3. Approach within 10m without colliding in pitch darkness
4. Deploy the "Hack-topus 3000" - RF tentacles that wrap around Titan
5. Execute attack while dealing with:
   - 380 atmospheres of pressure
   - 2°C water temperature  
   - Zero visibility
   - Crushing existential dread
   - Windows updates on the attack laptop

*Success Rate:* 0.001% (the 0.001% is if Poseidon personally assists)

## The Real Impact: When Theory Meets Reality

### Immediate Consequences of Controller Failure:

1. **Complete Loss of Control**
   - No manual override
   - No mechanical backup
   - No wired emergency system
   - Passengers become spectators to their fate

2. **Cascading System Failures**
   ```
   Controller Fails → No Thrust Control → Current Takes Over →
   Collision with Debris → Hull Damage → Game Over
   ```

3. **Psychological Impact**
   - Imagine knowing your life depends on AAA batteries
   - The same controller that failed during your Rocket League match
   - Now failing at 3,800 meters depth

### Financial Impact:

- Development cost of Titan: ~$15 million
- Cost per dive: ~$250,000 per passenger
- Insurance claims: Likely $50+ million
- OceanGate company value: $0 (bankrupt)
- Industry damage: Immeasurable

### The Regulatory Earthquake:

The Titan disaster triggered:
- Immediate moratorium on experimental deep-sea tourism
- Congressional hearings on maritime safety
- Industry-wide review of classification requirements
- Insurance companies refusing coverage without certification

## Lessons for the Security Community

### 1. **Consumer vs. Industrial Grade**
There's a reason industrial controllers cost $3,000 instead of $30:
- Redundant communication paths
- Cryptographic authentication
- Environmental hardening
- Fail-safe modes
- Extensive testing and certification

### 2. **Wireless in Critical Systems**
If it absolutely must be wireless:
- Use encrypted protocols (AES-256 minimum)
- Implement mutual authentication
- Add jamming detection
- Include wired backup
- Test interference scenarios

### 3. **The "It Works" Fallacy**
"We've used it 13 times without issue" is not a safety validation:
- Carbon fiber degrades with each compression cycle
- Wireless interference is environmental
- Battery life decreases over time
- Luck is not a engineering principle

### 4. **Security Through Obscurity Doesn't Work**
OceanGate assumed nobody would:
- Reverse engineer their custom software
- Interfere with deep-sea operations
- Exploit consumer hardware vulnerabilities
- All assumptions that aged poorly

## Technical Recommendations for Future Systems

### For Submersible Designers:

1. **Primary Control System**
   ```
   Requirements:
   - Wired connection with optical fiber backup
   - Military-spec connectors (rated for pressure)
   - Redundant control paths
   - Cryptographically signed commands
   - Real-time integrity checking
   ```

2. **Emergency Override System**
   ```
   - Mechanical ballast release
   - Acoustic command system (military-grade)
   - Dead man's switch for auto-surface
   - Manual control surfaces
   ```

3. **Wireless Systems (If Absolutely Required)**
   ```python
   class SecureSubmersibleControl:
       def __init__(self):
           self.encryption = AES256_GCM()
           self.auth = Ed25519_Signature()
           self.anti_replay = TimeWindowProtection(window=1.0)
           
       def send_command(self, command):
           timestamp = time.time_ns()
           nonce = os.urandom(12)
           
           # Sign the command
           signature = self.auth.sign(command + timestamp)
           
           # Encrypt command + signature
           ciphertext = self.encryption.encrypt(
               plaintext=command + signature,
               nonce=nonce,
               associated_data=timestamp
           )
           
           # Add anti-replay token
           packet = self.anti_replay.wrap(ciphertext, timestamp)
           
           # Transmit with FEC
           self.transmit_with_redundancy(packet)
   ```

### For Security Researchers:

1. **When Analyzing Life-Critical Systems:**
   - Consider environmental factors
   - Test failure modes extensively
   - Document all vulnerabilities clearly
   - Provide actionable recommendations
   - Remember: Lives depend on your work

2. **Responsible Disclosure:**
   - For active systems: immediate private disclosure
   - Include proof-of-concept with safety guards
   - Suggest specific mitigations
   - Follow up on implementation

## The Bigger Picture: Innovation vs. Safety

Silicon Valley's "move fast and break things" has no place in:
- Submersibles
- Aircraft
- Medical devices  
- Nuclear reactors
- Autonomous vehicles

These industries have safety standards written in blood. ISO 26262, DO-178C, IEC 62304—they exist because people died when corners were cut.

## Conclusion: Respect the Ocean, Respect the Standards

The Titan tragedy wasn't just about a gaming controller—it was about a fundamental misunderstanding of risk. The ocean doesn't care about your minimum viable product. Physics doesn't pivot based on user feedback. At 3,800 meters depth, there are no software patches.

As hackers and security researchers, we have a responsibility. When we see consumer hardware in life-critical applications, we must speak up. When we find vulnerabilities, we must disclose responsibly. When standards are ignored, we must advocate for safety.

The F710 is a perfectly fine gaming controller. I still use mine (wired mode only now). But between my couch and a submarine's command station lies an ocean of engineering requirements that no amount of disruption can bridge.

To the five souls lost on the Titan: Stockton Rush, Hamish Harding, Paul-Henri Nargeolet, Shahzada Dawood, and Suleman Dawood—may your tragedy ensure others don't repeat these mistakes.

To future engineers: Standards aren't obstacles to innovation. They're the shoulders of giants, offering you a view of all the ways things can go wrong, so you can focus on making things go right.

*For the complete technical analysis of the F710 vulnerabilities, including PoC code and packet captures, see my [detailed reverse engineering post](/posts/joystick-f710/).*

---

*Disclaimer: This analysis is for educational purposes. Do not attempt to interfere with any maritime vessels, submersible or otherwise. Also, please return James Cameron's submarine in the condition you borrowed it.*

*If you're designing life-critical systems and using this post as a "what not to do" guide—good. That's the point.*
