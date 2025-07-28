# Battle Royale Game - Game Mechanics

## Overview
The Battle Royale Game implements a competitive elimination-style game where players compete until only one remains.

## Game Flow

### 1. Lobby Phase
- Players join by calling `joinGame()` and paying entry fee
- Minimum 4 players, maximum 20 players per game
- Game auto-starts when minimum players reached
- Entry fees accumulate into prize pool

### 2. Battle Phase  
- Game state changes to "InProgress"
- Players compete in elimination-style gameplay
- Owner/Game manager eliminates players via `eliminatePlayer()`
- Game continues until 1 player remains

### 3. Resolution Phase
- Winner declared via `declareWinner()`
- Prizes automatically distributed:
  - Winner: 80% of prize pool
  - Second place: 15% of prize pool  
  - Platform: 5% fee
- New lobby automatically created

## Core Functions

### joinGame()
- **Purpose**: Enter current game lobby
- **Payment**: Must send entry fee (default 0.01 ETH)
- **Requirements**: Not already in game, lobby not full
- **Effect**: Added to player list, prize pool increased

### startGame()
- **Purpose**: Begin the battle phase
- **Caller**: Anyone (but auto-triggers at min players)
- **Requirements**: Minimum players met, game in lobby state
- **Effect**: Game state changes, timer starts

### declareWinner()
- **Purpose**: End game and distribute prizes
- **Caller**: Only contract owner/game manager
- **Requirements**: Game in progress, valid winner
- **Effect**: Prizes distributed, stats updated, new lobby created

## Prize Distribution

**Prize Pool Breakdown:**
- Entry fees from all players
- Winner receives 80% of remaining pool (after platform fee)
- Second place receives 20% of remaining pool
- Platform fee: 5% of total pool

## Security Features

- **ReentrancyGuard**: Prevents reentrancy attacks
- **Access Control**: Critical functions restricted to owner
- **Time Limits**: Games have maximum duration
- **Emergency Functions**: Handle stuck games
- **Input Validation**: All parameters validated

## Player Statistics

The contract tracks:
- Total wins per player
- Total earnings per player  
- Current game participation
- Game history and performance

## Emergency Mechanisms

- **emergencyEndGame()**: Refund players if game gets stuck
- **Time limits**: Automatic game expiration
- **Owner controls**: Administrative functions for game management

  ## Contract Details : 0xb9BC8Ed587d76CcadBe40fF888abc98Df3390518
  <img width="1918" height="870" alt="image" src="https://github.com/user-attachments/assets/af91bc1e-f0e2-4fa9-8f5c-afd427759a80" />
