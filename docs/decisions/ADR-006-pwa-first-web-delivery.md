# ADR-006 — PWA-first web delivery

Status: accepted
Date: 2026-09-14

## Decision

First production client is a responsive web application with PWA capabilities. Native iOS/Android applications are not part of Release 1.

## Why

OSG is primarily an operational/management system used across desktop, tablet and phone. PWA reduces duplicated client code and accelerates iteration.

## Consequences

- responsive UX is mandatory
- offline behavior is selective, not blanket
- installable manifest/service worker may be added where useful
- native apps remain possible later without changing domain/API contracts
