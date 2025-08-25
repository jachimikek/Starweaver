;; Starweaver - Decentralized Prediction Markets & Oracle Network
;; A sophisticated system for creating prediction markets and aggregating real-world data

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_MARKET_NOT_FOUND (err u401))
(define-constant ERR_MARKET_CLOSED (err u402))
(define-constant ERR_INVALID_OUTCOME (err u403))
(define-constant ERR_INSUFFICIENT_FUNDS (err u404))
(define-constant ERR_ORACLE_NOT_FOUND (err u405))
(define-constant ERR_ALREADY_RESOLVED (err u406))
(define-constant ERR_MARKET_EXPIRED (err u407))
(define-constant ERR_INVALID_TIMEFRAME (err u408))
(define-constant ERR_INSUFFICIENT_STAKE (err u409))
(define-constant ERR_ORACLE_DISPUTED (err u410))
(define-constant ERR_POSITION_NOT_FOUND (err u411))
(define-constant ERR_EARLY_RESOLUTION (err u412))

;; Market states
(define-constant MARKET_ACTIVE u0)
(define-constant MARKET_LOCKED u1)
(define-constant MARKET_RESOLVED u2)
(define-constant MARKET_DISPUTED u3)
(define-constant MARKET_CANCELLED u4)

;; Oracle states
(define-constant ORACLE_PENDING u0)
(define-constant ORACLE_SUBMITTED u1)
(define-constant ORACLE_CONFIRMED u2)
(define-constant ORACLE_DISPUTED u3)
(define-constant ORACLE_SLASHED u4)

;; Position types
(define-constant POSITION_YES u0)
(define-constant POSITION_NO u1)

;; Data Variables
(define-data-var next-market-id uint u1)
(define-data-var next-oracle-id uint u1)
(define-data-var platform-fee uint u200) ;; 2% in basis points
(define-data-var min-oracle-stake uint u10000000) ;; 10 STX
(define-data-var oracle-reward-pool uint u0)
(define-data-var dispute-bond uint u5000000) ;; 5 STX
(define-data-var resolution-period uint u2016) ;; ~2 weeks in blocks
(define-data-var total-volume uint u0)
(define-data-var active-markets uint u0)

;; Data Maps
(define-map prediction-markets
    { market-id: uint }
    {
        creator: principal,
        title: (string-utf8 256),
        description: (string-utf8 1024),
        category: (string-ascii 64),
        created-at: uint,
        resolve-time: uint,
        expiry-time: uint,
        state: uint,
        total-yes-shares: uint,
        total-no-shares: uint,
        total-volume: uint,
        resolution-source: (string-utf8 256),
        outcome: (optional bool),
        oracle-id: (optional uint),
        dispute-deadline: (optional uint)
    }
)

(define-map market-positions
    { market-id: uint, trader: principal }
    {
        yes-shares: uint,
        no-shares: uint,
        avg-yes-price: uint,
        avg-no-price: uint,
        total-invested: uint,
        last-trade-time: uint
    }
)

(define-map oracles
    { oracle-id: uint }
    {
        operator: principal,
        reputation-score: uint,
        total-stake: uint,
        active-requests: uint,
        successful-resolutions: uint,
        disputed-resolutions: uint,
        slash-count: uint,
        registered-at: uint,
        specialization: (string-ascii 64),
        fee-per-resolution: uint
    }
)

(define-map oracle-submissions
    { oracle-id: uint, market-id: uint }
    {
        submitted-outcome: bool,
        confidence-score: uint,
        evidence-hash: (string-ascii 64),
        submitted-at: uint,
        state: uint,
        challenger: (optional principal),
        challenge-deadline: (optional uint)
    }
)

(define-map market-liquidity
    { market-id: uint }
    {
        liquidity-provider: principal,
        yes-liquidity: uint,
        no-liquidity: uint,
        fees-earned: uint,
        provided-at: uint
    }
)

(define-map oracle-stakes
    { oracle-id: uint }
    {
        staked-amount: uint,
        locked-amount: uint,
        pending-rewards: uint,
        last-reward-claim: uint
    }
)

(define-map dispute-records
    { market-id: uint, disputer: principal }
    {
        dispute-reason: (string-utf8 512),
        bond-amount: uint,
        disputed-at: uint,
        evidence-provided: (string-ascii 64),
        resolved: bool
    }
)

(define-map market-analytics
    { market-id: uint }
    {
        unique-traders: uint,
        price-history: (list 100 uint),
        volume-24h: uint,
        last-trade-price: uint,
        volatility-score: uint
    }
)

(define-map trader-stats
    { trader: principal }
    {
        total-markets-traded: uint,
        total-volume: uint,
        profitable-trades: uint,
        total-trades: uint,
        reputation-score: uint,
        average-roi: int,
        last-activity: uint
    }
)

;; Read-only functions
(define-read-only (get-market (market-id uint))
    (map-get? prediction-markets { market-id: market-id })
)

(define-read-only (get-position (market-id uint) (trader principal))
    (map-get? market-positions { market-id: market-id, trader: trader })
)

(define-read-only (get-oracle (oracle-id uint))
    (map-get? oracles { oracle-id: oracle-id })
)

(define-read-only (get-oracle-submission (oracle-id uint) (market-id uint))
    (map-get? oracle-submissions { oracle-id: oracle-id, market-id: market-id })
)

(define-read-only (get-market-price (market-id uint))
    (match (map-get? prediction-markets { market-id: market-id })
        market-data
        (let (
            (yes-shares (get total-yes-shares market-data))
            (no-shares (get total-no-shares market-data))
            (total-shares (+ yes-shares no-shares))
        )
            (if (> total-shares u0)
                (ok (/ (* yes-shares u10000) total-shares))
                (ok u5000) ;; 50% if no trades yet
            )
        )
        ERR_MARKET_NOT_FOUND
    )
)

(define-read-only (calculate-trade-price (market-id uint) (position-type uint) (share-amount uint))
    (match (map-get? prediction-markets { market-id: market-id })
        market-data
        (let (
            (yes-shares (get total-yes-shares market-data))
            (no-shares (get total-no-shares market-data))
            (k-constant (* yes-shares no-shares)) ;; Automated Market Maker constant
        )
            (if (is-eq position-type POSITION_YES)
                (let (
                    (new-yes-shares (+ yes-shares share-amount))
                    (new-no-shares (/ k-constant new-yes-shares))
                    (price-impact (- no-shares new-no-shares))
                )
                    (ok price-impact)
                )
                (let (
                    (new-no-shares (+ no-shares share-amount))
                    (new-yes-shares (/ k-constant new-no-shares))
                    (price-impact (- yes-shares new-yes-shares))
                )
                    (ok price-impact)
                )
            )
        )
        ERR_MARKET_NOT_FOUND
    )
)

(define-read-only (get-platform-stats)
    {
        total-markets: (- (var-get next-market-id) u1),
        active-markets: (var-get active-markets),
        total-volume: (var-get total-volume),
        total-oracles: (- (var-get next-oracle-id) u1),
        platform-fee: (var-get platform-fee),
        oracle-reward-pool: (var-get oracle-reward-pool)
    }
)

(define-read-only (get-trader-stats (trader principal))
    (map-get? trader-stats { trader: trader })
)

(define-read-only (estimate-payout (market-id uint) (trader principal))
    (match (map-get? market-positions { market-id: market-id, trader: trader })
        position
        (match (map-get? prediction-markets { market-id: market-id })
            market-data
            (match (get outcome market-data)
                outcome-result
                (let (
                    (winning-shares (if outcome-result 
                                      (get yes-shares position)
                                      (get no-shares position)))
                    (total-invested (get total-invested position))
                )
                    (ok (if (> winning-shares u0) winning-shares u0))
                )
                (ok u0) ;; Market not resolved yet
            )
            ERR_MARKET_NOT_FOUND
        )
        ERR_POSITION_NOT_FOUND
    )
)

;; Private functions
(define-private (update-trader-stats (trader principal) (volume uint) (profitable bool))
    (match (map-get? trader-stats { trader: trader })
        stats
        (map-set trader-stats
            { trader: trader }
            (merge stats {
                total-volume: (+ (get total-volume stats) volume),
                total-trades: (+ (get total-trades stats) u1),
                profitable-trades: (if profitable 
                                     (+ (get profitable-trades stats) u1)
                                     (get profitable-trades stats)),
                last-activity: stacks-block-height
            })
        )
        ;; Create new trader stats
        (map-set trader-stats
            { trader: trader }
            {
                total-markets-traded: u1,
                total-volume: volume,
                profitable-trades: (if profitable u1 u0),
                total-trades: u1,
                reputation-score: u100,
                average-roi: 0,
                last-activity: stacks-block-height
            }
        )
    )
)

(define-private (calculate-platform-fee (amount uint))
    (/ (* amount (var-get platform-fee)) u10000)
)

(define-private (update-market-analytics (market-id uint) (trade-price uint) (volume uint))
    (match (map-get? market-analytics { market-id: market-id })
        analytics
        (map-set market-analytics
            { market-id: market-id }
            (merge analytics {
                volume-24h: (+ (get volume-24h analytics) volume),
                last-trade-price: trade-price
            })
        )
        ;; Create new analytics
        (map-set market-analytics
            { market-id: market-id }
            {
                unique-traders: u1,
                price-history: (list trade-price),
                volume-24h: volume,
                last-trade-price: trade-price,
                volatility-score: u0
            }
        )
    )
)

;; Public functions

;; Market Creation
(define-public (create-market 
    (title (string-utf8 256))
    (description (string-utf8 1024))
    (category (string-ascii 64))
    (resolve-time uint)
    (resolution-source (string-utf8 256))
)
    (let (
        (market-id (var-get next-market-id))
        (expiry-time (+ resolve-time (var-get resolution-period)))
    )
        (asserts! (> resolve-time stacks-block-height) ERR_INVALID_TIMEFRAME)
        
        (map-set prediction-markets
            { market-id: market-id }
            {
                creator: tx-sender,
                title: title,
                description: description,
                category: category,
                created-at: stacks-block-height,
                resolve-time: resolve-time,
                expiry-time: expiry-time,
                state: MARKET_ACTIVE,
                total-yes-shares: u1000, ;; Initial liquidity
                total-no-shares: u1000,
                total-volume: u0,
                resolution-source: resolution-source,
                outcome: none,
                oracle-id: none,
                dispute-deadline: none
            }
        )
        
        (var-set next-market-id (+ market-id u1))
        (var-set active-markets (+ (var-get active-markets) u1))
        (ok market-id)
    )
)

;; Trading Functions
(define-public (buy-shares (market-id uint) (position-type uint) (max-cost uint))
    (let (
        (market-data (unwrap! (map-get? prediction-markets { market-id: market-id }) ERR_MARKET_NOT_FOUND))
        (share-cost (unwrap! (calculate-trade-price market-id position-type u100) ERR_MARKET_NOT_FOUND))
        (platform-fee-amount (calculate-platform-fee share-cost))
        (net-cost (+ share-cost platform-fee-amount))
    )
        (asserts! (is-eq (get state market-data) MARKET_ACTIVE) ERR_MARKET_CLOSED)
        (asserts! (< stacks-block-height (get resolve-time market-data)) ERR_MARKET_EXPIRED)
        (asserts! (<= position-type POSITION_NO) ERR_INVALID_OUTCOME)
        (asserts! (>= max-cost net-cost) ERR_INSUFFICIENT_FUNDS)
        
        ;; Transfer payment
        (try! (stx-transfer? net-cost tx-sender (as-contract tx-sender)))
        (try! (stx-transfer? platform-fee-amount (as-contract tx-sender) CONTRACT_OWNER))
        
        ;; Update market state
        (let (
            (updated-market
                (if (is-eq position-type POSITION_YES)
                    (merge market-data {
                        total-yes-shares: (+ (get total-yes-shares market-data) u100),
                        total-volume: (+ (get total-volume market-data) share-cost)
                    })
                    (merge market-data {
                        total-no-shares: (+ (get total-no-shares market-data) u100),
                        total-volume: (+ (get total-volume market-data) share-cost)
                    })
                )
            )
        )
            (map-set prediction-markets { market-id: market-id } updated-market)
        )
        
        ;; Update trader position
        (match (map-get? market-positions { market-id: market-id, trader: tx-sender })
            existing-position
            (let (
                (updated-position
                    (if (is-eq position-type POSITION_YES)
                        (merge existing-position {
                            yes-shares: (+ (get yes-shares existing-position) u100),
                            total-invested: (+ (get total-invested existing-position) net-cost),
                            last-trade-time: stacks-block-height
                        })
                        (merge existing-position {
                            no-shares: (+ (get no-shares existing-position) u100),
                            total-invested: (+ (get total-invested existing-position) net-cost),
                            last-trade-time: stacks-block-height
                        })
                    )
                )
            )
                (map-set market-positions { market-id: market-id, trader: tx-sender } updated-position)
            )
            ;; Create new position
            (map-set market-positions
                { market-id: market-id, trader: tx-sender }
                {
                    yes-shares: (if (is-eq position-type POSITION_YES) u100 u0),
                    no-shares: (if (is-eq position-type POSITION_NO) u100 u0),
                    avg-yes-price: (if (is-eq position-type POSITION_YES) share-cost u0),
                    avg-no-price: (if (is-eq position-type POSITION_NO) share-cost u0),
                    total-invested: net-cost,
                    last-trade-time: stacks-block-height
                }
            )
        )
        
        ;; Update statistics
        (update-trader-stats tx-sender net-cost false) ;; Profitability determined later
        (update-market-analytics market-id share-cost net-cost)
        (var-set total-volume (+ (var-get total-volume) share-cost))
        
        (ok u100) ;; Return shares purchased
    )
)

;; Oracle System
(define-public (register-oracle 
    (specialization (string-ascii 64))
    (fee-per-resolution uint)
)
    (let (
        (oracle-id (var-get next-oracle-id))
        (stake-amount (var-get min-oracle-stake))
    )
        ;; Transfer stake
        (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
        
        (map-set oracles
            { oracle-id: oracle-id }
            {
                operator: tx-sender,
                reputation-score: u100,
                total-stake: stake-amount,
                active-requests: u0,
                successful-resolutions: u0,
                disputed-resolutions: u0,
                slash-count: u0,
                registered-at: stacks-block-height,
                specialization: specialization,
                fee-per-resolution: fee-per-resolution
            }
        )
        
        (map-set oracle-stakes
            { oracle-id: oracle-id }
            {
                staked-amount: stake-amount,
                locked-amount: u0,
                pending-rewards: u0,
                last-reward-claim: stacks-block-height
            }
        )
        
        (var-set next-oracle-id (+ oracle-id u1))
        (ok oracle-id)
    )
)

(define-public (submit-oracle-result 
    (oracle-id uint)
    (market-id uint)
    (outcome bool)
    (confidence-score uint)
    (evidence-hash (string-ascii 64))
)
    (let (
        (oracle-data (unwrap! (map-get? oracles { oracle-id: oracle-id }) ERR_ORACLE_NOT_FOUND))
        (market-data (unwrap! (map-get? prediction-markets { market-id: market-id }) ERR_MARKET_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get operator oracle-data)) ERR_UNAUTHORIZED)
        (asserts! (>= stacks-block-height (get resolve-time market-data)) ERR_EARLY_RESOLUTION)
        (asserts! (is-eq (get state market-data) MARKET_ACTIVE) ERR_MARKET_CLOSED)
        (asserts! (<= confidence-score u100) ERR_INVALID_OUTCOME)
        
        (map-set oracle-submissions
            { oracle-id: oracle-id, market-id: market-id }
            {
                submitted-outcome: outcome,
                confidence-score: confidence-score,
                evidence-hash: evidence-hash,
                submitted-at: stacks-block-height,
                state: ORACLE_SUBMITTED,
                challenger: none,
                challenge-deadline: (some (+ stacks-block-height u1008)) ;; 1 week challenge period
            }
        )
        
        ;; Lock market for resolution
        (map-set prediction-markets
            { market-id: market-id }
            (merge market-data { 
                state: MARKET_LOCKED,
                oracle-id: (some oracle-id)
            })
        )
        
        (ok true)
    )
)

(define-public (resolve-market (market-id uint))
    (let (
        (market-data (unwrap! (map-get? prediction-markets { market-id: market-id }) ERR_MARKET_NOT_FOUND))
        (oracle-id (unwrap! (get oracle-id market-data) ERR_ORACLE_NOT_FOUND))
        (submission (unwrap! (map-get? oracle-submissions { oracle-id: oracle-id, market-id: market-id }) ERR_ORACLE_NOT_FOUND))
    )
        (asserts! (is-eq (get state market-data) MARKET_LOCKED) ERR_MARKET_CLOSED)
        (asserts! (match (get challenge-deadline submission)
                    deadline (>= stacks-block-height deadline)
                    true
                  ) ERR_EARLY_RESOLUTION)
        
        ;; Resolve market
        (map-set prediction-markets
            { market-id: market-id }
            (merge market-data {
                state: MARKET_RESOLVED,
                outcome: (some (get submitted-outcome submission))
            })
        )
        
        ;; Update oracle reputation
        (match (map-get? oracles { oracle-id: oracle-id })
            oracle-data
            (map-set oracles
                { oracle-id: oracle-id }
                (merge oracle-data {
                    successful-resolutions: (+ (get successful-resolutions oracle-data) u1),
                    reputation-score: (+ (get reputation-score oracle-data) u10)
                })
            )
            false
        )
        
        (var-set active-markets (- (var-get active-markets) u1))
        (ok true)
    )
)

(define-public (claim-winnings (market-id uint))
    (let (
        (market-data (unwrap! (map-get? prediction-markets { market-id: market-id }) ERR_MARKET_NOT_FOUND))
        (position (unwrap! (map-get? market-positions { market-id: market-id, trader: tx-sender }) ERR_POSITION_NOT_FOUND))
        (outcome (unwrap! (get outcome market-data) ERR_MARKET_NOT_FOUND))
    )
        (asserts! (is-eq (get state market-data) MARKET_RESOLVED) ERR_MARKET_NOT_FOUND)
        
        (let (
            (winning-shares (if outcome 
                              (get yes-shares position)
                              (get no-shares position)))
            (total-invested (get total-invested position))
        )
            (asserts! (> winning-shares u0) ERR_INSUFFICIENT_FUNDS)
            
            ;; Transfer winnings
            (try! (as-contract (stx-transfer? winning-shares tx-sender tx-sender)))
            
            ;; Clear position
            (map-delete market-positions { market-id: market-id, trader: tx-sender })
            
            ;; Update trader stats
            (update-trader-stats tx-sender winning-shares (> winning-shares total-invested))
            
            (ok winning-shares)
        )
    )
)

;; Dispute System
(define-public (dispute-oracle-result (market-id uint) (dispute-reason (string-utf8 512)) (evidence (string-ascii 64)))
    (let (
        (market-data (unwrap! (map-get? prediction-markets { market-id: market-id }) ERR_MARKET_NOT_FOUND))
        (bond-amount (var-get dispute-bond))
    )
        (asserts! (is-eq (get state market-data) MARKET_LOCKED) ERR_MARKET_CLOSED)
        
        ;; Transfer dispute bond
        (try! (stx-transfer? bond-amount tx-sender (as-contract tx-sender)))
        
        (map-set dispute-records
            { market-id: market-id, disputer: tx-sender }
            {
                dispute-reason: dispute-reason,
                bond-amount: bond-amount,
                disputed-at: stacks-block-height,
                evidence-provided: evidence,
                resolved: false
            }
        )
        
        ;; Update market state
        (map-set prediction-markets
            { market-id: market-id }
            (merge market-data { 
                state: MARKET_DISPUTED,
                dispute-deadline: (some (+ stacks-block-height u2016)) ;; 2 week dispute period
            })
        )
        
        (ok true)
    )
)

;; Admin functions
(define-public (update-platform-parameters 
    (new-platform-fee uint)
    (new-min-oracle-stake uint)
    (new-dispute-bond uint)
    (new-resolution-period uint)
)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= new-platform-fee u1000) ERR_INVALID_OUTCOME) ;; Max 10%
        
        (var-set platform-fee new-platform-fee)
        (var-set min-oracle-stake new-min-oracle-stake)
        (var-set dispute-bond new-dispute-bond)
        (var-set resolution-period new-resolution-period)
        (ok true)
    )
)