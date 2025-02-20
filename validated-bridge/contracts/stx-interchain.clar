;; Interoperability Bridge Contract

;; Error Constants
(define-constant CONTRACT_ADMINISTRATOR tx-sender)
(define-constant ERR_NOT_ADMINISTRATOR (err u100))
(define-constant ERR_INVALID_INPUT_PARAMETERS (err u101))
(define-constant ERR_INSUFFICIENT_TOKEN_BALANCE (err u102))
(define-constant ERR_UNAUTHORIZED_ACCESS_ATTEMPT (err u103))
(define-constant ERR_BRIDGE_OPERATIONAL_STATUS (err u104))
(define-constant ERR_TRANSFER_RECORD_NOT_FOUND (err u105))
(define-constant ERR_INVALID_SOURCE_CHAIN_ID (err u106))
(define-constant ERR_TRANSFER_AMOUNT_TOO_LOW (err u107))
(define-constant ERR_TRANSFER_AMOUNT_TOO_HIGH (err u108))
(define-constant ERR_DUPLICATE_RELAYER_CONFIRMATION (err u109))
(define-constant ERR_UNAUTHORIZED_RELAYER (err u110))
(define-constant ERR_INVALID_RECIPIENT_ADDRESS (err u111))
(define-constant ERR_INVALID_TRANSACTION_HASH_FORMAT (err u112))
(define-constant ERR_CHAIN_ID_OUT_OF_RANGE (err u113))
(define-constant ERR_TRANSFER_EXPIRED (err u114))
(define-constant ERR_MAX_RELAYERS_REACHED (err u115))

;; Data Variables
(define-data-var minimum-transfer-threshold uint u1000000)
(define-data-var maximum-transfer-threshold uint u1000000000)
(define-data-var bridge-operations-suspended bool false)
(define-data-var minimum-relayer-confirmations uint u3)
(define-data-var maximum-relayers uint u10)
(define-data-var global-transfer-counter uint u0)
(define-data-var supported-chain-id-limit uint u100)
(define-data-var transfer-timeout-blocks uint u1440) ;; ~24 hours in blocks
(define-data-var active-relayer-count uint u0)

;; Data Maps
(define-map token-balance-registry principal uint)
(define-map verified-relayer-registry 
    principal 
    {
        is-active: bool,
        is-suspended: bool,
        last-confirmation-block: uint
    }
)
(define-map user-nonces principal uint)
(define-map completed-transfer-ledger
    {transaction-identifier: (buff 32), origin-chain-id: uint}
    {
        tokens-transferred: uint,
        destination-address: principal,
        transfer-completion-status: (string-ascii 20),
        relayer-confirmation-count: uint,
        transfer-completion-block: uint
    }
)

(define-map pending-transfer-registry
    uint
    {
        tokens-transferred: uint,
        initiator-address: principal,
        destination-address: principal,
        origin-chain-id: uint,
        destination-chain-id: uint,
        transfer-completion-status: (string-ascii 20),
        nonce: uint,
        initiation-block: uint
    }
)

;; Private Functions
(define-private (verify-administrator-privileges)
    (is-eq tx-sender CONTRACT_ADMINISTRATOR)
)

(define-private (verify-relayer-credentials (relayer-address principal))
    (let ((relayer-info (default-to 
        {is-active: false, is-suspended: false, last-confirmation-block: u0}
        (map-get? verified-relayer-registry relayer-address))))
        (begin
            (asserts! (not (is-eq relayer-address CONTRACT_ADMINISTRATOR)) ERR_UNAUTHORIZED_RELAYER)
            (asserts! (get is-active relayer-info) ERR_UNAUTHORIZED_RELAYER)
            (asserts! (not (get is-suspended relayer-info)) ERR_UNAUTHORIZED_RELAYER)
            (ok true)
        )
    )
)

(define-private (validate-blockchain-id (blockchain-id uint))
    (ok (asserts! 
        (and (> blockchain-id u0) (<= blockchain-id (var-get supported-chain-id-limit))) 
        ERR_CHAIN_ID_OUT_OF_RANGE))
)

(define-private (validate-destination-address (destination-address principal))
    (ok (asserts! 
        (and 
            (not (is-eq destination-address CONTRACT_ADMINISTRATOR)) 
            (not (is-eq destination-address tx-sender)))
        ERR_INVALID_RECIPIENT_ADDRESS))
)

(define-private (validate-cross-chain-hash (cross-chain-hash (buff 32)))
    (ok (asserts! 
        (and 
            (is-eq (len cross-chain-hash) u32)
            (not (is-eq cross-chain-hash 0x0000000000000000000000000000000000000000000000000000000000000000)))
        ERR_INVALID_TRANSACTION_HASH_FORMAT))
)

(define-private (validate-transfer-amount (amount uint))
    (begin
        (asserts! (>= amount (var-get minimum-transfer-threshold)) ERR_TRANSFER_AMOUNT_TOO_LOW)
        (asserts! (<= amount (var-get maximum-transfer-threshold)) ERR_TRANSFER_AMOUNT_TOO_HIGH)
        (ok true)
    )
)

(define-private (validate-token-transfer 
    (token-amount uint) 
    (destination-address principal) 
    (destination-chain-id uint)
)
    (begin
        (try! (validate-transfer-amount token-amount))
        (asserts! (is-some (map-get? token-balance-registry tx-sender)) ERR_INSUFFICIENT_TOKEN_BALANCE)
        (asserts! (>= (default-to u0 (map-get? token-balance-registry tx-sender)) token-amount) ERR_INSUFFICIENT_TOKEN_BALANCE)
        (try! (validate-destination-address destination-address))
        (try! (validate-blockchain-id destination-chain-id))
        (ok true)
    )
)

(define-private (check-transfer-timeout (initiation-block uint))
    (ok (asserts! 
        (<= (- block-height initiation-block) (var-get transfer-timeout-blocks))
        ERR_TRANSFER_EXPIRED))
)

;; Public Functions
(define-public (register-authorized-relayer (relayer-address principal))
    (begin
        (asserts! (verify-administrator-privileges) ERR_NOT_ADMINISTRATOR)
        (asserts! (not (is-eq relayer-address CONTRACT_ADMINISTRATOR)) ERR_INVALID_INPUT_PARAMETERS)
        (asserts! (< (var-get active-relayer-count) (var-get maximum-relayers)) ERR_MAX_RELAYERS_REACHED)
        
        (map-set verified-relayer-registry 
            relayer-address 
            {
                is-active: true,
                is-suspended: false,
                last-confirmation-block: u0
            })
        (var-set active-relayer-count (+ (var-get active-relayer-count) u1))
        (ok true)
    )
)

(define-public (suspend-relayer (relayer-address principal))
    (let ((relayer-info (unwrap! (map-get? verified-relayer-registry relayer-address) ERR_UNAUTHORIZED_RELAYER)))
        (begin
            (asserts! (verify-administrator-privileges) ERR_NOT_ADMINISTRATOR)
            (asserts! (not (is-eq relayer-address CONTRACT_ADMINISTRATOR)) ERR_INVALID_INPUT_PARAMETERS)
            (asserts! (get is-active relayer-info) ERR_UNAUTHORIZED_RELAYER)
            
            (map-set verified-relayer-registry 
                relayer-address 
                (merge relayer-info {is-suspended: true}))
            (ok true)
        )
    )
)

(define-public (deactivate-relayer (relayer-address principal))
    (let ((relayer-info (unwrap! (map-get? verified-relayer-registry relayer-address) ERR_UNAUTHORIZED_RELAYER)))
        (begin
            (asserts! (verify-administrator-privileges) ERR_NOT_ADMINISTRATOR)
            (asserts! (not (is-eq relayer-address CONTRACT_ADMINISTRATOR)) ERR_INVALID_INPUT_PARAMETERS)
            (asserts! (get is-active relayer-info) ERR_UNAUTHORIZED_RELAYER)
            
            (map-delete verified-relayer-registry relayer-address)
            (var-set active-relayer-count (- (var-get active-relayer-count) u1))
            (ok true)
        )
    )
)

(define-public (initiate-cross-chain-transfer 
    (token-amount uint)
    (destination-address principal)
    (destination-chain-id uint)
)
    (let (
        (transfer-identifier (var-get global-transfer-counter))
        (initiator-balance (default-to u0 (map-get? token-balance-registry tx-sender)))
        (current-nonce (default-to u0 (map-get? user-nonces tx-sender)))
    )
        ;; Checks
        (asserts! (not (var-get bridge-operations-suspended)) ERR_BRIDGE_OPERATIONAL_STATUS)
        (try! (validate-token-transfer token-amount destination-address destination-chain-id))
        (asserts! (>= initiator-balance token-amount) ERR_INSUFFICIENT_TOKEN_BALANCE)
        
        ;; Effects - Update state
        (map-set pending-transfer-registry transfer-identifier {
            tokens-transferred: token-amount,
            initiator-address: tx-sender,
            destination-address: destination-address,
            origin-chain-id: u1,
            destination-chain-id: destination-chain-id,
            transfer-completion-status: "PENDING",
            nonce: current-nonce,
            initiation-block: block-height
        })
        
        (var-set global-transfer-counter (+ transfer-identifier u1))
        (map-set user-nonces tx-sender (+ current-nonce u1))
        
        ;; Interactions - Update balances
        (map-set token-balance-registry 
            tx-sender 
            (- initiator-balance token-amount)
        )
        
        (ok transfer-identifier)
    )
)

(define-public (confirm-cross-chain-transfer 
    (transfer-identifier uint)
    (cross-chain-hash (buff 32))
)
    (let (
        (transfer-data (unwrap! (map-get? pending-transfer-registry transfer-identifier) ERR_TRANSFER_RECORD_NOT_FOUND))
        (transfer-record {
            transaction-identifier: cross-chain-hash,
            origin-chain-id: (get destination-chain-id transfer-data)
        })
        (processed-record (default-to 
            {
                tokens-transferred: u0,
                destination-address: CONTRACT_ADMINISTRATOR,
                transfer-completion-status: "PENDING",
                relayer-confirmation-count: u0,
                transfer-completion-block: u0
            } 
            (map-get? completed-transfer-ledger transfer-record)))
    )
        ;; Checks
        (try! (verify-relayer-credentials tx-sender))
        (try! (validate-cross-chain-hash cross-chain-hash))
        (try! (check-transfer-timeout (get initiation-block transfer-data)))
        (asserts! (not (var-get bridge-operations-suspended)) ERR_BRIDGE_OPERATIONAL_STATUS)
        (asserts! (< (get relayer-confirmation-count processed-record) (var-get minimum-relayer-confirmations)) ERR_DUPLICATE_RELAYER_CONFIRMATION)
        
        ;; Update relayer's last confirmation block
        (map-set verified-relayer-registry 
            tx-sender 
            (merge 
                (unwrap! (map-get? verified-relayer-registry tx-sender) ERR_UNAUTHORIZED_RELAYER)
                {last-confirmation-block: block-height}
            )
        )
        
        ;; Update transfer records
        (map-set completed-transfer-ledger 
            transfer-record
            {
                tokens-transferred: (get tokens-transferred transfer-data),
                destination-address: (get destination-address transfer-data),
                transfer-completion-status: "CONFIRMED",
                relayer-confirmation-count: (+ (get relayer-confirmation-count processed-record) u1),
                transfer-completion-block: block-height
            }
        )
        
        ;; Check confirmation threshold
        (if (>= (+ (get relayer-confirmation-count processed-record) u1) (var-get minimum-relayer-confirmations))
            (begin
                (try! (validate-blockchain-id (get destination-chain-id transfer-data)))
                (map-set pending-transfer-registry transfer-identifier 
                    (merge transfer-data {transfer-completion-status: "COMPLETED"}))
                (ok true)
            )
            (ok false)
        )
    )
)

;; Getter Functions
(define-read-only (get-transfer-details (transfer-identifier uint))
    (map-get? pending-transfer-registry transfer-identifier)
)

(define-read-only (get-relayer-status (relayer-address principal))
    (map-get? verified-relayer-registry relayer-address)
)

(define-read-only (get-bridge-configuration)
    {
        minimum-transfer-amount: (var-get minimum-transfer-threshold),
        maximum-transfer-amount: (var-get maximum-transfer-threshold),
        required-confirmations: (var-get minimum-relayer-confirmations),
        operations-suspended: (var-get bridge-operations-suspended),
        maximum-chain-id: (var-get supported-chain-id-limit),
        transfer-timeout: (var-get transfer-timeout-blocks),
        max-relayers: (var-get maximum-relayers),
        current-relayer-count: (var-get active-relayer-count)
    }
)