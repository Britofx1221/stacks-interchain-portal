# Interoperability Bridge Contract

## Overview
This smart contract implements a secure cross-chain bridge for token transfers between different blockchain networks. The contract includes robust validation mechanisms, multi-relayer confirmation system, and comprehensive administrative controls to ensure secure token transfers across chains.

## Key Features
- Multi-relayer confirmation system requiring multiple validations for transfer completion
- Comprehensive error handling and input validation
- Administrator-controlled relayer management
- Token balance tracking and verification
- Cross-chain transfer state management
- Configurable minimum transfer thresholds and chain ID limits

## Contract Components

### Constants
- Error codes for various validation and operational scenarios
- Administrative controls and access permissions

### Data Storage
- Token balance registry for user accounts
- Verified relayer registry
- Completed transfer ledger
- Pending transfer registry
- Configurable operational parameters

### Core Functions

#### Administrative Functions
1. `register-authorized-relayer`
   - Registers new authorized relayers
   - Restricted to contract administrator
   - Parameters: `relayer-address` (principal)

2. `deactivate-relayer`
   - Removes relayer authorization
   - Restricted to contract administrator
   - Parameters: `relayer-address` (principal)

#### Transfer Operations
1. `initiate-cross-chain-transfer`
   - Initiates a cross-chain token transfer
   - Parameters:
     - `token-amount` (uint)
     - `destination-address` (principal)
     - `destination-chain-id` (uint)
   - Returns: transfer identifier

2. `confirm-cross-chain-transfer`
   - Confirms cross-chain transfer completion by relayers
   - Parameters:
     - `transfer-identifier` (uint)
     - `cross-chain-hash` (buff 32)
   - Requires multiple relayer confirmations

#### Read-Only Functions
1. `get-transfer-details`
   - Retrieves transfer information
   - Parameters: `transfer-identifier` (uint)

2. `get-relayer-authorization-status`
   - Checks relayer authorization status
   - Parameters: `relayer-address` (principal)

3. `get-bridge-configuration`
   - Returns current bridge configuration parameters

## Security Features
- Strict input validation for all parameters
- Multi-relayer confirmation requirement
- Administrator-only access for sensitive operations
- Balance verification before transfers
- Prevention of duplicate confirmations
- Transaction hash format validation
- Chain ID range validation

## Error Handling
The contract includes comprehensive error handling for various scenarios:
- ERR_NOT_ADMINISTRATOR (u100): Unauthorized administrative access
- ERR_INVALID_INPUT_PARAMETERS (u101): Invalid input parameters
- ERR_INSUFFICIENT_TOKEN_BALANCE (u102): Insufficient token balance
- ERR_UNAUTHORIZED_ACCESS_ATTEMPT (u103): Unauthorized access
- ERR_BRIDGE_OPERATIONAL_STATUS (u104): Bridge operational status issues
- ERR_TRANSFER_RECORD_NOT_FOUND (u105): Transfer record not found
- ERR_INVALID_SOURCE_CHAIN_ID (u106): Invalid source chain ID
- ERR_TRANSFER_AMOUNT_TOO_LOW (u107): Transfer amount below threshold
- ERR_DUPLICATE_RELAYER_CONFIRMATION (u108): Duplicate relayer confirmation
- ERR_UNAUTHORIZED_RELAYER (u109): Unauthorized relayer
- ERR_INVALID_RECIPIENT_ADDRESS (u110): Invalid recipient address
- ERR_INVALID_TRANSACTION_HASH_FORMAT (u111): Invalid transaction hash format
- ERR_CHAIN_ID_OUT_OF_RANGE (u112): Chain ID out of valid range

## Usage Guidelines

### Initiating a Transfer
1. Ensure sufficient token balance
2. Specify valid destination address and chain ID
3. Transfer amount must exceed minimum threshold
4. Wait for required number of relayer confirmations

### Relayer Confirmation Process
1. Only authorized relayers can confirm transfers
2. Each transfer requires multiple unique confirmations
3. Valid transaction hash must be provided
4. Transfer status updates automatically upon reaching confirmation threshold

### Administrative Operations
1. Only contract administrator can manage relayers
2. Relayer management includes registration and deactivation
3. Administrator cannot be registered as a relayer

## Configuration Parameters
- Minimum transfer threshold
- Bridge operational status
- Minimum required relayer confirmations
- Global transfer counter
- Supported chain ID limit