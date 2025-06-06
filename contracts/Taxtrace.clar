(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_INVALID_PERCENTAGE (err u104))

(define-data-var next-tax-id uint u1)
(define-data-var next-allocation-id uint u1)

(define-map tax-authorities 
  { authority-id: uint }
  {
    name: (string-ascii 50),
    wallet: principal,
    total-collected: uint,
    active: bool
  }
)

(define-map tax-records
  { tax-id: uint }
  {
    authority-id: uint,
    amount: uint,
    source: (string-ascii 100),
    timestamp: uint,
    stacks-block-height: uint
  }
)

(define-map allocation-categories
  { category-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    active: bool
  }
)

(define-map tax-allocations
  { allocation-id: uint }
  {
    tax-id: uint,
    category-id: uint,
    amount: uint,
    percentage: uint,
    allocated-by: principal,
    timestamp: uint
  }
)

(define-map authority-allocations
  { authority-id: uint, category-id: uint }
  { total-allocated: uint }
)

(define-read-only (get-tax-authority (authority-id uint))
  (map-get? tax-authorities { authority-id: authority-id })
)

(define-read-only (get-tax-record (tax-id uint))
  (map-get? tax-records { tax-id: tax-id })
)

(define-read-only (get-allocation-category (category-id uint))
  (map-get? allocation-categories { category-id: category-id })
)

(define-read-only (get-tax-allocation (allocation-id uint))
  (map-get? tax-allocations { allocation-id: allocation-id })
)

(define-read-only (get-authority-category-total (authority-id uint) (category-id uint))
  (default-to 
    { total-allocated: u0 }
    (map-get? authority-allocations { authority-id: authority-id, category-id: category-id })
  )
)

(define-read-only (get-next-tax-id)
  (var-get next-tax-id)
)

(define-read-only (get-next-allocation-id)
  (var-get next-allocation-id)
)

(define-public (register-tax-authority (name (string-ascii 50)) (wallet principal))
  (let ((authority-id (var-get next-tax-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? tax-authorities { authority-id: authority-id })) ERR_ALREADY_EXISTS)
    (map-set tax-authorities
      { authority-id: authority-id }
      {
        name: name,
        wallet: wallet,
        total-collected: u0,
        active: true
      }
    )
    (var-set next-tax-id (+ authority-id u1))
    (ok authority-id)
  )
)

(define-public (create-allocation-category (name (string-ascii 50)) (description (string-ascii 200)))
  (let ((category-id (var-get next-allocation-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set allocation-categories
      { category-id: category-id }
      {
        name: name,
        description: description,
        active: true
      }
    )
    (var-set next-allocation-id (+ category-id u1))
    (ok category-id)
  )
)

(define-public (record-tax-collection (authority-id uint) (amount uint) (source (string-ascii 100)))
  (let 
    (
      (tax-id (var-get next-tax-id))
      (authority (unwrap! (map-get? tax-authorities { authority-id: authority-id }) ERR_NOT_FOUND))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get active authority) ERR_NOT_FOUND)
    (map-set tax-records
      { tax-id: tax-id }
      {
        authority-id: authority-id,
        amount: amount,
        source: source,
        timestamp: stacks-block-height,
        stacks-block-height: stacks-block-height
      }
    )
    (map-set tax-authorities
      { authority-id: authority-id }
      (merge authority { total-collected: (+ (get total-collected authority) amount) })
    )
    (var-set next-tax-id (+ tax-id u1))
    (ok tax-id)
  )
)

(define-public (allocate-tax-funds (tax-id uint) (category-id uint) (amount uint))
  (let 
    (
      (allocation-id (var-get next-allocation-id))
      (tax-record (unwrap! (map-get? tax-records { tax-id: tax-id }) ERR_NOT_FOUND))
      (category (unwrap! (map-get? allocation-categories { category-id: category-id }) ERR_NOT_FOUND))
      (authority-id (get authority-id tax-record))
      (tax-amount (get amount tax-record))
      (percentage (/ (* amount u10000) tax-amount))
      (current-allocation (get total-allocated (get-authority-category-total authority-id category-id)))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount tax-amount) ERR_INVALID_AMOUNT)
    (asserts! (get active category) ERR_NOT_FOUND)
    (asserts! (<= percentage u10000) ERR_INVALID_PERCENTAGE)
    (map-set tax-allocations
      { allocation-id: allocation-id }
      {
        tax-id: tax-id,
        category-id: category-id,
        amount: amount,
        percentage: percentage,
        allocated-by: tx-sender,
        timestamp: stacks-block-height
      }
    )
    (map-set authority-allocations
      { authority-id: authority-id, category-id: category-id }
      { total-allocated: (+ current-allocation amount) }
    )
    (var-set next-allocation-id (+ allocation-id u1))
    (ok allocation-id)
  )
)

(define-public (deactivate-authority (authority-id uint))
  (let ((authority (unwrap! (map-get? tax-authorities { authority-id: authority-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set tax-authorities
      { authority-id: authority-id }
      (merge authority { active: false })
    )
    (ok true)
  )
)

(define-public (deactivate-category (category-id uint))
  (let ((category (unwrap! (map-get? allocation-categories { category-id: category-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set allocation-categories
      { category-id: category-id }
      (merge category { active: false })
    )
    (ok true)
  )
)

(define-read-only (calculate-allocation-percentage (tax-id uint) (amount uint))
  (let ((tax-record (unwrap! (map-get? tax-records { tax-id: tax-id }) ERR_NOT_FOUND)))
    (ok (/ (* amount u10000) (get amount tax-record)))
  )
)

(define-read-only (get-authority-total-by-category (authority-id uint) (category-id uint))
  (get total-allocated (get-authority-category-total authority-id category-id))
)