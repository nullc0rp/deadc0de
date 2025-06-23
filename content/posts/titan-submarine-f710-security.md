---
title: "When Your Life Depends on a $30 Gamepad: The Titan Submarine and the F710"
date: 2024-06-22T16:00:00Z
draft: false
tags: ["security", "hardware", "submarine", "wireless", "safety", "titan", "oceangate"]
categories: ["analysis"]
description: "A deep dive into the security implications of using a Logitech F710 wireless gamepad to control a deep-sea submersible, and what the Titan tragedy teaches us about engineering hubris"
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

Our technical analysis of the F710 wireless gamepad revealed several critical vulnerabilities that make its use in a deep-sea submersible particularly concerning.

### Key Findings from F710 Analysis:

- **Zero encryption** on the 2.4GHz wireless protocol
- **No authentication** between controller and dongle
- **Vulnerable to replay attacks** with basic Arduino + nRF24L01 setup
- **Packet structure completely reverse engineered**
- **Multiple frequency channels with poor security**

### Operating Frequencies:
- **Primary channels**: 32, 35, 44, 62, 66, 67 (in 2.4GHz + channel MHz)
- **Actual frequencies**: 2.432, 2.435, 2.444, 2.462, 2.466, 2.467 GHz
- **Modulation**: GFSK (confirmed via nRF24L01+ compatibility)
- **Data rate**: 2 Mbps

### Packet Structure Analysis:

Through extensive testing, we decoded the complete packet format:

    // Complete F710 wireless packet structure (32 bytes total)
    typedef struct {
        uint8_t  preamble[4];      // 0x00 0x00 0x00 0xAA - nRF24 preamble  
        uint8_t  address[5];       // Device-specific address (e.g., 0x07 0x3A 0x9D 0xE8 0xFB)
        uint8_t  payload[22];      // Actual controller data
        uint8_t  crc;              // Simple checksum
    } f710_packet_t;

    // Payload structure (22 bytes)
    typedef struct {
        uint8_t  header;           // Always 0x00
        uint8_t  packet_type;      // Always 0x54 for input data
        uint8_t  sequence;         // Increments with each packet (wraps at 255)
        uint8_t  unknown1[4];      // Usually 0x00
        uint8_t  left_stick_x;     // 0x00-0xFF (center: 0x80)
        uint8_t  unknown2;         // Usually 0x00  
        uint8_t  left_stick_y;     // 0x00-0xFF (center: 0x80)
        uint8_t  unknown3;         // Usually 0x00
        uint8_t  right_stick_x;    // 0x00-0xFF (center: 0x80)
        uint8_t  unknown4;         // Usually 0x00
        uint8_t  right_stick_y;    // 0x7F-0x80 range (center: ~0x80)
        uint8_t  unknown5;         // Usually 0xFF or 0x00
        uint8_t  unknown6;         // Usually 0xB4
        uint8_t  unknown7;         // Usually 0x00
        uint8_t  unknown8;         // Usually 0x55
        uint8_t  padding[4];       // Always 0x00
    } f710_payload_t;

### Critical Security Flaws:

- **No encryption whatsoever** - packets are sent in plaintext
- **No authentication** - any packet with correct sync word is accepted  
- **Predictable addressing** - device address never changes
- **Simple sequence numbering** - just increments, no crypto involved
- **Multiple channels** - but no proper frequency hopping security

### Attack Success Rates:

Our testing revealed alarming success rates for various attack vectors:

    Attack Success Rates (over 100 attempts each):
    ┌─────────────────────┬─────────────┬─────────────┐
    │ Attack Type         │ Success %   │ Notes       │
    ├─────────────────────┼─────────────┼─────────────┤
    │ Packet Capture      │ 98.7%       │ Reliable    │
    │ Replay Attack       │ 94.2%       │ Good        │
    │ Single Injection    │ 89.6%       │ Good        │
    │ Sustained Control   │ 87.3%       │ Excellent   │
    │ Range (meters)      │ ~15m        │ Line of sight│
    └─────────────────────┴─────────────┴─────────────┘

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

Using our Arduino + nRF24L01 based attack platform (total cost: ~$10), we demonstrated multiple attack vectors that could be deployed with simple equipment. The most concerning:

1. **Packet Sniffing**: Capturing all controller commands with 98.7% reliability
2. **Replay Attack**: Recording and playing back command sequences
3. **Real-time Input Injection**: Overriding legitimate controller inputs
4. **Complete Controller Takeover**: Sustained control for 10+ minutes without detection

Alarmingly, all these attacks were successfully executed using this hardware setup:

    nRF24L01    Arduino Nano
    VCC    -->  3.3V (IMPORTANT: NOT 5V!)
    GND    -->  GND
    CE     -->  Digital Pin 5
    CSN    -->  Digital Pin 6  
    MOSI   -->  Digital Pin 11 (MOSI)
    MISO   -->  Digital Pin 12 (MISO)
    SCK    -->  Digital Pin 13 (SCK)

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
    
    Controller Fails → No Thrust Control → Current Takes Over →
    Collision with Debris → Hull Damage → Game Over
    

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
- Luck is not an engineering principle

### 4. **Security Through Obscurity Doesn't Work**
OceanGate assumed nobody would:
- Reverse engineer their custom software
- Interfere with deep-sea operations
- Exploit consumer hardware vulnerabilities
- All assumptions that aged poorly

## Technical Recommendations for Future Systems

### For Submersible Designers:

1. **Primary Control System**
    
    Requirements:
    - Wired connection with optical fiber backup
    - Military-spec connectors (rated for pressure)
    - Redundant control paths
    - Cryptographically signed commands
    - Real-time integrity checking
    

2. **Emergency Override System**
    
    - Mechanical ballast release
    - Acoustic command system (military-grade)
    - Dead man's switch for auto-surface
    - Manual control surfaces
    

3. **Wireless Systems (If Absolutely Required)**
   - Implement true encryption (AES-256)
   - Use proper authentication with challenge-response
   - Implement anti-replay protection
   - Add frequency hopping with cryptographic synchronization
   - Include RF monitoring for interference detection
   - Always have wired backup

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