# Cybersecurity Attack Patterns — Reference for Sentinel & Game Scenarios

Ingested 2026-03-09. Sources: Roger Grimes *12+ Ways to Hack MFA* (KnowBe4), Professor Messer *CompTIA Security+ SY0-701*.

## MFA Attack Surface

Authentication chain has four stages: **Identity → Secret Storage → Authentication → Authorization**. Attackers exploit gaps between any stage.

**Critical insight**: No matter how someone authenticates (password, fingerprint, MFA token), the resulting access control token is usually the same (Kerberos ticket, NTLM token, HTTP cookie). Steal the token → bypass all authentication.

### Social Engineering MFA Attacks
| Attack | Method | Example |
|---|---|---|
| Fake auth page | Entire login simulated by rogue site | User enters MFA codes into fake |
| Recovery questions | Easily guessed (20% first-try), poorly remembered (40% failure) | Google research confirmed |
| Social engineer support | Call support claiming lost device, urgent deadline | Woman with crying baby took over cell account |

### Technical MFA Attacks
| Attack | Method | Example |
|---|---|---|
| Session hijacking/proxy | MITM via phishing; steal session token | Kevin Mitnick demo'd in 6 min with Evilginx |
| Session ID prediction | Guess sequential/predictable session identifiers | No victim involvement needed |
| Man-in-endpoint | Admin access to victim device; piggyback auth | Banco trojans initiated wire transfers |
| Duplicate code generators | Compromise TOTP seed database | 2011: Chinese APT stole RSA SecurID seeds → broke into Lockheed Martin |
| SIM swap | Transfer victim's number to attacker phone | One victim lost $24M in cryptocurrency |
| Downgrade/recovery | Fall back to weaker backup auth method | Auth only as strong as weakest allowed method |
| Brute force | No rate-limiting on MFA PIN entry | Many new implementations lack lockout |
| Buggy MFA | Software bugs bypass MFA entirely | Uber 2FA bypass (2018); ROCA vulnerability (100M+ smartcards) |

### Biometric Vulnerabilities
- Every "unforgeable" biometric has been forged, usually within days, for under $100
- Readers must be "de-tuned" for usability → susceptible to near-likenesses
- 5.6M fingerprints stolen from US OPM (2015)
- Once compromised, biometrics can't be changed

---

## Security+ Framework Reference

### CIA Triad
- **Confidentiality**: Prevent unauthorized disclosure (encryption, access controls, 2FA)
- **Integrity**: Ensure data not tampered with (hashing, digital signatures, non-repudiation)
- **Availability**: Systems accessible when needed (redundancy, fault tolerance, patching)

### AAA Framework
- **Authentication**: Prove identity (know/have/are)
- **Authorization**: Determine access rights
- **Accounting**: Track user actions (logging, SIEM)

### Threat Actor Taxonomy
| Type | Motivation | Sophistication |
|---|---|---|
| Nation-state (APT) | Intelligence, disruption | Very high, persistent |
| Organized crime | Financial | High, ransomware/data theft |
| Hacktivists | Ideological | Medium, public disruption |
| Insider threats | Various | Has legitimate access |
| Script kiddies | Curiosity, ego | Low, existing tools |

### Social Engineering Attacks
- **Phishing**: email (spear = targeted, whaling = executives, vishing = voice, smishing = SMS)
- **Impersonation**: pretexting with fake identity/authority
- **Watering hole**: compromise sites the target frequents
- **Typosquatting**: misspelled domains

### Technical Vulnerabilities
- Buffer overflows, SQL injection, XSS, race conditions, zero-days
- Ransomware, trojans, rootkits, fileless malware, logic bombs
- MITM/on-path, DNS attacks, replay attacks, DDoS

### Cryptography Quick Reference
- **Symmetric**: AES (fast, same key)
- **Asymmetric**: RSA, ECC (key pairs, solves distribution)
- **Hashing**: SHA-256, SHA-3 (one-way, integrity)
- **Digital signatures**: hash + encrypt with private key
- **PKI**: certificate authorities, chains, trust models

### Incident Response Process
1. Preparation (policies, plans, training)
2. Detection/Analysis (SIEM, log analysis, IoC identification)
3. Containment (isolate affected systems)
4. Eradication (remove threat)
5. Recovery (restore, verify integrity)
6. Lessons Learned (post-incident review)

### Digital Forensics
- **Order of volatility**: memory → disk → logs → network
- **Chain of custody**: document handling
- **Legal hold**: preserve from normal deletion
- **Imaging**: bit-for-bit copy, hash verification

### Risk Management
- Risk = Likelihood × Impact
- Treatments: accept, mitigate, transfer (insurance), avoid
- Quantitative: ALE = ARO × SLE

---

## Application to Substrate

### For Objection! Cyber Court (Case Scenarios)
- SIM swap case, proxy phishing case, insider UPN swap case
- Banking trojan man-in-endpoint case
- Seed database theft (RSA SecurID → Lockheed Martin)
- Recovery/downgrade attack case
- Each maps to a full investigation with evidence chain

### For Sentinel (Security Agent)
- Threat actor taxonomy for categorizing incidents
- Incident response process for structured analysis
- Zero trust principles for infrastructure recommendations
