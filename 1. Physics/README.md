# Physics Systems

Shared physics-driven systems used across the entire game to create
consistent, emergent interactions.

## Highlights
- Unified water physics affecting **all RigidBody3D objects**
  - Enemies, props, pickups, and environmental debris
- Centralized buoyancy and drag logic to avoid per-entity duplication
- Pickup and throw system with multiplayer-safe authority handling
- Deterministic force application for predictable interactions

These systems allow enemies, objects, and the environment to interact
naturally without special-case logic.

<p align="center">
  <img src="../images/physics.png" width="520">
</p>
