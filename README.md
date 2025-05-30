# Decentralized Escrow Smart Contract

A trustless escrow system built on the Stacks blockchain using Clarity smart contracts. This system enables secure peer-to-peer transactions without requiring trust between parties, with built-in dispute resolution mechanisms.

## Overview

This smart contract provides a decentralized escrow service where:
- Buyers can create escrow agreements with sellers
- Funds are held securely in the contract until release conditions are met
- Disputes can be raised and resolved by authorized arbitrators
- A small fee is collected for each transaction to maintain the service

## Features

### Core Functionality
- **Create Escrow**: Buyers can initiate escrow agreements with sellers
- **Release Funds**: Buyers can release funds to sellers upon satisfaction
- **Dispute Resolution**: Either party can raise disputes for arbitrator review
- **Automated Fee Collection**: 0.5% fee automatically calculated and collected

### Security Features
- Minimum escrow amount (0.5 STX) to prevent spam
- Authorization checks for all critical functions
- Dispute timeout mechanisms
- Comprehensive error handling

### Administrative Controls
- Add/remove arbitrators
- Withdraw collected fees (contract owner only)
- View contract statistics and metrics

## Contract Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `MIN_ESCROW_AMOUNT` | 0.5 STX | Minimum amount for escrow creation |
| `ESCROW_FEE_RATE` | 0.5% | Fee percentage on each transaction |
| `DISPUTE_TIMEOUT_BLOCKS` | 1008 blocks | ~7 days for dispute resolution |

## Main Functions

### Public Functions

#### `create-escrow`
Creates a new escrow agreement between buyer and seller.
- **Parameters**: seller address, amount, description
- **Returns**: escrow ID
- **Requirements**: Minimum amount, sufficient balance

#### `release-escrow`
Releases escrowed funds to the seller (buyer only).
- **Parameters**: escrow ID
- **Requirements**: Must be buyer, escrow not disputed/released

#### `raise-dispute`
Initiates a dispute for arbitrator resolution.
- **Parameters**: escrow ID
- **Requirements**: Must be participant, escrow not released

#### `resolve-dispute`
Resolves disputes and distributes funds (arbitrators only).
- **Parameters**: escrow ID, winner, resolution notes
- **Requirements**: Must be active arbitrator

### Read-Only Functions

#### `get-escrow-details`
Retrieves complete escrow information by ID.

#### `get-contract-stats`
Returns contract statistics including total escrows and fees.

#### `calculate-fee`
Calculates the fee for a given escrow amount.

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 200 | ERR_UNAUTHORIZED | Caller not authorized for this action |
| 201 | ERR_INSUFFICIENT_BALANCE | Insufficient STX balance |
| 202 | ERR_INVALID_AMOUNT | Amount below minimum threshold |
| 203 | ERR_ESCROW_NOT_FOUND | Escrow ID does not exist |
| 204 | ERR_ESCROW_ALREADY_RELEASED | Escrow already completed |
| 205 | ERR_INVALID_PARTICIPANT | Invalid buyer/seller address |
| 206 | ERR_ESCROW_NOT_EXPIRED | Escrow timeout not reached |
| 207 | ERR_DISPUTE_ALREADY_RAISED | Dispute already in progress |

## Usage Example

```clarity
;; Create an escrow for 10 STX
(contract-call? .escrow create-escrow 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u10000000 "Payment for services")

;; Release escrow (as buyer)
(contract-call? .escrow release-escrow u1)

;; Raise dispute (as participant)
(contract-call? .escrow raise-dispute u1)
```

## Deployment

1. Deploy the contract to Stacks blockchain
2. Add initial arbitrators using `add-arbitrator`
3. Contract is ready for escrow creation

## Security Considerations

- All funds are held securely in the contract until release
- Only authorized arbitrators can resolve disputes
- Contract owner controls arbitrator management and fee withdrawal
- Comprehensive input validation prevents common attack vectors

## License

This smart contract is provided as-is for educational and commercial use. Please review and audit before production deployment.

## Contributing

Contributions are welcome! Please ensure all changes include appropriate tests and documentation updates.
```
