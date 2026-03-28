# Domain Layer

This directory contains interfaces (abstract classes) that define the contracts
between the presentation layer and the data layer.

## Why?
- Widgets depend on interfaces, not Supabase-specific implementations
- Tests can provide mock implementations without touching production code
- Implementations can be swapped (e.g., local-only mode, different backend)

## Structure
- `repositories/` — Data access interfaces
- `services/` — Business logic service interfaces
