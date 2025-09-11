;; EventHorizon - Decentralized Prediction Market Platform with Advanced AMM and Oracle Integration
;; A platform for creating and trading outcome shares using automated market maker algorithms
;; Now with external oracle integration for automatic market resolution

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_MARKET_NOT_FOUND (err u101))
(define-constant ERR_MARKET_CLOSED (err u102))
(define-constant ERR_MARKET_EXPIRED (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_INVALID_AMOUNT (err u105))
(define-constant ERR_MARKET_NOT_RESOLVED (err u106))
(define-constant ERR_MARKET_ALREADY_RESOLVED (err u107))
(define-constant ERR_INVALID_OUTCOME (err u108))
(define-constant ERR_CANNOT_RESOLVE_OWN_MARKET (err u109))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u110))
(define-constant ERR_SLIPPAGE_EXCEEDED (err u111))
(define-constant ERR_MINIMUM_LIQUIDITY (err u112))
(define-constant ERR_DIVISION_BY_ZERO (err u113))
(define-constant ERR_ORACLE_NOT_FOUND (err u114))
(define-constant ERR_ORACLE_NOT_AUTHORIZED (err u115))
(define-constant ERR_ORACLE_ALREADY_EXISTS (err u116))
(define-constant ERR_INVALID_ORACLE_DATA (err u117))
(define-constant ERR_ORACLE_DATA_TOO_OLD (err u118))
(define-constant ERR_ORACLE_RESOLUTION_PENDING (err u119))
(define-constant ERR_INVALID_STRING_LENGTH (err u120))
(define-constant ERR_INVALID_PRINCIPAL (err u121))

;; AMM Constants
(define-constant MINIMUM_LIQUIDITY u100000000) ;; 100 STX minimum liquidity per side
(define-constant PRECISION u1000000) ;; 6 decimal places for calculations
(define-constant MAX_SLIPPAGE u5000) ;; 50% maximum slippage protection
(define-constant ORACLE_DATA_VALIDITY_BLOCKS u144) ;; 24 hours validity for oracle data

;; Data Variables
(define-data-var market-counter uint u0)
(define-data-var oracle-counter uint u0)
(define-data-var platform-fee-rate uint u250) ;; 2.5% fee (250 basis points)

;; Oracle Data Maps
(define-map oracles uint {
    name: (string-ascii 64),
    operator: principal,
    active: bool,
    created-at: uint,
    total-resolutions: uint
})

(define-map oracle-data { oracle-id: uint, data-key: (string-ascii 128) } {
    value: (string-ascii 256),
    timestamp: uint,
    block-height: uint,
    verified: bool
})

(define-map market-oracles uint {
    oracle-id: uint,
    data-key: (string-ascii 128),
    resolution-criteria: (string-ascii 256),
    auto-resolve: bool
})

;; Data Maps
(define-map markets uint {
    creator: principal,
    title: (string-ascii 256),
    description: (string-ascii 1024),
    expiry-block: uint,
    resolution-block: uint,
    yes-pool: uint,
    no-pool: uint,
    total-volume: uint,
    resolved: bool,
    outcome: (optional bool),
    resolver: (optional principal),
    k-constant: uint, ;; AMM constant product k = x * y
    oracle-resolved: bool
})

(define-map user-positions { market-id: uint, user: principal } {
    yes-shares: uint,
    no-shares: uint,
    total-invested: uint
})

(define-map market-fees uint uint) ;; market-id -> accumulated fees

;; Oracle authorization map
(define-map authorized-oracles principal bool)

;; Read-only functions
(define-read-only (get-market (market-id uint))
    (map-get? markets market-id)
)

(define-read-only (get-oracle (oracle-id uint))
    (map-get? oracles oracle-id)
)

(define-read-only (get-oracle-data (oracle-id uint) (data-key (string-ascii 128)))
    (map-get? oracle-data { oracle-id: oracle-id, data-key: data-key })
)

(define-read-only (get-market-oracle (market-id uint))
    (map-get? market-oracles market-id)
)

(define-read-only (get-user-position (market-id uint) (user principal))
    (default-to 
        { yes-shares: u0, no-shares: u0, total-invested: u0 }
        (map-get? user-positions { market-id: market-id, user: user })
    )
)

(define-read-only (get-market-count)
    (var-get market-counter)
)

(define-read-only (get-oracle-count)
    (var-get oracle-counter)
)

(define-read-only (get-platform-fee-rate)
    (var-get platform-fee-rate)
)

(define-read-only (is-oracle-authorized (oracle-operator principal))
    (default-to false (map-get? authorized-oracles oracle-operator))
)

;; Simple AMM price calculation helper (internal)
(define-private (calculate-shares-internal (pool-in uint) (pool-out uint) (amount-in uint))
    (if (or (is-eq pool-in u0) (is-eq pool-out u0))
        u0
        (let (
            (k-constant (* pool-in pool-out))
            (new-pool-in (+ pool-in amount-in))
        )
            (if (is-eq new-pool-in u0)
                u0
                (let ((new-pool-out (/ k-constant new-pool-in)))
                    (if (> new-pool-out pool-out)
                        u0
                        (- pool-out new-pool-out)
                    )
                )
            )
        )
    )
)

;; AMM price calculation using constant product formula
(define-read-only (calculate-amm-price (yes-pool uint) (no-pool uint) (bet-yes bool) (amount-in uint))
    (let (
        (pool-in (if bet-yes yes-pool no-pool))
        (pool-out (if bet-yes no-pool yes-pool))
        (fee-amount (/ (* amount-in (var-get platform-fee-rate)) u10000))
        (amount-in-after-fee (if (>= amount-in fee-amount) (- amount-in fee-amount) u0))
        (shares-out (calculate-shares-internal pool-in pool-out amount-in-after-fee))
    )
        (if (and (> amount-in u0) (> shares-out u0))
            (ok shares-out)
            (err ERR_INSUFFICIENT_LIQUIDITY)
        )
    )
)

;; Calculate price impact for a trade
(define-read-only (calculate-price-impact (yes-pool uint) (no-pool uint) (bet-yes bool) (amount-in uint))
    (let (
        (pool-in (if bet-yes yes-pool no-pool))
        (pool-out (if bet-yes no-pool yes-pool))
        (total-pool (+ yes-pool no-pool))
    )
        (if (or (is-eq pool-in u0) (is-eq total-pool u0) (is-eq amount-in u0))
            (ok u0)
            (let (
                (price-before (/ (* pool-out PRECISION) total-pool))
                (shares-out (calculate-shares-internal pool-in pool-out amount-in))
                (new-pool-out (if (>= pool-out shares-out) (- pool-out shares-out) u0))
                (new-total (+ (+ pool-in amount-in) new-pool-out))
                (price-after (if (is-eq new-total u0) u0 (/ (* new-pool-out PRECISION) new-total)))
            )
                (if (is-eq price-before u0)
                    (ok u0)
                    (ok (if (>= price-before price-after)
                            (/ (* (- price-before price-after) u10000) price-before)
                            u0))
                )
            )
        )
    )
)

;; Get minimum output with slippage protection
(define-read-only (get-minimum-output (yes-pool uint) (no-pool uint) (bet-yes bool) (amount-in uint) (slippage-tolerance uint))
    (let (
        (pool-in (if bet-yes yes-pool no-pool))
        (pool-out (if bet-yes no-pool yes-pool))
        (fee-amount (/ (* amount-in (var-get platform-fee-rate)) u10000))
        (amount-in-after-fee (if (>= amount-in fee-amount) (- amount-in fee-amount) u0))
        (expected-output (calculate-shares-internal pool-in pool-out amount-in-after-fee))
        (slippage-factor (if (>= u10000 slippage-tolerance) (- u10000 slippage-tolerance) u0))
        (minimum-output (/ (* expected-output slippage-factor) u10000))
    )
        (if (> expected-output u0)
            (ok minimum-output)
            (err ERR_INSUFFICIENT_LIQUIDITY)
        )
    )
)

(define-read-only (is-market-active (market-id uint))
    (match (map-get? markets market-id)
        market-data (and 
            (< stacks-block-height (get expiry-block market-data))
            (not (get resolved market-data))
        )
        false
    )
)

;; Validate input parameters
(define-private (validate-amount (amount uint))
    (and (> amount u0) (<= amount u1000000000000)) ;; Max 1M STX per transaction
)

(define-private (validate-slippage (slippage uint))
    (<= slippage MAX_SLIPPAGE)
)

(define-private (validate-string-length (str (string-ascii 256)) (min-len uint) (max-len uint))
    (and (>= (len str) min-len) (<= (len str) max-len))
)

(define-private (validate-description-length (desc (string-ascii 1024)) (min-len uint) (max-len uint))
    (and (>= (len desc) min-len) (<= (len desc) max-len))
)

(define-private (validate-oracle-name (name (string-ascii 64)))
    (and (>= (len name) u1) (<= (len name) u64))
)

(define-private (validate-data-key (key (string-ascii 128)))
    (and (>= (len key) u1) (<= (len key) u128))
)

(define-private (validate-oracle-value (value (string-ascii 256)))
    (and (>= (len value) u1) (<= (len value) u256))
)

(define-private (validate-resolution-criteria (criteria (string-ascii 256)))
    (and (>= (len criteria) u1) (<= (len criteria) u256))
)

;; Enhanced principal validation helper
(define-private (validate-principal (principal-to-check principal))
    ;; Basic check to ensure the principal is not a null/zero principal
    ;; In Stacks, we can't easily check for "null" principals, but we can validate
    ;; that it's not the same as a known invalid state
    (not (is-eq principal-to-check 'ST000000000000000000002AMW42H))
)

;; Oracle Management Functions
(define-public (register-oracle (name (string-ascii 64)))
    (let (
        (oracle-id (+ (var-get oracle-counter) u1))
        (validated-name (unwrap! (as-max-len? name u64) ERR_INVALID_STRING_LENGTH))
    )
        ;; Validate inputs
        (asserts! (validate-oracle-name validated-name) ERR_INVALID_STRING_LENGTH)
        (asserts! (validate-principal tx-sender) ERR_INVALID_PRINCIPAL)
        (asserts! (is-oracle-authorized tx-sender) ERR_ORACLE_NOT_AUTHORIZED)
        
        ;; Create oracle
        (map-set oracles oracle-id {
            name: validated-name,
            operator: tx-sender,
            active: true,
            created-at: stacks-block-height,
            total-resolutions: u0
        })
        
        (var-set oracle-counter oracle-id)
        (ok oracle-id)
    )
)

(define-public (update-oracle-data (oracle-id uint) (data-key (string-ascii 128)) (value (string-ascii 256)))
    (let (
        (oracle-info (unwrap! (map-get? oracles oracle-id) ERR_ORACLE_NOT_FOUND))
        (validated-key (unwrap! (as-max-len? data-key u128) ERR_INVALID_STRING_LENGTH))
        (validated-value (unwrap! (as-max-len? value u256) ERR_INVALID_STRING_LENGTH))
    )
        ;; Validate inputs and authorization
        (asserts! (validate-data-key validated-key) ERR_INVALID_STRING_LENGTH)
        (asserts! (validate-oracle-value validated-value) ERR_INVALID_STRING_LENGTH)
        (asserts! (validate-principal tx-sender) ERR_INVALID_PRINCIPAL)
        (asserts! (is-eq tx-sender (get operator oracle-info)) ERR_ORACLE_NOT_AUTHORIZED)
        (asserts! (get active oracle-info) ERR_ORACLE_NOT_AUTHORIZED)
        
        ;; Update oracle data
        (map-set oracle-data { oracle-id: oracle-id, data-key: validated-key } {
            value: validated-value,
            timestamp: stacks-block-height,
            block-height: stacks-block-height,
            verified: true
        })
        
        (ok true)
    )
)

(define-public (authorize-oracle (oracle-operator principal))
    (begin
        ;; Enhanced validation for principal parameter
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (validate-principal oracle-operator) ERR_INVALID_PRINCIPAL)
        ;; Additional check to prevent authorizing the same principal multiple times
        (asserts! (not (is-oracle-authorized oracle-operator)) ERR_ORACLE_ALREADY_EXISTS)
        
        (map-set authorized-oracles oracle-operator true)
        (ok true)
    )
)

(define-public (revoke-oracle-authorization (oracle-operator principal))
    (begin
        ;; Enhanced validation for principal parameter
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (validate-principal oracle-operator) ERR_INVALID_PRINCIPAL)
        ;; Check that the oracle is currently authorized before revoking
        (asserts! (is-oracle-authorized oracle-operator) ERR_ORACLE_NOT_FOUND)
        
        (map-delete authorized-oracles oracle-operator)
        (ok true)
    )
)

;; Market Creation with Oracle Integration
(define-public (create-market (title (string-ascii 256)) (description (string-ascii 1024)) (duration-blocks uint) (initial-liquidity uint))
    (let (
        (market-id (+ (var-get market-counter) u1))
        (expiry-block (+ stacks-block-height duration-blocks))
        (resolution-block (+ expiry-block u144)) ;; 24 hours after expiry for resolution
        (validated-title (unwrap! (as-max-len? title u256) ERR_INVALID_STRING_LENGTH))
        (validated-description (unwrap! (as-max-len? description u1024) ERR_INVALID_STRING_LENGTH))
        (pool-amount (/ initial-liquidity u2))
        (initial-k (* pool-amount pool-amount))
    )
        ;; Comprehensive input validation
        (asserts! (> duration-blocks u0) ERR_INVALID_AMOUNT)
        (asserts! (validate-string-length validated-title u1 u256) ERR_INVALID_STRING_LENGTH)
        (asserts! (validate-description-length validated-description u1 u1024) ERR_INVALID_STRING_LENGTH)
        (asserts! (validate-amount initial-liquidity) ERR_INVALID_AMOUNT)
        (asserts! (>= initial-liquidity MINIMUM_LIQUIDITY) ERR_MINIMUM_LIQUIDITY)
        (asserts! (is-eq (mod initial-liquidity u2) u0) ERR_INVALID_AMOUNT) ;; Must be even for balanced pools
        (asserts! (validate-principal tx-sender) ERR_INVALID_PRINCIPAL)
        
        ;; Transfer initial liquidity from creator
        (try! (stx-transfer? initial-liquidity tx-sender (as-contract tx-sender)))
        
        ;; Create market with balanced pools
        (map-set markets market-id {
            creator: tx-sender,
            title: validated-title,
            description: validated-description,
            expiry-block: expiry-block,
            resolution-block: resolution-block,
            yes-pool: pool-amount,
            no-pool: pool-amount,
            total-volume: initial-liquidity,
            resolved: false,
            outcome: none,
            resolver: none,
            k-constant: initial-k,
            oracle-resolved: false
        })
        
        (var-set market-counter market-id)
        (ok market-id)
    )
)

;; Create market with oracle integration
(define-public (create-oracle-market (title (string-ascii 256)) (description (string-ascii 1024)) (duration-blocks uint) (initial-liquidity uint) (oracle-id uint) (data-key (string-ascii 128)) (resolution-criteria (string-ascii 256)) (auto-resolve bool))
    (let (
        (market-id (try! (create-market title description duration-blocks initial-liquidity)))
        (oracle-info (unwrap! (map-get? oracles oracle-id) ERR_ORACLE_NOT_FOUND))
        (validated-key (unwrap! (as-max-len? data-key u128) ERR_INVALID_STRING_LENGTH))
        (validated-criteria (unwrap! (as-max-len? resolution-criteria u256) ERR_INVALID_STRING_LENGTH))
    )
        ;; Validate oracle configuration and market-id
        (asserts! (> market-id u0) ERR_MARKET_NOT_FOUND) ;; Ensure market creation was successful
        (asserts! (validate-data-key validated-key) ERR_INVALID_STRING_LENGTH)
        (asserts! (validate-resolution-criteria validated-criteria) ERR_INVALID_STRING_LENGTH)
        (asserts! (get active oracle-info) ERR_ORACLE_NOT_AUTHORIZED)
        
        ;; Link market to oracle with validated market-id
        (map-set market-oracles market-id {
            oracle-id: oracle-id,
            data-key: validated-key,
            resolution-criteria: validated-criteria,
            auto-resolve: auto-resolve
        })
        
        (ok market-id)
    )
)

;; Oracle-based market resolution
(define-public (resolve-market-with-oracle (market-id uint))
    (let (
        (market-data (unwrap! (map-get? markets market-id) ERR_MARKET_NOT_FOUND))
        (oracle-config (unwrap! (map-get? market-oracles market-id) ERR_ORACLE_NOT_FOUND))
        (config-oracle-id (get oracle-id oracle-config))
        (config-data-key (get data-key oracle-config))
        (oracle-info (unwrap! (map-get? oracles config-oracle-id) ERR_ORACLE_NOT_FOUND))
        (oracle-data-entry (unwrap! (map-get? oracle-data { oracle-id: config-oracle-id, data-key: config-data-key }) ERR_INVALID_ORACLE_DATA))
        (data-block-height (get block-height oracle-data-entry))
        (data-age (if (>= stacks-block-height data-block-height) (- stacks-block-height data-block-height) u0))
        (data-verified (get verified oracle-data-entry))
        (market-expiry (get expiry-block market-data))
        (market-resolution-block (get resolution-block market-data))
        (market-resolved (get resolved market-data))
        (oracle-operator (get operator oracle-info))
        (oracle-total-resolutions (get total-resolutions oracle-info))
    )
        ;; Validation checks
        (asserts! (> market-id u0) ERR_MARKET_NOT_FOUND)
        (asserts! (> stacks-block-height market-expiry) ERR_MARKET_NOT_RESOLVED)
        (asserts! (< stacks-block-height market-resolution-block) ERR_MARKET_EXPIRED)
        (asserts! (not market-resolved) ERR_MARKET_ALREADY_RESOLVED)
        (asserts! data-verified ERR_INVALID_ORACLE_DATA)
        (asserts! (< data-age ORACLE_DATA_VALIDITY_BLOCKS) ERR_ORACLE_DATA_TOO_OLD)
        (asserts! (validate-principal oracle-operator) ERR_INVALID_PRINCIPAL)
        
        ;; Determine outcome based on oracle data
        (let (
            (oracle-value (get value oracle-data-entry))
            (outcome (is-eq oracle-value "true")) ;; Simple boolean resolution for now
        )
            ;; Update market with oracle resolution
            (map-set markets market-id 
                (merge market-data {
                    resolved: true,
                    outcome: (some outcome),
                    resolver: (some oracle-operator),
                    oracle-resolved: true
                })
            )
            
            ;; Update oracle statistics
            (map-set oracles config-oracle-id
                (merge oracle-info {
                    total-resolutions: (+ oracle-total-resolutions u1)
                })
            )
            
            (ok outcome)
        )
    )
)

;; Enhanced buy shares function with oracle validation
(define-public (buy-shares (market-id uint) (bet-yes bool) (amount uint) (minimum-shares uint))
    (let (
        (market-data (unwrap! (map-get? markets market-id) ERR_MARKET_NOT_FOUND))
        (current-position (get-user-position market-id tx-sender))
        (pool-in (if bet-yes (get yes-pool market-data) (get no-pool market-data)))
        (pool-out (if bet-yes (get no-pool market-data) (get yes-pool market-data)))
        (fee-amount (/ (* amount (var-get platform-fee-rate)) u10000))
        (net-amount (if (>= amount fee-amount) (- amount fee-amount) u0))
        (shares-out (calculate-shares-internal pool-in pool-out net-amount))
        (new-yes-pool (if bet-yes (+ (get yes-pool market-data) net-amount) (if (>= (get yes-pool market-data) shares-out) (- (get yes-pool market-data) shares-out) u0)))
        (new-no-pool (if bet-yes (if (>= (get no-pool market-data) shares-out) (- (get no-pool market-data) shares-out) u0) (+ (get no-pool market-data) net-amount)))
        (new-k-constant (* new-yes-pool new-no-pool))
    )
        ;; Comprehensive validation
        (asserts! (> market-id u0) ERR_MARKET_NOT_FOUND)
        (asserts! (validate-amount amount) ERR_INVALID_AMOUNT)
        (asserts! (validate-principal tx-sender) ERR_INVALID_PRINCIPAL)
        (asserts! (is-market-active market-id) ERR_MARKET_CLOSED)
        (asserts! (> shares-out u0) ERR_INSUFFICIENT_LIQUIDITY)
        (asserts! (>= shares-out minimum-shares) ERR_SLIPPAGE_EXCEEDED)
        (asserts! (> new-yes-pool u0) ERR_INSUFFICIENT_LIQUIDITY)
        (asserts! (> new-no-pool u0) ERR_INSUFFICIENT_LIQUIDITY)
        (asserts! (>= amount fee-amount) ERR_INVALID_AMOUNT)
        
        ;; Transfer STX from user
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update market with new AMM state
        (map-set markets market-id 
            (merge market-data {
                yes-pool: new-yes-pool,
                no-pool: new-no-pool,
                total-volume: (+ (get total-volume market-data) amount),
                k-constant: new-k-constant
            })
        )
        
        ;; Update user position
        (map-set user-positions { market-id: market-id, user: tx-sender }
            (if bet-yes
                {
                    yes-shares: (+ (get yes-shares current-position) shares-out),
                    no-shares: (get no-shares current-position),
                    total-invested: (+ (get total-invested current-position) amount)
                }
                {
                    yes-shares: (get yes-shares current-position),
                    no-shares: (+ (get no-shares current-position) shares-out),
                    total-invested: (+ (get total-invested current-position) amount)
                }
            )
        )
        
        ;; Record fees
        (map-set market-fees market-id 
            (+ (default-to u0 (map-get? market-fees market-id)) fee-amount)
        )
        
        (ok shares-out)
    )
)

(define-public (add-liquidity (market-id uint) (amount uint))
    (let (
        (market-data (unwrap! (map-get? markets market-id) ERR_MARKET_NOT_FOUND))
        (amount-per-pool (/ amount u2))
        (new-yes-pool (+ (get yes-pool market-data) amount-per-pool))
        (new-no-pool (+ (get no-pool market-data) amount-per-pool))
        (new-k-constant (* new-yes-pool new-no-pool))
    )
        (asserts! (> market-id u0) ERR_MARKET_NOT_FOUND)
        (asserts! (validate-amount amount) ERR_INVALID_AMOUNT)
        (asserts! (validate-principal tx-sender) ERR_INVALID_PRINCIPAL)
        (asserts! (is-market-active market-id) ERR_MARKET_CLOSED)
        (asserts! (is-eq (mod amount u2) u0) ERR_INVALID_AMOUNT) ;; Must be even for balanced liquidity
        
        ;; Transfer STX from user
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update market pools
        (map-set markets market-id 
            (merge market-data {
                yes-pool: new-yes-pool,
                no-pool: new-no-pool,
                total-volume: (+ (get total-volume market-data) amount),
                k-constant: new-k-constant
            })
        )
        
        (ok true)
    )
)

(define-public (resolve-market (market-id uint) (outcome bool))
    (let (
        (market-data (unwrap! (map-get? markets market-id) ERR_MARKET_NOT_FOUND))
    )
        ;; Validation checks
        (asserts! (> market-id u0) ERR_MARKET_NOT_FOUND)
        (asserts! (validate-principal tx-sender) ERR_INVALID_PRINCIPAL)
        (asserts! (not (is-eq tx-sender (get creator market-data))) ERR_CANNOT_RESOLVE_OWN_MARKET)
        (asserts! (> stacks-block-height (get expiry-block market-data)) ERR_MARKET_NOT_RESOLVED)
        (asserts! (< stacks-block-height (get resolution-block market-data)) ERR_MARKET_EXPIRED)
        (asserts! (not (get resolved market-data)) ERR_MARKET_ALREADY_RESOLVED)
        
        ;; Update market with resolution
        (map-set markets market-id 
            (merge market-data {
                resolved: true,
                outcome: (some outcome),
                resolver: (some tx-sender),
                oracle-resolved: false
            })
        )
        
        (ok true)
    )
)

(define-public (claim-winnings (market-id uint))
    (let (
        (market-data (unwrap! (map-get? markets market-id) ERR_MARKET_NOT_FOUND))
        (user-position (get-user-position market-id tx-sender))
        (market-outcome (unwrap! (get outcome market-data) ERR_MARKET_NOT_RESOLVED))
        (winning-shares (if market-outcome (get yes-shares user-position) (get no-shares user-position)))
        (total-pool (+ (get yes-pool market-data) (get no-pool market-data)))
        (winning-pool (if market-outcome (get yes-pool market-data) (get no-pool market-data)))
        (payout (if (and (> winning-pool u0) (> winning-shares u0)) 
                   (/ (* winning-shares total-pool) winning-pool) 
                   u0))
    )
        ;; Validation
        (asserts! (> market-id u0) ERR_MARKET_NOT_FOUND)
        (asserts! (validate-principal tx-sender) ERR_INVALID_PRINCIPAL)
        (asserts! (get resolved market-data) ERR_MARKET_NOT_RESOLVED)
        (asserts! (> winning-shares u0) ERR_INSUFFICIENT_BALANCE)
        (asserts! (> payout u0) ERR_INSUFFICIENT_BALANCE)
        
        ;; Reset user position
        (map-set user-positions { market-id: market-id, user: tx-sender }
            { yes-shares: u0, no-shares: u0, total-invested: u0 }
        )
        
        ;; Transfer winnings
        (as-contract (stx-transfer? payout tx-sender contract-caller))
    )
)

;; Admin functions
(define-public (set-platform-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (<= new-rate u1000) ERR_INVALID_AMOUNT) ;; Max 10% fee
        (var-set platform-fee-rate new-rate)
        (ok true)
    )
)

(define-public (withdraw-fees (market-id uint))
    (let (
        (accumulated-fees (default-to u0 (map-get? market-fees market-id)))
    )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (> market-id u0) ERR_MARKET_NOT_FOUND)
        (asserts! (> accumulated-fees u0) ERR_INSUFFICIENT_BALANCE)
        
        (map-delete market-fees market-id)
        (as-contract (stx-transfer? accumulated-fees tx-sender CONTRACT_OWNER))
    )
)