# Dice System

The core mechanic of the game: dynamic dice that control spawning,
events, and world state.

## Features
- Runtime-generated dice with variable side counts (D6, D20, etc.)
- Dynamic side reassignment based on game state
- Weighted and constrained RNG to prevent soft-locks
- Dice-driven spawning of enemies, terrain, and world events

This system acts as the game’s primary director, balancing chaos with
player readability.

<p align="center">
  <img src="images/d20_dice.png" width="260">
  <img src="images/dice.png" width="260">
</p>
