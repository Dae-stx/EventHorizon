;; EventHorizon - Decentralized Prediction Market Platform with Advanced AMM
;; A platform for creating and trading outcome shares using automated market maker algorithms

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

;; AMM Constants
(define-constant MINIMUM_LIQUIDITY u100000000) ;; 100 STX minimum liquidity per side
(define-constant PRECISION u1000000) ;; 6 decimal places for calculations
(define-constant MAX_SLIPPAGE u5000) ;; 50% maximum slippage protection

;; Data Variables
(define-data-var market-counter uint u0)
(define-data-var platform-fee-rate uint u250) ;; 2.5% fee (250 basis points)

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
    k-constant: uint ;; AMM constant product k = x * y
})

(define-map user-positions { market-id: uint, user: principal } {
    yes-shares: uint,
    no-shares: uint,
    total-invested: uint
})

(define-map market-fees uint uint) ;; market-id -> accumulated fees

;; Read-only functions
(define-read-only (get-market (market-id uint))
    (map-get? markets market-id)
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

(define-read-only (get-platform-fee-rate)
    (var-get platform-fee-rate)
)

;; Simple AMM price calculation helper (internal)
(define-private (calculate-shares-internal (pool-in uint) (pool-out uint) (amount-in uint))
    (if (or (is-eq pool-in u0) (is-eq pool-out u0))
        u0
        (let (
            (k-constant (* pool-in pool-out))
            (new-pool-in (+ pool-in amount-in))
            (new-pool-out (/ k-constant new-pool-in))
        )
            (if (> new-pool-out pool-out)
                u0
                (- pool-out new-pool-out)
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
        (amount-in-after-fee (- amount-in fee-amount))
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
                (new-pool-out (- pool-out shares-out))
                (new-total (+ (+ pool-in amount-in) new-pool-out))
                (price-after (if (is-eq new-total u0) u0 (/ (* new-pool-out PRECISION) new-total)))
            )
                (if (is-eq price-before u0)
                    (ok u0)
                    (ok (/ (* (- price-before price-after) u10000) price-before))
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
        (amount-in-after-fee (- amount-in fee-amount))
        (expected-output (calculate-shares-internal pool-in pool-out amount-in-after-fee))
        (slippage-factor (- u10000 slippage-tolerance))
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

;; Public functions
(define-public (create-market (title (string-ascii 256)) (description (string-ascii 1024)) (duration-blocks uint) (initial-liquidity uint))
    (let (
        (market-id (+ (var-get market-counter) u1))
        (expiry-block (+ stacks-block-height duration-blocks))
        (resolution-block (+ expiry-block u144)) ;; 24 hours after expiry for resolution
        (validated-title (unwrap! (as-max-len? title u256) ERR_INVALID_AMOUNT))
        (validated-description (unwrap! (as-max-len? description u1024) ERR_INVALID_AMOUNT))
        (pool-amount (/ initial-liquidity u2))
        (initial-k (* pool-amount pool-amount))
    )
        ;; Comprehensive input validation
        (asserts! (> duration-blocks u0) ERR_INVALID_AMOUNT)
        (asserts! (validate-string-length validated-title u1 u256) ERR_INVALID_AMOUNT)
        (asserts! (validate-description-length validated-description u1 u1024) ERR_INVALID_AMOUNT)
        (asserts! (validate-amount initial-liquidity) ERR_INVALID_AMOUNT)
        (asserts! (>= initial-liquidity MINIMUM_LIQUIDITY) ERR_MINIMUM_LIQUIDITY)
        (asserts! (is-eq (mod initial-liquidity u2) u0) ERR_INVALID_AMOUNT) ;; Must be even for balanced pools
        
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
            k-constant: initial-k
        })
        
        (var-set market-counter market-id)
        (ok market-id)
    )
)

(define-public (buy-shares (market-id uint) (bet-yes bool) (amount uint) (minimum-shares uint))
    (let (
        (market-data (unwrap! (map-get? markets market-id) ERR_MARKET_NOT_FOUND))
        (current-position (get-user-position market-id tx-sender))
        (pool-in (if bet-yes (get yes-pool market-data) (get no-pool market-data)))
        (pool-out (if bet-yes (get no-pool market-data) (get yes-pool market-data)))
        (fee-amount (/ (* amount (var-get platform-fee-rate)) u10000))
        (net-amount (- amount fee-amount))
        (shares-out (calculate-shares-internal pool-in pool-out net-amount))
        (new-yes-pool (if bet-yes (+ (get yes-pool market-data) net-amount) (- (get yes-pool market-data) shares-out)))
        (new-no-pool (if bet-yes (- (get no-pool market-data) shares-out) (+ (get no-pool market-data) net-amount)))
        (new-k-constant (* new-yes-pool new-no-pool))
    )
        ;; Comprehensive validation
        (asserts! (validate-amount amount) ERR_INVALID_AMOUNT)
        (asserts! (is-market-active market-id) ERR_MARKET_CLOSED)
        (asserts! (> shares-out u0) ERR_INSUFFICIENT_LIQUIDITY)
        (asserts! (>= shares-out minimum-shares) ERR_SLIPPAGE_EXCEEDED)
        (asserts! (> new-yes-pool u0) ERR_INSUFFICIENT_LIQUIDITY)
        (asserts! (> new-no-pool u0) ERR_INSUFFICIENT_LIQUIDITY)
        
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
        (asserts! (validate-amount amount) ERR_INVALID_AMOUNT)
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
        (asserts! (not (is-eq tx-sender (get creator market-data))) ERR_CANNOT_RESOLVE_OWN_MARKET)
        (asserts! (> stacks-block-height (get expiry-block market-data)) ERR_MARKET_NOT_RESOLVED)
        (asserts! (< stacks-block-height (get resolution-block market-data)) ERR_MARKET_EXPIRED)
        (asserts! (not (get resolved market-data)) ERR_MARKET_ALREADY_RESOLVED)
        
        ;; Update market with resolution
        (map-set markets market-id 
            (merge market-data {
                resolved: true,
                outcome: (some outcome),
                resolver: (some tx-sender)
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
        (asserts! (> accumulated-fees u0) ERR_INSUFFICIENT_BALANCE)
        
        (map-delete market-fees market-id)
        (as-contract (stx-transfer? accumulated-fees tx-sender CONTRACT_OWNER))
    )
)