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
(define-constant ERR_INVALID_DURATION (err u122))
(define-constant ERR_CALCULATION_ERROR (err u123))

;; AMM Constants
(define-constant MINIMUM_LIQUIDITY u100000000) ;; 100 STX minimum liquidity per side
(define-constant PRECISION u1000000) ;; 6 decimal places for calculations
(define-constant MAX_SLIPPAGE u5000) ;; 50% maximum slippage protection
(define-constant ORACLE_DATA_VALIDITY_BLOCKS u144) ;; 24 hours validity for oracle data
(define-constant MAX_DURATION_BLOCKS u52560) ;; ~1 year maximum market duration
(define-constant MIN_DURATION_BLOCKS u144) ;; ~24 hours minimum market duration

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
    k-constant: uint,
    oracle-resolved: bool
})

(define-map user-positions { market-id: uint, user: principal } {
    yes-shares: uint,
    no-shares: uint,
    total-invested: uint
})

(define-map market-fees uint uint)

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

(define-read-only (get-market-fees (market-id uint))
    (default-to u0 (map-get? market-fees market-id))
)

;; Safe division helper to prevent division by zero
(define-private (safe-divide (numerator uint) (denominator uint))
    (if (is-eq denominator u0)
        (err ERR_DIVISION_BY_ZERO)
        (ok (/ numerator denominator))
    )
)

;; Safe multiplication with overflow check
(define-private (safe-multiply (a uint) (b uint))
    (let ((result (* a b)))
        (if (and (> a u0) (> b u0) (< result a))
            (err ERR_CALCULATION_ERROR)
            (ok result)
        )
    )
)

;; Simple AMM price calculation helper (internal)
(define-private (calculate-shares-internal (pool-in uint) (pool-out uint) (amount-in uint))
    (if (or (is-eq pool-in u0) (is-eq pool-out u0) (is-eq amount-in u0))
        u0
        (let (
            (k-result (unwrap! (safe-multiply pool-in pool-out) u0))
            (new-pool-in (+ pool-in amount-in))
        )
            (if (is-eq new-pool-in u0)
                u0
                (let ((new-pool-out (unwrap! (safe-divide k-result new-pool-in) u0)))
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
        (fee-calc (unwrap! (safe-multiply amount-in (var-get platform-fee-rate)) ERR_CALCULATION_ERROR))
        (fee-amount (unwrap! (safe-divide fee-calc u10000) ERR_DIVISION_BY_ZERO))
        (amount-in-after-fee (if (>= amount-in fee-amount) (- amount-in fee-amount) u0))
        (shares-out (calculate-shares-internal pool-in pool-out amount-in-after-fee))
    )
        (if (and (> amount-in u0) (> shares-out u0))
            (ok shares-out)
            ERR_INSUFFICIENT_LIQUIDITY
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
                (price-before-calc (unwrap! (safe-multiply pool-out PRECISION) ERR_CALCULATION_ERROR))
                (price-before (unwrap! (safe-divide price-before-calc total-pool) ERR_DIVISION_BY_ZERO))
                (shares-out (calculate-shares-internal pool-in pool-out amount-in))
                (new-pool-out (if (>= pool-out shares-out) (- pool-out shares-out) u0))
                (new-total (+ (+ pool-in amount-in) new-pool-out))
                (price-after-calc (if (> new-total u0) (unwrap! (safe-multiply new-pool-out PRECISION) ERR_CALCULATION_ERROR) u0))
                (price-after (if (> new-total u0) (unwrap! (safe-divide price-after-calc new-total) ERR_DIVISION_BY_ZERO) u0))
            )
                (if (is-eq price-before u0)
                    (ok u0)
                    (let (
                        (diff (if (>= price-before price-after) (- price-before price-after) u0))
                        (impact-calc (unwrap! (safe-multiply diff u10000) ERR_CALCULATION_ERROR))
                    )
                        (ok (unwrap! (safe-divide impact-calc price-before) ERR_DIVISION_BY_ZERO))
                    )
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
        (fee-calc (unwrap! (safe-multiply amount-in (var-get platform-fee-rate)) ERR_CALCULATION_ERROR))
        (fee-amount (unwrap! (safe-divide fee-calc u10000) ERR_DIVISION_BY_ZERO))
        (amount-in-after-fee (if (>= amount-in fee-amount) (- amount-in fee-amount) u0))
        (expected-output (calculate-shares-internal pool-in pool-out amount-in-after-fee))
        (slippage-factor (if (>= u10000 slippage-tolerance) (- u10000 slippage-tolerance) u0))
        (min-calc (unwrap! (safe-multiply expected-output slippage-factor) ERR_CALCULATION_ERROR))
        (minimum-output (unwrap! (safe-divide min-calc u10000) ERR_DIVISION_BY_ZERO))
    )
        (if (> expected-output u0)
            (ok minimum-output)
            ERR_INSUFFICIENT_LIQUIDITY
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
    (and (> amount u0) (<= amount u1000000000000))
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

(define-private (validate-duration (duration uint))
    (and (>= duration MIN_DURATION_BLOCKS) (<= duration MAX_DURATION_BLOCKS))
)

(define-private (validate-principal (principal-to-check principal))
    (not (is-eq principal-to-check 'ST000000000000000000002AMW42H))
)

;; Oracle Management Functions
(define-public (register-oracle (name (string-ascii 64)))
    (let (
        (oracle-id (+ (var-get oracle-counter) u1))
    )
        (asserts! (validate-oracle-name name) ERR_INVALID_STRING_LENGTH)
        (asserts! (validate-principal tx-sender) ERR_INVALID_PRINCIPAL)
        (asserts! (is-oracle-authorized tx-sender) ERR_ORACLE_NOT_AUTHORIZED)
        
        (map-set oracles oracle-id {
            name: name,
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
    )
        (asserts! (validate-data-key data-key) ERR_INVALID_STRING_LENGTH)
        (asserts! (validate-oracle-value value) ERR_INVALID_STRING_LENGTH)
        (asserts! (validate-principal tx-sender) ERR_INVALID_PRINCIPAL)
        (asserts! (is-eq tx-sender (get operator oracle-info)) ERR_ORACLE_NOT_AUTHORIZED)
        (asserts! (get active oracle-info) ERR_ORACLE_NOT_AUTHORIZED)
        
        (map-set oracle-data { oracle-id: oracle-id, data-key: data-key } {
            value: value,
            timestamp: stacks-block-height,
            block-height: stacks-block-height,
            verified: true
        })
        
        (ok true)
    )
)

(define-public (authorize-oracle (oracle-operator principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (validate-principal oracle-operator) ERR_INVALID_PRINCIPAL)
        (asserts! (not (is-oracle-authorized oracle-operator)) ERR_ORACLE_ALREADY_EXISTS)
        
        (map-set authorized-oracles oracle-operator true)
        (ok true)
    )
)

(define-public (revoke-oracle-authorization (oracle-operator principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (validate-principal oracle-operator) ERR_INVALID_PRINCIPAL)
        (asserts! (is-oracle-authorized oracle-operator) ERR_ORACLE_NOT_FOUND)
        
        (map-delete authorized-oracles oracle-operator)
        (ok true)
    )
)

;; Market Creation
(define-public (create-market (title (string-ascii 256)) (description (string-ascii 1024)) (duration-blocks uint) (initial-liquidity uint))
    (let (
        (market-id (+ (var-get market-counter) u1))
        (expiry-block (+ stacks-block-height duration-blocks))
        (resolution-block (+ expiry-block u144))
        (pool-amount (unwrap! (safe-divide initial-liquidity u2) ERR_INVALID_AMOUNT))
        (initial-k (unwrap! (safe-multiply pool-amount pool-amount) ERR_CALCULATION_ERROR))
    )
        (asserts! (validate-duration duration-blocks) ERR_INVALID_DURATION)
        (asserts! (validate-string-length title u1 u256) ERR_INVALID_STRING_LENGTH)
        (asserts! (validate-description-length description u1 u1024) ERR_INVALID_STRING_LENGTH)
        (asserts! (validate-amount initial-liquidity) ERR_INVALID_AMOUNT)
        (asserts! (>= initial-liquidity MINIMUM_LIQUIDITY) ERR_MINIMUM_LIQUIDITY)
        (asserts! (is-eq (mod initial-liquidity u2) u0) ERR_INVALID_AMOUNT)
        (asserts! (validate-principal tx-sender) ERR_INVALID_PRINCIPAL)
        
        (try! (stx-transfer? initial-liquidity tx-sender (as-contract tx-sender)))
        
        (map-set markets market-id {
            creator: tx-sender,
            title: title,
            description: description,
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
    )
        (asserts! (> market-id u0) ERR_MARKET_NOT_FOUND)
        (asserts! (validate-data-key data-key) ERR_INVALID_STRING_LENGTH)
        (asserts! (validate-resolution-criteria resolution-criteria) ERR_INVALID_STRING_LENGTH)
        (asserts! (get active oracle-info) ERR_ORACLE_NOT_AUTHORIZED)
        
        (map-set market-oracles market-id {
            oracle-id: oracle-id,
            data-key: data-key,
            resolution-criteria: resolution-criteria,
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
        (oracle-info (unwrap! (map-get? oracles (get oracle-id oracle-config)) ERR_ORACLE_NOT_FOUND))
        (oracle-data-entry (unwrap! (map-get? oracle-data { 
            oracle-id: (get oracle-id oracle-config), 
            data-key: (get data-key oracle-config) 
        }) ERR_INVALID_ORACLE_DATA))
        (data-age (if (>= stacks-block-height (get block-height oracle-data-entry)) 
                     (- stacks-block-height (get block-height oracle-data-entry)) 
                     u0))
    )
        (asserts! (> market-id u0) ERR_MARKET_NOT_FOUND)
        (asserts! (> stacks-block-height (get expiry-block market-data)) ERR_MARKET_NOT_RESOLVED)
        (asserts! (< stacks-block-height (get resolution-block market-data)) ERR_MARKET_EXPIRED)
        (asserts! (not (get resolved market-data)) ERR_MARKET_ALREADY_RESOLVED)
        (asserts! (get verified oracle-data-entry) ERR_INVALID_ORACLE_DATA)
        (asserts! (< data-age ORACLE_DATA_VALIDITY_BLOCKS) ERR_ORACLE_DATA_TOO_OLD)
        (asserts! (validate-principal (get operator oracle-info)) ERR_INVALID_PRINCIPAL)
        
        (let (
            (outcome (is-eq (get value oracle-data-entry) "true"))
        )
            (map-set markets market-id 
                (merge market-data {
                    resolved: true,
                    outcome: (some outcome),
                    resolver: (some (get operator oracle-info)),
                    oracle-resolved: true
                })
            )
            
            (map-set oracles (get oracle-id oracle-config)
                (merge oracle-info {
                    total-resolutions: (+ (get total-resolutions oracle-info) u1)
                })
            )
            
            (ok outcome)
        )
    )
)

;; Buy shares function
(define-public (buy-shares (market-id uint) (bet-yes bool) (amount uint) (minimum-shares uint))
    (let (
        (market-data (unwrap! (map-get? markets market-id) ERR_MARKET_NOT_FOUND))
        (current-position (get-user-position market-id tx-sender))
        (pool-in (if bet-yes (get yes-pool market-data) (get no-pool market-data)))
        (pool-out (if bet-yes (get no-pool market-data) (get yes-pool market-data)))
        (fee-calc (unwrap! (safe-multiply amount (var-get platform-fee-rate)) ERR_CALCULATION_ERROR))
        (fee-amount (unwrap! (safe-divide fee-calc u10000) ERR_DIVISION_BY_ZERO))
        (net-amount (if (>= amount fee-amount) (- amount fee-amount) u0))
        (shares-out (calculate-shares-internal pool-in pool-out net-amount))
        (new-yes-pool (if bet-yes 
                         (+ (get yes-pool market-data) net-amount) 
                         (if (>= (get yes-pool market-data) shares-out) 
                             (- (get yes-pool market-data) shares-out) 
                             u0)))
        (new-no-pool (if bet-yes 
                        (if (>= (get no-pool market-data) shares-out) 
                            (- (get no-pool market-data) shares-out) 
                            u0) 
                        (+ (get no-pool market-data) net-amount)))
        (new-k-constant (unwrap! (safe-multiply new-yes-pool new-no-pool) ERR_CALCULATION_ERROR))
    )
        (asserts! (> market-id u0) ERR_MARKET_NOT_FOUND)
        (asserts! (validate-amount amount) ERR_INVALID_AMOUNT)
        (asserts! (validate-principal tx-sender) ERR_INVALID_PRINCIPAL)
        (asserts! (is-market-active market-id) ERR_MARKET_CLOSED)
        (asserts! (> shares-out u0) ERR_INSUFFICIENT_LIQUIDITY)
        (asserts! (>= shares-out minimum-shares) ERR_SLIPPAGE_EXCEEDED)
        (asserts! (> new-yes-pool u0) ERR_INSUFFICIENT_LIQUIDITY)
        (asserts! (> new-no-pool u0) ERR_INSUFFICIENT_LIQUIDITY)
        (asserts! (>= amount fee-amount) ERR_INVALID_AMOUNT)
        
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (map-set markets market-id 
            (merge market-data {
                yes-pool: new-yes-pool,
                no-pool: new-no-pool,
                total-volume: (+ (get total-volume market-data) amount),
                k-constant: new-k-constant
            })
        )
        
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
        
        (map-set market-fees market-id 
            (+ (default-to u0 (map-get? market-fees market-id)) fee-amount)
        )
        
        (ok shares-out)
    )
)

(define-public (add-liquidity (market-id uint) (amount uint))
    (let (
        (market-data (unwrap! (map-get? markets market-id) ERR_MARKET_NOT_FOUND))
        (amount-per-pool (unwrap! (safe-divide amount u2) ERR_INVALID_AMOUNT))
        (new-yes-pool (+ (get yes-pool market-data) amount-per-pool))
        (new-no-pool (+ (get no-pool market-data) amount-per-pool))
        (new-k-constant (unwrap! (safe-multiply new-yes-pool new-no-pool) ERR_CALCULATION_ERROR))
    )
        (asserts! (> market-id u0) ERR_MARKET_NOT_FOUND)
        (asserts! (validate-amount amount) ERR_INVALID_AMOUNT)
        (asserts! (validate-principal tx-sender) ERR_INVALID_PRINCIPAL)
        (asserts! (is-market-active market-id) ERR_MARKET_CLOSED)
        (asserts! (is-eq (mod amount u2) u0) ERR_INVALID_AMOUNT)
        
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
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
        (asserts! (> market-id u0) ERR_MARKET_NOT_FOUND)
        (asserts! (validate-principal tx-sender) ERR_INVALID_PRINCIPAL)
        (asserts! (not (is-eq tx-sender (get creator market-data))) ERR_CANNOT_RESOLVE_OWN_MARKET)
        (asserts! (> stacks-block-height (get expiry-block market-data)) ERR_MARKET_NOT_RESOLVED)
        (asserts! (< stacks-block-height (get resolution-block market-data)) ERR_MARKET_EXPIRED)
        (asserts! (not (get resolved market-data)) ERR_MARKET_ALREADY_RESOLVED)
        
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
        (payout-calc (if (and (> winning-pool u0) (> winning-shares u0))
                         (unwrap! (safe-multiply winning-shares total-pool) ERR_CALCULATION_ERROR)
                         u0))
        (payout (if (> payout-calc u0)
                   (unwrap! (safe-divide payout-calc winning-pool) ERR_DIVISION_BY_ZERO)
                   u0))
    )
        (asserts! (> market-id u0) ERR_MARKET_NOT_FOUND)
        (asserts! (validate-principal tx-sender) ERR_INVALID_PRINCIPAL)
        (asserts! (get resolved market-data) ERR_MARKET_NOT_RESOLVED)
        (asserts! (> winning-shares u0) ERR_INSUFFICIENT_BALANCE)
        (asserts! (> payout u0) ERR_INSUFFICIENT_BALANCE)
        
        (map-set user-positions { market-id: market-id, user: tx-sender }
            { yes-shares: u0, no-shares: u0, total-invested: u0 }
        )
        
        (as-contract (stx-transfer? payout tx-sender contract-caller))
    )
)

;; Admin functions
(define-public (set-platform-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (<= new-rate u1000) ERR_INVALID_AMOUNT)
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