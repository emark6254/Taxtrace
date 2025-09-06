;; TaxRateOptimizer - Data-driven tax rate optimization system
;; Analyzes collection patterns and budget needs to recommend optimal tax rates

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u500))
(define-constant err-invalid-parameters (err u501))
(define-constant err-data-not-found (err u502))
(define-constant err-analysis-not-ready (err u503))
(define-constant err-rate-not-found (err u504))
(define-constant err-insufficient-data (err u505))

;; Data variables
(define-data-var next-analysis-id uint u1)
(define-data-var next-rate-id uint u1)
(define-data-var optimization-enabled bool true)

;; Tax rate categories and their current rates
(define-map tax-rate-categories
    uint
    {
        category-name: (string-ascii 30),
        current-rate: uint, ;; Rate as percentage * 100 (e.g., 500 = 5.00%)
        minimum-rate: uint,
        maximum-rate: uint,
        collection-type: (string-ascii 20),
        is-active: bool,
        last-updated: uint
    }
)

;; Historical collection performance data
(define-map collection-performance
    {authority-id: uint, category-id: uint, period: uint}
    {
        period-start: uint,
        period-end: uint,
        target-collection: uint,
        actual-collection: uint,
        collection-efficiency: uint,
        compliance-rate: uint,
        economic-indicator: uint
    }
)

;; Rate optimization recommendations
(define-map rate-recommendations
    uint
    {
        authority-id: uint,
        category-id: uint,
        current-rate: uint,
        recommended-rate: uint,
        confidence-score: uint,
        reasoning: (string-ascii 150),
        impact-estimate: uint,
        created-at: uint,
        expires-at: uint,
        implemented: bool
    }
)

;; Economic indicators tracking
(define-map economic-indicators
    {authority-id: uint, period: uint}
    {
        unemployment-rate: uint,
        inflation-rate: uint,
        property-values: uint,
        business-growth: uint,
        population-change: uint,
        updated-at: uint
    }
)

;; Rate change history
(define-map rate-change-history
    uint
    {
        authority-id: uint,
        category-id: uint,
        old-rate: uint,
        new-rate: uint,
        change-reason: (string-ascii 100),
        implemented-by: principal,
        implementation-date: uint,
        projected-impact: uint
    }
)

;; Public functions

;; Initialize tax rate categories (admin only)
(define-public (init-tax-rate-categories)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (map-set tax-rate-categories u1
            {category-name: "Property", current-rate: u125, minimum-rate: u50, maximum-rate: u300,
             collection-type: "property", is-active: true, last-updated: stacks-block-height})
        (map-set tax-rate-categories u2
            {category-name: "Sales", current-rate: u875, minimum-rate: u400, maximum-rate: u1500,
             collection-type: "sales", is-active: true, last-updated: stacks-block-height})
        (map-set tax-rate-categories u3
            {category-name: "Business", current-rate: u650, minimum-rate: u300, maximum-rate: u1200,
             collection-type: "business", is-active: true, last-updated: stacks-block-height})
        (ok true)
    )
)

;; Record collection performance data
(define-public (record-collection-performance
    (authority-id uint)
    (category-id uint)
    (period uint)
    (target-collection uint)
    (actual-collection uint)
    (compliance-rate uint))
    (let
        (
            (collection-efficiency (if (> target-collection u0) 
                (/ (* actual-collection u100) target-collection) u0))
            (period-start (* period u2016)) ;; Approximate blocks per period
            (period-end (+ period-start u2016))
        )
        (asserts! (> target-collection u0) err-invalid-parameters)
        (asserts! (<= compliance-rate u100) err-invalid-parameters)
        
        (map-set collection-performance 
            {authority-id: authority-id, category-id: category-id, period: period}
            {
                period-start: period-start,
                period-end: period-end,
                target-collection: target-collection,
                actual-collection: actual-collection,
                collection-efficiency: collection-efficiency,
                compliance-rate: compliance-rate,
                economic-indicator: u100 ;; Neutral baseline
            }
        )
        (ok true)
    )
)

;; Update economic indicators
(define-public (update-economic-indicators
    (authority-id uint)
    (period uint)
    (unemployment-rate uint)
    (inflation-rate uint)
    (property-values uint)
    (business-growth uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (<= unemployment-rate u3000) err-invalid-parameters) ;; Max 30%
        (asserts! (<= inflation-rate u2000) err-invalid-parameters) ;; Max 20%
        
        (map-set economic-indicators {authority-id: authority-id, period: period}
            {
                unemployment-rate: unemployment-rate,
                inflation-rate: inflation-rate,
                property-values: property-values,
                business-growth: business-growth,
                population-change: u100, ;; Baseline
                updated-at: stacks-block-height
            }
        )
        (ok true)
    )
)

;; Generate rate optimization recommendation
(define-public (generate-rate-recommendation
    (authority-id uint)
    (category-id uint))
    (let
        (
            (recommendation-id (var-get next-analysis-id))
            (category-data (unwrap! (map-get? tax-rate-categories category-id) err-data-not-found))
            (current-rate (get current-rate category-data))
            (performance-data (get-recent-performance authority-id category-id))
            (economic-data (get-recent-economic-data authority-id))
            (recommended-rate (calculate-optimal-rate category-data performance-data economic-data))
            (confidence (calculate-confidence-score performance-data economic-data))
        )
        (asserts! (var-get optimization-enabled) err-not-authorized)
        (asserts! (get is-active category-data) err-invalid-parameters)
        
        (map-set rate-recommendations recommendation-id
            {
                authority-id: authority-id,
                category-id: category-id,
                current-rate: current-rate,
                recommended-rate: recommended-rate,
                confidence-score: confidence,
                reasoning: (generate-reasoning current-rate recommended-rate confidence),
                impact-estimate: (calculate-impact-estimate current-rate recommended-rate),
                created-at: stacks-block-height,
                expires-at: (+ stacks-block-height u2016), ;; 2 weeks
                implemented: false
            }
        )
        (var-set next-analysis-id (+ recommendation-id u1))
        (ok recommendation-id)
    )
)

;; Implement rate recommendation
(define-public (implement-rate-change
    (recommendation-id uint))
    (let
        (
            (recommendation (unwrap! (map-get? rate-recommendations recommendation-id) err-data-not-found))
            (category-id (get category-id recommendation))
            (authority-id (get authority-id recommendation))
            (new-rate (get recommended-rate recommendation))
            (old-rate (get current-rate recommendation))
            (category-data (unwrap! (map-get? tax-rate-categories category-id) err-data-not-found))
            (change-id (var-get next-rate-id))
        )
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (not (get implemented recommendation)) err-invalid-parameters)
        (asserts! (< stacks-block-height (get expires-at recommendation)) err-analysis-not-ready)
        (asserts! (>= new-rate (get minimum-rate category-data)) err-invalid-parameters)
        (asserts! (<= new-rate (get maximum-rate category-data)) err-invalid-parameters)
        
        ;; Update tax rate category
        (map-set tax-rate-categories category-id
            (merge category-data {
                current-rate: new-rate,
                last-updated: stacks-block-height
            })
        )
        
        ;; Mark recommendation as implemented
        (map-set rate-recommendations recommendation-id
            (merge recommendation {implemented: true})
        )
        
        ;; Record rate change history
        (map-set rate-change-history change-id
            {
                authority-id: authority-id,
                category-id: category-id,
                old-rate: old-rate,
                new-rate: new-rate,
                change-reason: "optimization",
                implemented-by: tx-sender,
                implementation-date: stacks-block-height,
                projected-impact: (get impact-estimate recommendation)
            }
        )
        
        (var-set next-rate-id (+ change-id u1))
        (ok change-id)
    )
)

;; Helper functions for rate calculation

;; Get recent performance data (simplified)
(define-private (get-recent-performance (authority-id uint) (category-id uint))
    (let
        (
            (current-period (/ stacks-block-height u2016))
            (recent-data (map-get? collection-performance 
                {authority-id: authority-id, category-id: category-id, period: current-period}))
        )
        (default-to 
            {period-start: u0, period-end: u0, target-collection: u0, actual-collection: u0,
             collection-efficiency: u100, compliance-rate: u85, economic-indicator: u100}
            recent-data)
    )
)

;; Get recent economic data (simplified)
(define-private (get-recent-economic-data (authority-id uint))
    (let
        (
            (current-period (/ stacks-block-height u2016))
            (economic-data (map-get? economic-indicators 
                {authority-id: authority-id, period: current-period}))
        )
        (default-to 
            {unemployment-rate: u500, inflation-rate: u300, property-values: u100,
             business-growth: u100, population-change: u100, updated-at: u0}
            economic-data)
    )
)

;; Calculate optimal rate based on data
(define-private (calculate-optimal-rate (category-data (tuple (category-name (string-ascii 30)) (current-rate uint) (minimum-rate uint) (maximum-rate uint) (collection-type (string-ascii 20)) (is-active bool) (last-updated uint))) (performance-data (tuple (period-start uint) (period-end uint) (target-collection uint) (actual-collection uint) (collection-efficiency uint) (compliance-rate uint) (economic-indicator uint))) (economic-data (tuple (unemployment-rate uint) (inflation-rate uint) (property-values uint) (business-growth uint) (population-change uint) (updated-at uint))))
    (let
        (
            (current-rate (get current-rate category-data))
            (efficiency (get collection-efficiency performance-data))
            (compliance (get compliance-rate performance-data))
            (unemployment (get unemployment-rate economic-data))
            (business-growth (get business-growth economic-data))
            
            ;; Calculate adjustment factor based on efficiency and economic conditions
            (efficiency-factor (if (> efficiency u110) u95  ;; Reduce rate if over-performing
                               (if (< efficiency u80) u105 u100))) ;; Increase if under-performing
            (economic-factor (if (> unemployment u1000) u95  ;; Reduce during high unemployment
                             (if (> business-growth u110) u102 u100))) ;; Slight increase during growth
            
            (adjustment-multiplier (/ (* efficiency-factor economic-factor) u100))
            (recommended-rate (/ (* current-rate adjustment-multiplier) u100))
            
            ;; Ensure within bounds
            (final-rate (if (< recommended-rate (get minimum-rate category-data))
                           (get minimum-rate category-data)
                           (if (> recommended-rate (get maximum-rate category-data))
                               (get maximum-rate category-data)
                               recommended-rate)))
        )
        final-rate
    )
)

;; Calculate confidence score for recommendation
(define-private (calculate-confidence-score (performance-data (tuple (period-start uint) (period-end uint) (target-collection uint) (actual-collection uint) (collection-efficiency uint) (compliance-rate uint) (economic-indicator uint))) (economic-data (tuple (unemployment-rate uint) (inflation-rate uint) (property-values uint) (business-growth uint) (population-change uint) (updated-at uint))))
    (let
        (
            (data-freshness (if (> (get updated-at economic-data) u0) u30 u10))
            (compliance-score (/ (get compliance-rate performance-data) u4))
            (efficiency-score (if (> (get collection-efficiency performance-data) u50) u25 u10))
            (stability-score (if (< (get unemployment-rate economic-data) u800) u20 u10))
        )
        (+ data-freshness compliance-score efficiency-score stability-score)
    )
)

;; Generate reasoning text based on rate change
(define-private (generate-reasoning (current-rate uint) (recommended-rate uint) (confidence uint))
    (if (> recommended-rate current-rate)
        "Increase recommended based on collection efficiency"
        (if (< recommended-rate current-rate)
            "Decrease recommended due to economic conditions"
            "Maintain current rate - optimal performance"
        )
    )
)

;; Calculate projected impact of rate change
(define-private (calculate-impact-estimate (current-rate uint) (recommended-rate uint))
    (if (> recommended-rate current-rate)
        (/ (* (- recommended-rate current-rate) u100) current-rate)
        (if (< recommended-rate current-rate)
            (/ (* (- current-rate recommended-rate) u100) current-rate)
            u0
        )
    )
)

;; Read-only functions

;; Get tax rate category
(define-read-only (get-tax-rate-category (category-id uint))
    (map-get? tax-rate-categories category-id)
)

;; Get rate recommendation
(define-read-only (get-rate-recommendation (recommendation-id uint))
    (map-get? rate-recommendations recommendation-id)
)

;; Get collection performance data
(define-read-only (get-collection-performance (authority-id uint) (category-id uint) (period uint))
    (map-get? collection-performance {authority-id: authority-id, category-id: category-id, period: period})
)

;; Get economic indicators
(define-read-only (get-economic-indicators (authority-id uint) (period uint))
    (map-get? economic-indicators {authority-id: authority-id, period: period})
)

;; Get rate change history
(define-read-only (get-rate-change-history (change-id uint))
    (map-get? rate-change-history change-id)
)

;; Calculate collection forecast
(define-read-only (forecast-collection 
    (authority-id uint)
    (category-id uint)
    (proposed-rate uint))
    (let
        (
            (performance-data (get-recent-performance authority-id category-id))
            (current-efficiency (get collection-efficiency performance-data))
            (last-collection (get actual-collection performance-data))
            (category-data (unwrap! (map-get? tax-rate-categories category-id) err-data-not-found))
            (current-rate (get current-rate category-data))
            
            ;; Simple forecast based on rate change and efficiency
            (rate-impact (if (> proposed-rate current-rate) u110 u95)) ;; 10% increase or 5% decrease
            (projected-collection (/ (* last-collection rate-impact) u100))
        )
        (ok {
            projected-collection: projected-collection,
            confidence-level: (calculate-confidence-score performance-data (get-recent-economic-data authority-id)),
            rate-change-impact: (calculate-impact-estimate current-rate proposed-rate)
        })
    )
)

;; Get optimization summary for authority
(define-read-only (get-optimization-summary (authority-id uint))
    (ok {
        total-categories: u3, ;; Fixed for demo
        active-recommendations: u0, ;; Would need iteration to calculate
        last-optimization: stacks-block-height,
        optimization-enabled: (var-get optimization-enabled)
    })
)

;; Administrative functions

;; Update tax rate category (admin only)
(define-public (update-tax-rate-category
    (category-id uint)
    (current-rate uint)
    (minimum-rate uint)
    (maximum-rate uint))
    (let
        (
            (category-data (unwrap! (map-get? tax-rate-categories category-id) err-rate-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (< minimum-rate maximum-rate) err-invalid-parameters)
        (asserts! (and (>= current-rate minimum-rate) (<= current-rate maximum-rate)) err-invalid-parameters)
        
        (map-set tax-rate-categories category-id
            (merge category-data {
                current-rate: current-rate,
                minimum-rate: minimum-rate,
                maximum-rate: maximum-rate,
                last-updated: stacks-block-height
            })
        )
        (ok true)
    )
)

;; Toggle optimization system (admin only)
(define-public (toggle-optimization-system (enabled bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (var-set optimization-enabled enabled)
        (ok enabled)
    )
)
