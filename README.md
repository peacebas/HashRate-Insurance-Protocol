# HashRate Insurance Protocol (HIP)

A parametric insurance smart contract for Bitcoin miners built on the Stacks blockchain, providing coverage against difficulty adjustments and energy price spikes.

## Overview

The HashRate Insurance Protocol enables Bitcoin miners to purchase insurance policies that automatically pay out when predetermined thresholds are exceeded for:
- **Mining Difficulty**: Protection against sudden difficulty increases
- **Energy Prices**: Coverage for energy cost spikes

## Features

### Core Functionality
- **Policy Creation**: Miners can create customized insurance policies with specific coverage amounts and trigger thresholds
- **Automated Payouts**: Claims are processed automatically when oracle data confirms threshold breaches
- **Oracle Integration**: Secure, authorized oracle system for reliable difficulty and energy price data
- **Risk-Based Pricing**: Premium calculation based on coverage amount and risk multipliers

### Policy Management
- **Active Policy Tracking**: Monitor policy status, coverage periods, and claim history
- **Policy Cancellation**: Cancel policies before activation with premium refunds
- **Miner Profiles**: Track individual miner statistics and claim history

### Administrative Controls
- **Oracle Authorization**: Contract owner can authorize/revoke oracle addresses
- **Fee Management**: Adjustable protocol fees (capped at 10%)
- **Treasury Management**: Protocol fee collection and withdrawal system

## Smart Contract Structure

### Key Components

#### Data Maps
- `policies`: Store policy details including coverage, thresholds, and status
- `oracle-data`: Oracle-submitted difficulty and energy price data
- `authorized-oracles`: Manage oracle permissions
- `miner-profiles`: Track miner statistics and history
- `policy-events`: Log important policy events

#### Constants
- Protocol error codes for standardized error handling
- Maximum fee limits and validation parameters
- Valid data types for oracle submissions

## Usage

### For Miners

#### Creating a Policy
```clarity
(contract-call? .hip create-policy 
  u1000000      ;; coverage-amount (1M microSTX)
  u25000000     ;; difficulty-threshold 
  u150          ;; energy-price-threshold ($/MWh)
  u2016         ;; duration-blocks (~2 weeks)
  u120)         ;; risk-multiplier (120%)
```

#### Processing a Claim
```clarity
(contract-call? .hip process-claim u1) ;; policy-id
```

#### Canceling a Policy
```clarity
(contract-call? .hip cancel-policy u1) ;; policy-id (before activation)
```

### For Oracles

#### Submitting Data
```clarity
(contract-call? .hip submit-oracle-data "difficulty" u25500000)
(contract-call? .hip submit-oracle-data "energy-price" u165)
```

### Read-Only Functions

#### Check Policy Status
```clarity
(contract-call? .hip get-policy u1)
```

#### View Miner Profile
```clarity
(contract-call? .hip get-miner-profile 'SP1234...)
```

#### Calculate Premium
```clarity
(contract-call? .hip calculate-premium u1000000 u120)
```

## Oracle Data Requirements

### Difficulty Data
- **Type**: `"difficulty"`
- **Format**: Current Bitcoin network difficulty as uint
- **Update Frequency**: After each difficulty adjustment (~2 weeks)

### Energy Price Data
- **Type**: `"energy-price"`
- **Format**: Energy price in $/MWh as uint
- **Update Frequency**: Daily or as market conditions change

## Economic Model

### Premium Calculation
- **Base Rate**: 5% of coverage amount
- **Risk Adjustment**: Multiplied by risk factor (typically 100-200%)
- **Protocol Fee**: 2.5% of premium (configurable up to 10%)

### Example Premium Calculation
For a 1M microSTX policy with 120% risk multiplier:
- Base Premium: 50,000 microSTX (5%)
- Risk-Adjusted Premium: 60,000 microSTX
- Protocol Fee: 1,500 microSTX (2.5%)
- **Total Cost**: 61,500 microSTX

## Security Features

### Access Controls
- Owner-only administrative functions
- Oracle authorization system
- Miner-only policy management

### Validation
- Input parameter validation
- Principal address verification  
- Threshold and balance checks
- Policy status verification

### Error Handling
- Comprehensive error codes
- Safe arithmetic operations
- Proper state management

## Deployment

### Prerequisites
- Stacks node access
- Clarinet for testing
- STX tokens for deployment

### Contract Deployment
1. Deploy contract to Stacks testnet/mainnet
2. Initialize oracle authorizations
3. Set appropriate protocol fee rates
4. Fund contract for initial payouts

## Testing

### Test Scenarios
- Policy creation and premium calculation
- Oracle data submission and validation
- Claim processing with threshold validation
- Administrative function access controls
- Edge cases and error conditions

### Integration Testing
- Oracle data feed integration
- Multi-policy scenarios
- Treasury management operations

## Governance

### Protocol Parameters
- **Fee Rate**: Adjustable by contract owner (max 10%)
- **Oracle Authorization**: Managed by contract owner
- **Valid Data Types**: Currently supports difficulty and energy-price

### Upgrade Path
- Contract is immutable once deployed
- New versions require redeployment
- Migration strategies for existing policies

## Risk Considerations

### Smart Contract Risks
- Code audit recommended before mainnet deployment
- Oracle dependency for claim processing
- STX token price volatility affects real coverage value

### Operational Risks
- Oracle reliability and data accuracy
- Network congestion affecting claim processing
- Market manipulation of underlying metrics

## Contributing

### Development Setup
1. Install Clarinet
2. Clone repository
3. Run tests: `clarinet test`
4. Deploy locally: `clarinet deploy`

### Code Standards
- Follow Clarity best practices
- Comprehensive test coverage
- Clear documentation and comments
