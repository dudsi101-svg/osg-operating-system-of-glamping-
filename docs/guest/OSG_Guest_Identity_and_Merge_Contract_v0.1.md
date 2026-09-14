# OSG — Guest Identity & Merge Contract v0.1

Status: pre-freeze additive contract
Date: 2026-09-15

## 1. Problem

The same real guest can arrive through different channels with different spelling, email/phone formatting or incomplete data. OSG must support repeat-guest analytics without destructive or speculative profile merging.

## 2. Principle

A merge is an auditable identity-resolution decision, not a DELETE/UPDATE cleanup operation.

`GuestProfile` remains the canonical CRM identity used by business relations.
Source provenance remains preserved.

## 3. Entities

### GuestIdentitySignal
Normalized identity signal attached to GuestProfile.
Examples:
- EMAIL
- PHONE
- EXTERNAL_CUSTOMER_ID
- HASHED_SOURCE_ID

Fields conceptually:
- guest_profile_id
- signal_type
- normalized_value / protected hash where appropriate
- source
- verified_at
- confidence
- active

### GuestMatchCandidate
A proposed relationship between two GuestProfiles.

Status:
- OPEN
- CONFIRMED_MATCH
- REJECTED
- EXPIRED

Stores:
- match method/version
- evidence summary
- confidence
- created_at/reviewed_at

### GuestMergeEvent
Append-only audit of an accepted canonicalization:
- canonical_guest_profile_id
- merged_guest_profile_id
- reason
- evidence/match_candidate
- actor
- occurred_at

### GuestProfileAlias
Maps historical/merged profile to current canonical profile without rewriting historical source records.

## 4. Merge behavior

After confirmed merge:
- future CRM lookup resolves alias → canonical GuestProfile,
- historical Reservations/Stays may retain original profile reference for provenance,
- semantic analytics resolves through canonical alias mapping,
- ExternalReferences are not deleted,
- conflicting personal fields are not blindly overwritten.

## 5. Automatic matching

Release 1 may automatically create MatchCandidates, but should not auto-merge on weak fuzzy similarity.

High-confidence candidates may include:
- same verified email,
- same verified phone,
- stable external customer identifier from trusted provider.

Name-only fuzzy match is insufficient for automatic merge.

## 6. Split / undo

Because merge decisions can be wrong, canonicalization must be reversible at the alias/resolution layer. Undo creates another auditable identity event rather than deleting merge history.

## 7. Repeat Guest Rate

Repeat Guest metrics resolve completed Stay guests through canonical GuestProfile identity.

Metric confidence must fall if:
- GuestProfile is missing,
- identity is unresolved,
- match relies on low-confidence/manual signals.

## 8. Privacy

Identity signals are PERSONAL and access-controlled.
Normalized values used for matching should be minimized; hashes may be used where lookup requirements allow it.

Marketing consent is not automatically merged as one boolean. Consent events retain their source/time/content version; current consent state is derived according to policy.

## 9. AI

AI may recommend a merge candidate with evidence, but cannot silently merge personal identities. Merge is at least A1/A2 depending on policy and must remain auditable.
