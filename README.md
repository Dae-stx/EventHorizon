# EventHorizon 🌌

**Next-Generation Decentralized Prediction Markets with Oracle Integration**

EventHorizon is an advanced decentralized prediction market platform built on the Stacks blockchain, featuring sophisticated AMM algorithms, external oracle integration, and automated market resolution capabilities for real-world events.

## 🚀 Key Features

### Core Functionality
- **Market Creation**: Anyone can create prediction markets with custom parameters and oracle integration
- **Advanced AMM Pricing**: Sophisticated automated market maker using constant product formula (x * y = k)
- **Oracle Integration**: External oracle support for automated and verifiable market resolution
- **Dynamic Liquidity**: Continuous liquidity provision with balanced pool mechanics
- **Share Trading**: Trade "Yes/No" outcome shares with real-time AMM-based pricing
- **Decentralized Resolution**: Multiple resolution methods including oracle-based and community-driven

### Advanced Features
- **Oracle Management**: Comprehensive oracle registration, authorization, and data validation system
- **Auto-Resolution**: Markets can automatically resolve using external oracle data
- **Slippage Protection**: Built-in mechanisms with configurable tolerance levels
- **Price Impact Analysis**: Real-time calculation of trade impact on market prices
- **Multi-Resolution Support**: Both manual and oracle-based resolution methods
- **Enhanced Security**: Comprehensive input validation and principal verification
- **Safe Math Operations**: Overflow protection and division-by-zero prevention

## 🔧 How It Works

### Market Creation & Trading Flow
1. **Market Setup**: Create markets with optional oracle integration for automated resolution
2. **Liquidity Provisioning**: Markets launch with balanced AMM pools using initial liquidity
3. **Oracle Configuration**: Link markets to external oracles for automated data feeds
4. **Share Trading**: Participants buy/sell shares with prices determined by AMM algorithms
5. **Price Discovery**: Continuous price adjustment based on supply/demand through AMM mechanics
6. **Resolution**: Automated oracle resolution or manual resolution by authorized parties
7. **Winnings Distribution**: Proportional payout based on winning shares and total pool

### Oracle Integration Workflow
1. **Oracle Registration**: Authorized operators register oracles with unique identifiers
2. **Data Updates**: Oracle operators provide real-world data with timestamp verification
3. **Market Linking**: Markets can be linked to specific oracles with resolution criteria
4. **Automated Resolution**: Markets resolve automatically when oracle criteria are met
5. **Data Validation**: Built-in validation ensures oracle data freshness and accuracy

## 🧮 Advanced AMM Architecture

### Constant Product Formula
```
x * y = k (where k remains constant)
```
- **x, y**: Reserve amounts for Yes/No pools
- **k**: Constant product maintained across all trades
- **Dynamic Pricing**: Prices adjust automatically based on pool ratios

### Enhanced AMM Features
- **Fee Integration**: Platform fees seamlessly integrated into AMM calculations
- **Slippage Calculation**: Real-time slippage impact analysis
- **Minimum Output**: Guaranteed minimum shares with configurable slippage tolerance
- **Price Impact Protection**: Prevents excessive market manipulation
- **Liquidity Constraints**: Minimum liquidity requirements for market stability
- **Safe Arithmetic**: Protected against overflow and division errors

## 📡 Oracle System

### Oracle Management
- **Registration**: Authorized oracle operators can register data providers
- **Authorization**: Contract owner controls oracle operator permissions
- **Data Validation**: Comprehensive validation of oracle data integrity and freshness
- **Multi-Oracle Support**: Support for multiple oracle providers per platform

### Oracle Data Structure
```clarity
{
  oracle-id: uint,
  data-key: string,
  value: string,
  timestamp: uint,
  block-height: uint,
  verified: bool
}
```

### Resolution Criteria
- **Automated Resolution**: Markets can resolve based on oracle data automatically
- **Data Freshness**: Oracle data must be within validity window (24 hours / 144 blocks)
- **Verification Requirements**: Only verified oracle data can trigger resolutions
- **Fallback Resolution**: Manual resolution available if oracle fails

## 📋 Smart Contract API

### Market Functions
```clarity
;; Create standard market
(create-market title description duration-blocks initial-liquidity)

;; Create oracle-integrated market
(create-oracle-market title description duration oracle-id data-key criteria auto-resolve)

;; Trading functions
(buy-shares market-id bet-yes amount minimum-shares)
(add-liquidity market-id amount)
(claim-winnings market-id)
```

### Oracle Functions
```clarity
;; Oracle management
(register-oracle name)
(update-oracle-data oracle-id data-key value)
(authorize-oracle oracle-operator)
(revoke-oracle-authorization oracle-operator)

;; Resolution functions
(resolve-market-with-oracle market-id)
(resolve-market market-id outcome)
```

### Read-Only Functions
```clarity
;; Market data
(get-market market-id)
(get-user-position market-id user)
(is-market-active market-id)

;; AMM calculations
(calculate-amm-price yes-pool no-pool bet-yes amount-in)
(calculate-price-impact yes-pool no-pool bet-yes amount-in)
(get-minimum-output pools bet-yes amount-in slippage-tolerance)

;; Oracle data
(get-oracle oracle-id)
(get-oracle-data oracle-id data-key)
(is-oracle-authorized oracle-operator)
```

## ⚙️ Technical Specifications

### Platform Parameters
- **Platform Fee**: 2.5% (250 basis points) on all transactions
- **Minimum Liquidity**: 100 STX per pool side for market creation
- **Minimum Duration**: 144 blocks (~24 hours)
- **Maximum Duration**: 52,560 blocks (~1 year)
- **Resolution Window**: 144 blocks (24 hours) after market expiry
- **Oracle Data Validity**: 144 blocks (~24 hours) for data freshness
- **Maximum Slippage**: 50% protection limit
- **Precision**: 1,000,000 units (6 decimal places) for calculations

### Security Measures
- **Input Validation**: Comprehensive validation for all user inputs
- **Principal Verification**: Enhanced validation of user principals
- **Oracle Authorization**: Multi-level authorization system for oracle operators
- **Conflict Prevention**: Market creators cannot resolve their own markets
- **Data Integrity**: Timestamp and block-height validation for oracle data
- **Slippage Protection**: Configurable limits prevent unfavorable trades
- **Safe Math**: Protected arithmetic operations preventing overflows and division by zero
- **Duration Limits**: Markets must be within valid timeframe constraints

### Error Handling
```clarity
;; Comprehensive error codes
ERR_NOT_AUTHORIZED (u100)
ERR_MARKET_NOT_FOUND (u101)
ERR_ORACLE_NOT_AUTHORIZED (u115)
ERR_INVALID_ORACLE_DATA (u117)
ERR_ORACLE_DATA_TOO_OLD (u118)
ERR_INVALID_PRINCIPAL (u121)
ERR_INVALID_DURATION (u122)
ERR_CALCULATION_ERROR (u123)
;; ... and more
```

## 🛡️ Security Features

### Enhanced Validation
- **String Length Validation**: All string inputs validated for proper length
- **Amount Validation**: Comprehensive amount and balance checking
- **Principal Validation**: Enhanced verification of user principals
- **Oracle Data Validation**: Multi-layer validation for oracle data integrity
- **Duration Validation**: Market duration must be within acceptable bounds

### Conflict Prevention
- **Self-Resolution Protection**: Market creators cannot resolve their own markets
- **Oracle Authorization**: Only authorized operators can provide oracle data
- **Data Freshness**: Oracle data must be recent and verified
- **Double-Resolution Prevention**: Markets cannot be resolved multiple times

### AMM Protection
- **Minimum Liquidity**: Ensures sufficient market depth
- **Slippage Limits**: Protects users from excessive price impact
- **Price Impact Calculation**: Transparent pricing impact disclosure
- **Fee Integration**: Platform fees built into AMM calculations
- **Safe Calculations**: All math operations protected against overflow/underflow

## 🚀 Getting Started

### Deployment
1. Deploy the Clarity contract to Stacks blockchain
2. Authorize initial oracle operators
3. Set platform fee parameters
4. Initialize oracle registry

### Creating Markets
1. **Standard Markets**: Create markets with manual resolution
2. **Oracle Markets**: Create markets with automated oracle resolution
3. **Configure Parameters**: Set duration, liquidity, and resolution criteria
4. **Link Oracles**: Connect markets to external data sources

### Oracle Integration
1. **Register Oracle**: Authorized operators register oracle services
2. **Configure Data Keys**: Define data identifiers for market resolution
3. **Set Resolution Criteria**: Specify conditions for automatic resolution
4. **Monitor Data Feeds**: Ensure continuous data updates

## 🔮 Use Cases

### Supported Market Types
- **Political Events**: Elections, policy decisions, referendums
- **Sports Events**: Game outcomes, tournament winners, player statistics  
- **Cryptocurrency**: Price predictions, protocol upgrades, market milestones
- **Economic Indicators**: GDP growth, inflation rates, market indices
- **Technology Events**: Product launches, adoption metrics, development milestones
- **Weather & Climate**: Temperature records, precipitation, natural events

### Oracle Data Sources
- **Price Feeds**: Cryptocurrency and traditional asset prices
- **Sports Results**: Real-time game and tournament outcomes
- **Election Results**: Official voting results and political outcomes
- **Economic Data**: Government and institutional economic indicators
- **Custom APIs**: Integration with specialized data providers

## 📊 Benefits

### For Traders
- **Fair Pricing**: AMM ensures transparent and continuous pricing
- **Liquidity Assurance**: Always available trading without order books
- **Slippage Protection**: Built-in protection against unfavorable price movements
- **Oracle Reliability**: Automated resolution reduces counterparty risk
- **Low Fees**: Competitive 2.5% platform fee structure
- **Safe Operations**: Protected against calculation errors and exploits

### For Market Creators
- **Oracle Integration**: Automated resolution reduces operational overhead
- **Flexible Configuration**: Customizable market parameters and criteria
- **Revenue Opportunities**: Earn from initial liquidity provision
- **Global Reach**: Decentralized platform accessible worldwide
- **Duration Flexibility**: Create markets from 24 hours to 1 year

### For Oracle Operators
- **Revenue Stream**: Earn fees from providing reliable data feeds
- **Reputation Building**: Build credibility through accurate data provision
- **Technical Integration**: Simple API for data updates and management
- **Authorization System**: Controlled access ensures data quality

## 🔄 Recent Updates (v2.0)

### Enhanced Safety & Validation
- ✅ **Safe Math Operations**: Added overflow protection for all arithmetic operations
- ✅ **Division by Zero Prevention**: Comprehensive checks prevent division errors
- ✅ **Duration Constraints**: Markets now have min (24h) and max (1 year) duration limits
- ✅ **Proper Stacks Syntax**: Uses correct `block-height` instead of deprecated syntax
- ✅ **Calculation Error Handling**: New error code (ERR_CALCULATION_ERROR) for math failures
- ✅ **Enhanced Input Validation**: All parameters checked before processing

### Code Quality Improvements
- ✅ **Clarinet Compatible**: Passes `clarinet check` without warnings
- ✅ **No Unchecked Data**: All potentially unsafe operations now wrapped in error handling
- ✅ **Type Safety**: Proper unwrapping of optional values with error propagation
- ✅ **Consistent Error Handling**: Standardized error responses across all functions

