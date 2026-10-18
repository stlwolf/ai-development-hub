# ADR-002: Raw protobuf wire-format parser

- **Status:** Accepted
- **Date:** 2026-02-21 (rewritten 2026-10-18)

## Context

Message bodies live in `agentKv:blob` as protobuf. Options: generated `.proto` code, `@bufbuild/protobuf` / `protobufjs`, or a tiny hand-written wire parser.

## Decision

Implement a **zero-dependency raw wire-format parser** in `extension/src/proto/decoder.ts`.

## Rationale

- Only a few fields are needed (text, blob IDs, steps)
- No official `.proto` from Cursor; reverse-engineering a full schema is high cost
- Extra protobuf libraries add little once raw parsing is validated on real blobs

## Consequences

- Cursor schema changes require updating field numbers in `decoder.ts`
- No protobuf runtime in `package.json`
