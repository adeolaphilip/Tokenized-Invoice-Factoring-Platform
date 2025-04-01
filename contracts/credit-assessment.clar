;; Credit Assessment Contract
;; This contract evaluates the likelihood of invoice payment

(define-data-var admin principal tx-sender)

;; Credit score: 0-100 scale, higher is better
(define-map credit-scores
  { entity: principal }
  { score: uint }
)

;; Invoice risk assessment: 0-100 scale, higher means more risk
(define-map invoice-risk
  { invoice-id: (string-ascii 32) }
  {
    risk-score: uint,
    assessment-date: uint
  }
)

(define-read-only (get-credit-score (entity principal))
  (default-to { score: u50 } (map-get? credit-scores { entity: entity }))
)

(define-read-only (get-invoice-risk (invoice-id (string-ascii 32)))
  (map-get? invoice-risk { invoice-id: invoice-id })
)

(define-public (set-credit-score (entity principal) (score uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Not authorized
    (asserts! (<= score u100) (err u2)) ;; Score must be between 0-100

    (map-set credit-scores
      { entity: entity }
      { score: score }
    )
    (ok true)
  )
)

(define-public (assess-invoice-risk
    (invoice-id (string-ascii 32))
    (debtor principal))
  (let (
      (credit-info (get-credit-score debtor))
      (risk-score (- u100 (get score credit-info)))
    )
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Not authorized

    (map-set invoice-risk
      { invoice-id: invoice-id }
      {
        risk-score: risk-score,
        assessment-date: (unwrap-panic (get-block-info? time u0))
      }
    )
    (ok risk-score)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Not authorized
    (var-set admin new-admin)
    (ok true)
  )
)

