# EventHorizon 🌌

**On-Chain Prediction Markets Beyond the Known**

EventHorizon is a decentralized prediction market platform built on the Stacks blockchain where users can create and trade outcome shares for real-world events like elections, sports, and cryptocurrency prices.

## Features

- **Market Creation**: Anyone can create prediction markets with custom duration and resolution periods
- **Share Trading**: Trade "Yes/No" outcome shares with dynamic pricing based on pool liquidity
- **Decentralized Resolution**: Markets are resolved by verified moderators (not market creators to prevent conflicts)
- **STX-Based Betting**: All transactions use STX tokens with transparent fee distribution
- **Event Explorer**: Track market performance, volume, and outcomes
- **Auto-Expiration**: Markets automatically close and enter resolution phase

## How It Works

1. **Create Market**: Users create prediction markets by specifying title, description, and duration
2. **Buy Shares**: Participants purchase "Yes" or "No" shares based on their predictions
3. **Price Discovery**: Share prices adjust dynamically based on the pool ratios
4. **Resolution**: After market expiry, authorized resolvers determine the outcome
5. **Claim Winnings**: Winners can claim their proportional share of the total pool

## Smart Contract Functions

### Public Functions
- `create-market`: Create a new prediction market
- `buy-shares`: Purchase Yes/No shares in a market
- `resolve-market`: Resolve market outcome (moderators only)
- `claim-winnings`: Claim winnings from resolved markets

### Read-Only Functions
- `get-market`: Retrieve market information
- `get-user-position`: Check user's position in a market
- `calculate-share-price`: Get current share price
- `is-market-active`: Check if market is still accepting bets

## Technical Details

- **Platform Fee**: 2.5% fee on all transactions
- **Resolution Window**: 24 hours after market expiry for resolution
- **Share Model**: 1:1 STX to share ratio for simplicity
- **Conflict Prevention**: Market creators cannot resolve their own markets

## Getting Started

1. Deploy the Clarity contract to Stacks blockchain
2. Create your first prediction market
3. Share with participants to start trading
4. Resolve markets after events conclude

## Security Features

- Input validation on all parameters
- Prevention of self-resolution conflicts
- Time-based market lifecycle management
- Protected admin functions
