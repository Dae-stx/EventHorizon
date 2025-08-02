# EventHorizon 🌌

**On-Chain Prediction Markets Beyond the Known**

EventHorizon is a decentralized prediction market platform built on the Stacks blockchain where users can create and trade outcome shares for real-world events like elections, sports, and cryptocurrency prices.

## Features

- **Market Creation**: Anyone can create prediction markets with custom duration and resolution periods
- **Advanced AMM Pricing**: Sophisticated automated market maker algorithms for optimal price discovery
- **Dynamic Liquidity**: Constant product formula ensures continuous liquidity and fair pricing
- **Share Trading**: Trade "Yes/No" outcome shares with automated pricing based on AMM algorithms
- **Decentralized Resolution**: Markets are resolved by verified moderators (not market creators to prevent conflicts)
- **STX-Based Betting**: All transactions use STX tokens with transparent fee distribution
- **Event Explorer**: Track market performance, volume, and outcomes
- **Auto-Expiration**: Markets automatically close and enter resolution phase
- **Slippage Protection**: Built-in mechanisms to protect traders from excessive price impact

## How It Works

1. **Create Market**: Users create prediction markets by specifying title, description, and duration
2. **Initial Liquidity**: Markets start with balanced liquidity pools using AMM algorithms
3. **Buy Shares**: Participants purchase "Yes" or "No" shares with prices determined by constant product formula
4. **Price Discovery**: Share prices adjust automatically based on supply/demand through AMM mechanics
5. **Resolution**: After market expiry, authorized resolvers determine the outcome
6. **Claim Winnings**: Winners can claim their proportional share of the total pool

## Advanced Pricing Models

### Constant Product AMM
- Uses the formula `x * y = k` where x and y are pool reserves and k is constant
- Provides continuous liquidity and automatic price adjustment
- Minimizes price manipulation through balanced pool mechanics

### Dynamic Pricing Features
- **Price Impact Calculation**: Shows how trades affect market prices
- **Slippage Tolerance**: Configurable limits to protect against unfavorable price movements
- **Minimum Liquidity**: Ensures markets maintain sufficient depth for fair trading
- **Fee Integration**: Platform fees are seamlessly integrated into AMM calculations

## Smart Contract Functions

### Public Functions
- `create-market`: Create a new prediction market with initial liquidity
- `buy-shares`: Purchase Yes/No shares using AMM pricing
- `add-liquidity`: Add liquidity to existing markets
- `resolve-market`: Resolve market outcome (moderators only)
- `claim-winnings`: Claim winnings from resolved markets

### Read-Only Functions
- `get-market`: Retrieve market information
- `get-user-position`: Check user's position in a market
- `calculate-amm-price`: Get current AMM-based share price
- `calculate-price-impact`: Calculate price impact for a given trade size
- `get-minimum-output`: Calculate minimum shares received for a given input
- `is-market-active`: Check if market is still accepting bets

## Technical Details

- **Platform Fee**: 2.5% fee on all transactions (integrated into AMM)
- **Resolution Window**: 24 hours after market expiry for resolution
- **AMM Model**: Constant product formula with dynamic fee integration
- **Minimum Liquidity**: 100 STX minimum per pool to ensure proper price discovery
- **Slippage Protection**: Built-in calculations to prevent excessive price impact
- **Conflict Prevention**: Market creators cannot resolve their own markets

## Getting Started

1. Deploy the Clarity contract to Stacks blockchain
2. Create your first prediction market with initial liquidity
3. Share with participants to start trading
4. Markets automatically maintain fair pricing through AMM algorithms
5. Resolve markets after events conclude

## Security Features

- Input validation on all parameters with comprehensive checks
- Prevention of self-resolution conflicts
- Time-based market lifecycle management
- Protected admin functions
- AMM-based manipulation resistance
- Minimum liquidity requirements
- Slippage protection mechanisms

## AMM Benefits

- **Fair Price Discovery**: Automatic price adjustment based on market activity
- **Continuous Liquidity**: Always available trading without order books
- **Manipulation Resistance**: Large trades have proportional price impact
- **Transparent Pricing**: All pricing logic is on-chain and verifiable
- **Efficient Markets**: Reduced spreads and improved trading experience