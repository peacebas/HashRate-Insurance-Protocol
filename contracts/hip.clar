;; HashRate Insurance Protocol (HIP)
;; Parametric insurance for Bitcoin miners against difficulty adjustments and energy price spikes

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-POLICY-EXPIRED (err u104))
(define-constant ERR-CLAIM-ALREADY-PROCESSED (err u105))
(define-constant ERR-THRESHOLD-NOT-MET (err u106))
(define-constant ERR-ORACLE-NOT-AUTHORIZED (err u107))
(define-constant ERR-INVALID-PARAMETERS (err u108))

;; Data Variables
(define-data-var oracle-address principal CONTRACT-OWNER)
(define-data-var protocol-fee-rate uint u250) ;; 2.5% in basis points
(define-data-var total-policies-created uint u0)
(define-data-var protocol-treasury uint u0)

;; Valid data types for oracle submissions - Fixed string length
(define-constant VALID-DATA-TYPES (list "difficulty" "energy-price"))

;; Validation helper - Fixed parameter type to match list elements
(define-private (is-data-type-valid (data-type (string-ascii 12)))
  (is-some (index-of VALID-DATA-TYPES data-type))
)

;; Valid principals check
(define-private (is-valid-principal (addr principal))
  (not (is-eq addr 'SP000000000000000000002Q6VF78))
)

;; Policy Structure
(define-map policies
  { policy-id: uint }
  {
    miner: principal,
    premium-paid: uint,
    coverage-amount: uint,
    difficulty-threshold: uint,
    energy-price-threshold: uint,
    start-block: uint,
    end-block: uint,
    claimed: bool,
    active: bool
  }
)

;; Oracle Data - Updated to use consistent string length
(define-map oracle-data
  { data-type: (string-ascii 12), submission-block: uint }
  {
    value: uint,
    timestamp: uint,
    oracle: principal
  }
)

;; Authorized Oracles
(define-map authorized-oracles
  { oracle: principal }
  { authorized: bool }
)

;; Miner Profiles
(define-map miner-profiles
  { miner: principal }
  {
    total-policies: uint,
    total-claims: uint,
    total-premiums-paid: uint
  }
)

;; Events - Updated to use consistent string length
(define-map policy-events
  { policy-id: uint, event-type: (string-ascii 20) }
  {
    event-block: uint,
    timestamp: uint,
    data: uint
  }
)

;; Read-only functions

(define-read-only (get-policy (policy-id uint))
  (map-get? policies { policy-id: policy-id })
)

(define-read-only (get-oracle-data (data-type (string-ascii 12)) (submission-block uint))
  (map-get? oracle-data { data-type: data-type, submission-block: submission-block })
)

(define-read-only (get-miner-profile (miner principal))
  (default-to 
    { total-policies: u0, total-claims: u0, total-premiums-paid: u0 }
    (map-get? miner-profiles { miner: miner })
  )
)

(define-read-only (is-oracle-authorized (oracle principal))
  (default-to false (get authorized (map-get? authorized-oracles { oracle: oracle })))
)

(define-read-only (calculate-premium (coverage-amount uint) (risk-multiplier uint))
  (let ((base-premium (/ (* coverage-amount u500) u10000))) ;; 5% base rate
    (/ (* base-premium risk-multiplier) u100)
  )
)

(define-read-only (get-protocol-stats)
  {
    total-policies: (var-get total-policies-created),
    protocol-treasury: (var-get protocol-treasury),
    oracle-address: (var-get oracle-address),
    protocol-fee-rate: (var-get protocol-fee-rate)
  }
)

;; Administrative functions

(define-public (set-oracle-address (new-oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (is-valid-principal new-oracle) ERR-INVALID-PARAMETERS)
    (var-set oracle-address new-oracle)
    (ok true)
  )
)

(define-public (authorize-oracle (oracle-addr principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (is-valid-principal oracle-addr) ERR-INVALID-PARAMETERS)
    (map-set authorized-oracles { oracle: oracle-addr } { authorized: true })
    (ok true)
  )
)

(define-public (revoke-oracle (oracle-addr principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (is-valid-principal oracle-addr) ERR-INVALID-PARAMETERS)
    (map-set authorized-oracles { oracle: oracle-addr } { authorized: false })
    (ok true)
  )
)

(define-public (update-protocol-fee (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (<= new-rate u1000) ERR-INVALID-PARAMETERS) ;; Max 10%
    (var-set protocol-fee-rate new-rate)
    (ok true)
  )
)

;; Oracle functions - Updated parameter type

(define-public (submit-oracle-data (data-type (string-ascii 12)) (value uint))
  (let ((current-block block-height))
    (asserts! (is-oracle-authorized tx-sender) ERR-ORACLE-NOT-AUTHORIZED)
    (asserts! (is-data-type-valid data-type) ERR-INVALID-PARAMETERS)
    (map-set oracle-data 
      { data-type: data-type, submission-block: current-block }
      { value: value, timestamp: (unwrap-panic (get-block-info? time current-block)), oracle: tx-sender }
    )
    (ok true)
  )
)

;; Core insurance functions

(define-public (create-policy 
  (coverage-amount uint)
  (difficulty-threshold uint)
  (energy-price-threshold uint)
  (duration-blocks uint)
  (risk-multiplier uint)
)
  (let (
    (policy-id (+ (var-get total-policies-created) u1))
    (premium (calculate-premium coverage-amount risk-multiplier))
    (protocol-fee (/ (* premium (var-get protocol-fee-rate)) u10000))
    (total-cost (+ premium protocol-fee))
    (current-block block-height)
    (end-block (+ current-block duration-blocks))
    (current-profile (get-miner-profile tx-sender))
  )
    (asserts! (> coverage-amount u0) ERR-INVALID-PARAMETERS)
    (asserts! (> difficulty-threshold u0) ERR-INVALID-PARAMETERS)
    (asserts! (> energy-price-threshold u0) ERR-INVALID-PARAMETERS)
    (asserts! (> duration-blocks u0) ERR-INVALID-PARAMETERS)
    (asserts! (>= (stx-get-balance tx-sender) total-cost) ERR-INSUFFICIENT-BALANCE)
    
    ;; Transfer premium and fee
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    
    ;; Create policy
    (map-set policies 
      { policy-id: policy-id }
      {
        miner: tx-sender,
        premium-paid: premium,
        coverage-amount: coverage-amount,
        difficulty-threshold: difficulty-threshold,
        energy-price-threshold: energy-price-threshold,
        start-block: current-block,
        end-block: end-block,
        claimed: false,
        active: true
      }
    )
    
    ;; Update miner profile
    (map-set miner-profiles 
      { miner: tx-sender }
      {
        total-policies: (+ (get total-policies current-profile) u1),
        total-claims: (get total-claims current-profile),
        total-premiums-paid: (+ (get total-premiums-paid current-profile) premium)
      }
    )
    
    ;; Update protocol state
    (var-set total-policies-created policy-id)
    (var-set protocol-treasury (+ (var-get protocol-treasury) protocol-fee))
    
    (ok policy-id)
  )
)

(define-public (process-claim (policy-id uint))
  (let (
    (policy (unwrap! (get-policy policy-id) ERR-NOT-FOUND))
    (current-block block-height)
    (difficulty-data (get-oracle-data "difficulty" current-block))
    (energy-data (get-oracle-data "energy-price" current-block))
    (current-profile (get-miner-profile (get miner policy)))
  )
    (asserts! (is-eq tx-sender (get miner policy)) ERR-OWNER-ONLY)
    (asserts! (get active policy) ERR-NOT-FOUND)
    (asserts! (not (get claimed policy)) ERR-CLAIM-ALREADY-PROCESSED)
    (asserts! (<= current-block (get end-block policy)) ERR-POLICY-EXPIRED)
    
    ;; Check if thresholds are met
    (let (
      (difficulty-triggered 
        (match difficulty-data
          oracle-entry (>= (get value oracle-entry) (get difficulty-threshold policy))
          false
        )
      )
      (energy-triggered 
        (match energy-data
          oracle-entry (>= (get value oracle-entry) (get energy-price-threshold policy))
          false
        )
      )
    )
      (asserts! (or difficulty-triggered energy-triggered) ERR-THRESHOLD-NOT-MET)
      
      ;; Calculate payout
      (let ((payout-amount (get coverage-amount policy)))
        ;; Transfer payout
        (try! (as-contract (stx-transfer? payout-amount tx-sender (get miner policy))))
        
        ;; Update policy
        (map-set policies 
          { policy-id: policy-id }
          (merge policy { claimed: true, active: false })
        )
        
        ;; Update miner profile
        (map-set miner-profiles 
          { miner: (get miner policy) }
          (merge current-profile { total-claims: (+ (get total-claims current-profile) u1) })
        )
        
        ;; Record event
        (map-set policy-events
          { policy-id: policy-id, event-type: "claim-processed" }
          { event-block: current-block, timestamp: (unwrap-panic (get-block-info? time current-block)), data: payout-amount }
        )
        
        (ok payout-amount)
      )
    )
  )
)

(define-public (cancel-policy (policy-id uint))
  (let (
    (policy (unwrap! (get-policy policy-id) ERR-NOT-FOUND))
    (current-block block-height)
  )
    (asserts! (is-eq tx-sender (get miner policy)) ERR-OWNER-ONLY)
    (asserts! (get active policy) ERR-NOT-FOUND)
    (asserts! (not (get claimed policy)) ERR-CLAIM-ALREADY-PROCESSED)
    (asserts! (< current-block (get start-block policy)) ERR-POLICY-EXPIRED)
    
    ;; Refund premium (minus protocol fee)
    (let ((refund-amount (get premium-paid policy)))
      (try! (as-contract (stx-transfer? refund-amount tx-sender (get miner policy))))
      
      ;; Deactivate policy
      (map-set policies 
        { policy-id: policy-id }
        (merge policy { active: false })
      )
      
      (ok refund-amount)
    )
  )
)

;; Treasury management

(define-public (withdraw-treasury (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (<= amount (var-get protocol-treasury)) ERR-INSUFFICIENT-BALANCE)
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER)))
    (var-set protocol-treasury (- (var-get protocol-treasury) amount))
    (ok amount)
  )
)

;; Initialize contract
(begin
  (map-set authorized-oracles { oracle: CONTRACT-OWNER } { authorized: true })
)