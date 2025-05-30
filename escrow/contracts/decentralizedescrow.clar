;; Decentralized Escrow Smart Contract
;; A trustless escrow system for secure peer-to-peer transactions

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INSUFFICIENT_BALANCE (err u201))
(define-constant ERR_INVALID_AMOUNT (err u202))
(define-constant ERR_ESCROW_NOT_FOUND (err u203))
(define-constant ERR_ESCROW_ALREADY_RELEASED (err u204))
(define-constant ERR_INVALID_PARTICIPANT (err u205))
(define-constant ERR_ESCROW_NOT_EXPIRED (err u206))
(define-constant ERR_DISPUTE_ALREADY_RAISED (err u207))
(define-constant MIN_ESCROW_AMOUNT u500000) ;; 0.5 STX minimum
(define-constant ESCROW_FEE_RATE u50) ;; 0.5% fee
(define-constant DISPUTE_TIMEOUT_BLOCKS u1008) ;; ~7 days

;; Data Variables
(define-data-var next-escrow-id uint u1)
(define-data-var total-escrows-created uint u0)
(define-data-var total-fees-earned uint u0)

;; Data Maps
(define-map escrows
  { escrow-id: uint }
  {
    buyer: principal,
    seller: principal,
    amount: uint,
    fee: uint,
    created-at: uint,
    released: bool,
    disputed: bool,
    description: (string-ascii 256)
  }
)

(define-map arbitrators
  { arbitrator: principal }
  { active: bool, reputation: uint }
)

(define-map dispute-resolutions
  { escrow-id: uint }
  {
    arbitrator: principal,
    resolved-at: uint,
    winner: principal,
    resolution-notes: (string-ascii 512)
  }
)

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (is-active-arbitrator)
  (default-to false (get active (map-get? arbitrators { arbitrator: tx-sender })))
)

;; Utility Functions
(define-private (calculate-escrow-fee (amount uint))
  (/ (* amount ESCROW_FEE_RATE) u10000)
)

(define-private (is-valid-escrow-amount (amount uint))
  (>= amount MIN_ESCROW_AMOUNT)
)

(define-private (is-escrow-participant (escrow-id uint) (user principal))
  (match (map-get? escrows { escrow-id: escrow-id })
    escrow-data (or 
      (is-eq user (get buyer escrow-data))
      (is-eq user (get seller escrow-data))
    )
    false
  )
)

;; Core Escrow Functions
(define-public (create-escrow (seller principal) (amount uint) (description (string-ascii 256)))
  (let (
    (escrow-id (var-get next-escrow-id))
    (fee (calculate-escrow-fee amount))
    (total-amount (+ amount fee))
  )
    (asserts! (is-valid-escrow-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (not (is-eq tx-sender seller)) ERR_INVALID_PARTICIPANT)
    
    ;; Transfer funds to contract
    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
    
    ;; Store escrow details
    (map-set escrows
      { escrow-id: escrow-id }
      {
        buyer: tx-sender,
        seller: seller,
        amount: amount,
        fee: fee,
        created-at: stacks-block-height,
        released: false,
        disputed: false,
        description: description
      }
    )
    
    ;; Update counters
    (var-set next-escrow-id (+ escrow-id u1))
    (var-set total-escrows-created (+ (var-get total-escrows-created) u1))
    
    (ok escrow-id)
  )
)

(define-public (release-escrow (escrow-id uint))
  (let (
    (escrow-data (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR_ESCROW_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get buyer escrow-data)) ERR_UNAUTHORIZED)
    (asserts! (not (get released escrow-data)) ERR_ESCROW_ALREADY_RELEASED)
    (asserts! (not (get disputed escrow-data)) ERR_DISPUTE_ALREADY_RAISED)
    
    ;; Transfer amount to seller
    (try! (as-contract (stx-transfer? (get amount escrow-data) tx-sender (get seller escrow-data))))
    
    ;; Collect fee
    (var-set total-fees-earned (+ (var-get total-fees-earned) (get fee escrow-data)))
    
    ;; Mark as released
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { released: true })
    )
    
    (ok true)
  )
)

(define-public (raise-dispute (escrow-id uint))
  (let (
    (escrow-data (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR_ESCROW_NOT_FOUND))
  )
    (asserts! (is-escrow-participant escrow-id tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (get released escrow-data)) ERR_ESCROW_ALREADY_RELEASED)
    (asserts! (not (get disputed escrow-data)) ERR_DISPUTE_ALREADY_RAISED)
    
    ;; Mark as disputed
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { disputed: true })
    )
    
    (ok true)
  )
)

(define-public (resolve-dispute (escrow-id uint) (winner principal) (resolution-notes (string-ascii 512)))
  (let (
    (escrow-data (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR_ESCROW_NOT_FOUND))
  )
    (asserts! (is-active-arbitrator) ERR_UNAUTHORIZED)
    (asserts! (get disputed escrow-data) ERR_UNAUTHORIZED)
    (asserts! (not (get released escrow-data)) ERR_ESCROW_ALREADY_RELEASED)
    (asserts! (or 
      (is-eq winner (get buyer escrow-data))
      (is-eq winner (get seller escrow-data))
    ) ERR_INVALID_PARTICIPANT)
    
    ;; Transfer amount to winner
    (try! (as-contract (stx-transfer? (get amount escrow-data) tx-sender winner)))
    
    ;; Collect fee
    (var-set total-fees-earned (+ (var-get total-fees-earned) (get fee escrow-data)))
    
    ;; Record resolution
    (map-set dispute-resolutions
      { escrow-id: escrow-id }
      {
        arbitrator: tx-sender,
        resolved-at: stacks-block-height,
        winner: winner,
        resolution-notes: resolution-notes
      }
    )
    
    ;; Mark as released
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { released: true })
    )
    
    (ok true)
  )
)

;; Administrative Functions
(define-public (add-arbitrator (arbitrator principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (map-set arbitrators { arbitrator: arbitrator } { active: true, reputation: u0 })
    (ok true)
  )
)

(define-public (remove-arbitrator (arbitrator principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (map-set arbitrators { arbitrator: arbitrator } { active: false, reputation: u0 })
    (ok true)
  )
)

(define-public (withdraw-fees (amount uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (<= amount (var-get total-fees-earned)) ERR_INSUFFICIENT_BALANCE)
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
    (var-set total-fees-earned (- (var-get total-fees-earned) amount))
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-escrow-details (escrow-id uint))
  (map-get? escrows { escrow-id: escrow-id })
)

(define-read-only (get-dispute-resolution (escrow-id uint))
  (map-get? dispute-resolutions { escrow-id: escrow-id })
)

(define-read-only (get-contract-stats)
  {
    total-escrows: (var-get total-escrows-created),
    total-fees: (var-get total-fees-earned),
    next-id: (var-get next-escrow-id)
  }
)

(define-read-only (calculate-fee (amount uint))
  (calculate-escrow-fee amount)
)

(define-read-only (is-arbitrator (user principal))
  (default-to false (get active (map-get? arbitrators { arbitrator: user })))
)
