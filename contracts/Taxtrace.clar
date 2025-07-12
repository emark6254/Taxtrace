(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_INVALID_PERCENTAGE (err u104))
(define-constant ERR_BUDGET_EXCEEDED (err u105))
(define-constant ERR_INVALID_BUDGET (err u106))
(define-constant ERR_BUDGET_NOT_FOUND (err u107))

(define-data-var next-tax-id uint u1)
(define-data-var next-allocation-id uint u1)
(define-data-var next-budget-id uint u1)

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

(define-map budget-plans
  { budget-id: uint }
  {
    authority-id: uint,
    category-id: uint,
    budget-limit: uint,
    fiscal-period-start: uint,
    fiscal-period-end: uint,
    created-by: principal,
    approved: bool,
    active: bool
  }
)

(define-map budget-utilization
  { authority-id: uint, category-id: uint, fiscal-period: uint }
  {
    total-allocated: uint,
    budget-limit: uint,
    remaining-budget: uint,
    utilization-percentage: uint,
    last-updated: uint
  }
)

(define-map budget-alerts
  { alert-id: uint }
  {
    authority-id: uint,
    category-id: uint,
    alert-type: (string-ascii 20),
    threshold-percentage: uint,
    alert-message: (string-ascii 200),
    triggered-at: uint,
    acknowledged: bool
  }
)

(define-data-var next-alert-id uint u1)

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

(define-read-only (get-budget-plan (budget-id uint))
  (map-get? budget-plans { budget-id: budget-id })
)

(define-read-only (get-budget-utilization (authority-id uint) (category-id uint) (fiscal-period uint))
  (map-get? budget-utilization { authority-id: authority-id, category-id: category-id, fiscal-period: fiscal-period })
)

(define-read-only (get-budget-alert (alert-id uint))
  (map-get? budget-alerts { alert-id: alert-id })
)

(define-read-only (get-next-budget-id)
  (var-get next-budget-id)
)

(define-read-only (get-next-alert-id)
  (var-get next-alert-id)
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
      (fiscal-period (/ stacks-block-height u2016))
      (budget-check (try! (check-budget-compliance authority-id category-id amount fiscal-period)))
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
    (unwrap-panic (update-budget-utilization authority-id category-id amount fiscal-period))
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

(define-public (create-budget-plan (authority-id uint) (category-id uint) (budget-limit uint) (fiscal-period-start uint) (fiscal-period-end uint))
  (let 
    (
      (budget-id (var-get next-budget-id))
      (authority (unwrap! (map-get? tax-authorities { authority-id: authority-id }) ERR_NOT_FOUND))
      (category (unwrap! (map-get? allocation-categories { category-id: category-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> budget-limit u0) ERR_INVALID_BUDGET)
    (asserts! (< fiscal-period-start fiscal-period-end) ERR_INVALID_BUDGET)
    (asserts! (get active authority) ERR_NOT_FOUND)
    (asserts! (get active category) ERR_NOT_FOUND)
    (map-set budget-plans
      { budget-id: budget-id }
      {
        authority-id: authority-id,
        category-id: category-id,
        budget-limit: budget-limit,
        fiscal-period-start: fiscal-period-start,
        fiscal-period-end: fiscal-period-end,
        created-by: tx-sender,
        approved: false,
        active: true
      }
    )
    (var-set next-budget-id (+ budget-id u1))
    (ok budget-id)
  )
)

(define-public (approve-budget-plan (budget-id uint))
  (let ((budget (unwrap! (map-get? budget-plans { budget-id: budget-id }) ERR_BUDGET_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (get active budget) ERR_BUDGET_NOT_FOUND)
    (map-set budget-plans
      { budget-id: budget-id }
      (merge budget { approved: true })
    )
    (ok true)
  )
)

(define-public (revoke-budget-plan (budget-id uint))
  (let ((budget (unwrap! (map-get? budget-plans { budget-id: budget-id }) ERR_BUDGET_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set budget-plans
      { budget-id: budget-id }
      (merge budget { active: false })
    )
    (ok true)
  )
)

(define-private (check-budget-compliance (authority-id uint) (category-id uint) (allocation-amount uint) (fiscal-period uint))
  (let 
    (
      (current-utilization (default-to 
        { total-allocated: u0, budget-limit: u0, remaining-budget: u0, utilization-percentage: u0, last-updated: u0 }
        (map-get? budget-utilization { authority-id: authority-id, category-id: category-id, fiscal-period: fiscal-period })
      ))
      (new-total (+ (get total-allocated current-utilization) allocation-amount))
      (budget-limit (get budget-limit current-utilization))
    )
    (if (> budget-limit u0)
      (begin
        (asserts! (<= new-total budget-limit) ERR_BUDGET_EXCEEDED)
        (if (>= (/ (* new-total u100) budget-limit) u80)
          (begin
            (unwrap-panic (create-budget-alert authority-id category-id "warning" u80 "Budget utilization approaching limit"))
            (ok true)
          )
          (ok true)
        )
      )
      (ok true)
    )
  )
)

(define-private (update-budget-utilization (authority-id uint) (category-id uint) (allocation-amount uint) (fiscal-period uint))
  (let 
    (
      (current-utilization (default-to 
        { total-allocated: u0, budget-limit: u0, remaining-budget: u0, utilization-percentage: u0, last-updated: u0 }
        (map-get? budget-utilization { authority-id: authority-id, category-id: category-id, fiscal-period: fiscal-period })
      ))
      (budget-limit (get budget-limit current-utilization))
      (new-total (+ (get total-allocated current-utilization) allocation-amount))
      (new-remaining (if (> budget-limit new-total) (- budget-limit new-total) u0))
      (new-percentage (if (> budget-limit u0) (/ (* new-total u100) budget-limit) u0))
    )
    (map-set budget-utilization
      { authority-id: authority-id, category-id: category-id, fiscal-period: fiscal-period }
      {
        total-allocated: new-total,
        budget-limit: budget-limit,
        remaining-budget: new-remaining,
        utilization-percentage: new-percentage,
        last-updated: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-private (create-budget-alert (authority-id uint) (category-id uint) (alert-type (string-ascii 20)) (threshold uint) (message (string-ascii 200)))
  (let ((alert-id (var-get next-alert-id)))
    (map-set budget-alerts
      { alert-id: alert-id }
      {
        authority-id: authority-id,
        category-id: category-id,
        alert-type: alert-type,
        threshold-percentage: threshold,
        alert-message: message,
        triggered-at: stacks-block-height,
        acknowledged: false
      }
    )
    (var-set next-alert-id (+ alert-id u1))
    (ok alert-id)
  )
)

(define-public (acknowledge-budget-alert (alert-id uint))
  (let ((alert (unwrap! (map-get? budget-alerts { alert-id: alert-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set budget-alerts
      { alert-id: alert-id }
      (merge alert { acknowledged: true })
    )
    (ok true)
  )
)

(define-public (initialize-budget-utilization (authority-id uint) (category-id uint) (budget-limit uint) (fiscal-period uint))
  (let 
    (
      (authority (unwrap! (map-get? tax-authorities { authority-id: authority-id }) ERR_NOT_FOUND))
      (category (unwrap! (map-get? allocation-categories { category-id: category-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> budget-limit u0) ERR_INVALID_BUDGET)
    (asserts! (get active authority) ERR_NOT_FOUND)
    (asserts! (get active category) ERR_NOT_FOUND)
    (map-set budget-utilization
      { authority-id: authority-id, category-id: category-id, fiscal-period: fiscal-period }
      {
        total-allocated: u0,
        budget-limit: budget-limit,
        remaining-budget: budget-limit,
        utilization-percentage: u0,
        last-updated: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-read-only (calculate-budget-variance (authority-id uint) (category-id uint) (fiscal-period uint))
  (let 
    (
      (utilization (map-get? budget-utilization { authority-id: authority-id, category-id: category-id, fiscal-period: fiscal-period }))
    )
    (match utilization
      budget-data
        (let 
          (
            (total-allocated (get total-allocated budget-data))
            (budget-limit (get budget-limit budget-data))
            (variance (if (> budget-limit total-allocated) (- budget-limit total-allocated) (- total-allocated budget-limit)))
          )
          (ok { variance: variance, over-budget: (> total-allocated budget-limit) })
        )
      ERR_BUDGET_NOT_FOUND
    )
  )
)