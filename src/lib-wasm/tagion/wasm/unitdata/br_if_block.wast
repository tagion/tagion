;; Test `br_if` operator

(module
  (func $dummy)

  (func (export "type-i32")
    (block (drop (i32.ctz (br_if 0 (i32.const 0) (i32.const 1)))))
  )
  (func (export "type-i64")
    (block (drop (i64.ctz (br_if 0 (i64.const 0) (i32.const 1)))))
  )
  (func (export "type-f32")
    (block (drop (f32.neg (br_if 0 (f32.const 0) (i32.const 1)))))
  )
  (func (export "type-f64")
    (block (drop (f64.neg (br_if 0 (f64.const 0) (i32.const 1)))))
  )

  (func (export "type-i32-value") (result i32)
    (block (result i32) (i32.ctz (br_if 0 (i32.const 1) (i32.const 1))))
  )
  (func (export "type-i64-value") (result i64)
    (block (result i64) (i64.ctz (br_if 0 (i64.const 2) (i32.const 1))))
  )
  (func (export "type-f32-value") (result f32)
    (block (result f32) (f32.neg (br_if 0 (f32.const 3) (i32.const 1))))
  )
  (func (export "type-f64-value") (result f64)
    (block (result f64) (f64.neg (br_if 0 (f64.const 4) (i32.const 1))))
  )

  (func (export "as-block-first") (param i32) (result i32)
    (block (br_if 0 (local.get 0)) (return (i32.const 2))) (i32.const 3)
  )
  (func (export "as-block-mid") (param i32) (result i32)
    (block (call $dummy) (br_if 0 (local.get 0)) (return (i32.const 2)))
    (i32.const 3)
  )
  (func (export "as-block-last") (param i32)
    (block (call $dummy) (call $dummy) (br_if 0 (local.get 0)))
  )

  (func (export "as-block-first-value") (param i32) (result i32)
    (block (result i32)
      (drop (br_if 0 (i32.const 10) (local.get 0))) (return (i32.const 11))
    )
  )
  (func (export "as-block-mid-value") (param i32) (result i32)
    (block (result i32)
      (call $dummy)
      (drop (br_if 0 (i32.const 20) (local.get 0)))
      (return (i32.const 21))
    )
  )
  (func (export "as-block-last-value") (param i32) (result i32)
    (block (result i32)
      (call $dummy) (call $dummy) (br_if 0 (i32.const 11) (local.get 0))
    )
  )

  (func (export "as-br-value") (result i32)
    (block (result i32) (br 0 (br_if 0 (i32.const 1) (i32.const 2))))
  )

  (func (export "as-br_if-cond")
    (block (br_if 0 (br_if 0 (i32.const 1) (i32.const 1))))
  )
  (func (export "as-br_if-value") (result i32)
    (block (result i32)
      (drop (br_if 0 (br_if 0 (i32.const 1) (i32.const 2)) (i32.const 3)))
      (i32.const 4)
    )
  )
  (func (export "as-br_if-value-cond") (param i32) (result i32)
    (block (result i32)
      (drop (br_if 0 (i32.const 2) (br_if 0 (i32.const 1) (local.get 0))))
      (i32.const 4)
    )
  )
)
(assert_return (invoke "type-i32"))
(assert_return (invoke "type-i64"))
(assert_return (invoke "type-f32"))
(assert_return (invoke "type-f64"))

(assert_return (invoke "type-i32-value") (i32.const 1))
(assert_return (invoke "type-i64-value") (i64.const 2))
(assert_return (invoke "type-f32-value") (f32.const 3))
(assert_return (invoke "type-f64-value") (f64.const 4))

(assert_return (invoke "as-block-first" (i32.const 0)) (i32.const 2))
(assert_return (invoke "as-block-first" (i32.const 1)) (i32.const 3))
(assert_return (invoke "as-block-mid" (i32.const 0)) (i32.const 2))
(assert_return (invoke "as-block-mid" (i32.const 1)) (i32.const 3))
(assert_return (invoke "as-block-last" (i32.const 0)))
(assert_return (invoke "as-block-last" (i32.const 1)))
(;

(assert_return (invoke "as-block-first-value" (i32.const 0)) (i32.const 11))
(assert_return (invoke "as-block-first-value" (i32.const 1)) (i32.const 10))
(assert_return (invoke "as-block-mid-value" (i32.const 0)) (i32.const 21))
(assert_return (invoke "as-block-mid-value" (i32.const 1)) (i32.const 20))
(assert_return (invoke "as-block-last-value" (i32.const 0)) (i32.const 11))
(assert_return (invoke "as-block-last-value" (i32.const 1)) (i32.const 11))

(assert_return (invoke "as-loop-first" (i32.const 0)) (i32.const 2))
(assert_return (invoke "as-loop-first" (i32.const 1)) (i32.const 3))
(assert_return (invoke "as-loop-mid" (i32.const 0)) (i32.const 2))
(assert_return (invoke "as-loop-mid" (i32.const 1)) (i32.const 4))
(assert_return (invoke "as-loop-last" (i32.const 0)))
(assert_return (invoke "as-loop-last" (i32.const 1)))

(assert_return (invoke "as-br-value") (i32.const 1))

(assert_return (invoke "as-br_if-cond"))
(assert_return (invoke "as-br_if-value") (i32.const 1))
(assert_return (invoke "as-br_if-value-cond" (i32.const 0)) (i32.const 2))
(assert_return (invoke "as-br_if-value-cond" (i32.const 1)) (i32.const 1))

(assert_return (invoke "as-br_table-index"))
(assert_return (invoke "as-br_table-value") (i32.const 1))
(assert_return (invoke "as-br_table-value-index") (i32.const 1))

(assert_return (invoke "as-return-value") (i64.const 1))

(assert_return (invoke "as-if-cond" (i32.const 0)) (i32.const 2))
(assert_return (invoke "as-if-cond" (i32.const 1)) (i32.const 1))
(assert_return (invoke "as-if-then" (i32.const 0) (i32.const 0)))
(assert_return (invoke "as-if-then" (i32.const 4) (i32.const 0)))
(assert_return (invoke "as-if-then" (i32.const 0) (i32.const 1)))
(assert_return (invoke "as-if-then" (i32.const 4) (i32.const 1)))
(assert_return (invoke "as-if-else" (i32.const 0) (i32.const 0)))
(assert_return (invoke "as-if-else" (i32.const 3) (i32.const 0)))
(assert_return (invoke "as-if-else" (i32.const 0) (i32.const 1)))
(assert_return (invoke "as-if-else" (i32.const 3) (i32.const 1)))

(assert_return (invoke "as-select-first" (i32.const 0)) (i32.const 3))
(assert_return (invoke "as-select-first" (i32.const 1)) (i32.const 3))
(assert_return (invoke "as-select-second" (i32.const 0)) (i32.const 3))
(assert_return (invoke "as-select-second" (i32.const 1)) (i32.const 3))
(assert_return (invoke "as-select-cond") (i32.const 3))

(assert_return (invoke "as-call-first") (i32.const 12))
(assert_return (invoke "as-call-mid") (i32.const 13))
(assert_return (invoke "as-call-last") (i32.const 14))

(assert_return (invoke "as-call_indirect-func") (i32.const 4))
(assert_return (invoke "as-call_indirect-first") (i32.const 4))
(assert_return (invoke "as-call_indirect-mid") (i32.const 4))
(assert_return (invoke "as-call_indirect-last") (i32.const 4))

(assert_return (invoke "as-local.set-value" (i32.const 0)) (i32.const -1))
(assert_return (invoke "as-local.set-value" (i32.const 1)) (i32.const 17))

(assert_return (invoke "as-local.tee-value" (i32.const 0)) (i32.const -1))
(assert_return (invoke "as-local.tee-value" (i32.const 1)) (i32.const 1))

(assert_return (invoke "as-global.set-value" (i32.const 0)) (i32.const -1))
(assert_return (invoke "as-global.set-value" (i32.const 1)) (i32.const 1))

(assert_return (invoke "as-load-address") (i32.const 1))
(assert_return (invoke "as-loadN-address") (i32.const 30))

(assert_return (invoke "as-store-address") (i32.const 30))
(assert_return (invoke "as-store-value") (i32.const 31))
(assert_return (invoke "as-storeN-address") (i32.const 32))
(assert_return (invoke "as-storeN-value") (i32.const 33))

(assert_return (invoke "as-unary-operand") (f64.const 1.0))
(assert_return (invoke "as-binary-left") (i32.const 1))
(assert_return (invoke "as-binary-right") (i32.const 1))
(assert_return (invoke "as-test-operand") (i32.const 0))
(assert_return (invoke "as-compare-left") (i32.const 1))
(assert_return (invoke "as-compare-right") (i32.const 1))
(assert_return (invoke "as-memory.grow-size") (i32.const 1))

(assert_return (invoke "nested-block-value" (i32.const 0)) (i32.const 21))
(assert_return (invoke "nested-block-value" (i32.const 1)) (i32.const 9))
(assert_return (invoke "nested-br-value" (i32.const 0)) (i32.const 5))
(assert_return (invoke "nested-br-value" (i32.const 1)) (i32.const 9))
(assert_return (invoke "nested-br_if-value" (i32.const 0)) (i32.const 5))
(assert_return (invoke "nested-br_if-value" (i32.const 1)) (i32.const 9))
(assert_return (invoke "nested-br_if-value-cond" (i32.const 0)) (i32.const 5))
(assert_return (invoke "nested-br_if-value-cond" (i32.const 1)) (i32.const 9))
(assert_return (invoke "nested-br_table-value" (i32.const 0)) (i32.const 5))
(assert_return (invoke "nested-br_table-value" (i32.const 1)) (i32.const 9))
(assert_return (invoke "nested-br_table-value-index" (i32.const 0)) (i32.const 5))
(assert_return (invoke "nested-br_table-value-index" (i32.const 1)) (i32.const 9))

(assert_invalid
  (module (func $type-false-i32 (block (i32.ctz (br_if 0 (i32.const 0))))))
  "type mismatch"
)
(assert_invalid
  (module (func $type-false-i64 (block (i64.ctz (br_if 0 (i32.const 0))))))
  "type mismatch"
)
(assert_invalid
  (module (func $type-false-f32 (block (f32.neg (br_if 0 (i32.const 0))))))
  "type mismatch"
)
(assert_invalid
  (module (func $type-false-f64 (block (f64.neg (br_if 0 (i32.const 0))))))
  "type mismatch"
)

(assert_invalid
  (module (func $type-true-i32 (block (i32.ctz (br_if 0 (i32.const 1))))))
  "type mismatch"
)
(assert_invalid
  (module (func $type-true-i64 (block (i64.ctz (br_if 0 (i64.const 1))))))
  "type mismatch"
)
(assert_invalid
  (module (func $type-true-f32 (block (f32.neg (br_if 0 (f32.const 1))))))
  "type mismatch"
)
(assert_invalid
  (module (func $type-true-f64 (block (f64.neg (br_if 0 (i64.const 1))))))
  "type mismatch"
)

(assert_invalid
  (module (func $type-false-arg-void-vs-num (result i32)
    (block (result i32) (br_if 0 (i32.const 0)) (i32.const 1))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-true-arg-void-vs-num (result i32)
    (block (result i32) (br_if 0 (i32.const 1)) (i32.const 1))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-false-arg-num-vs-void
    (block (br_if 0 (i32.const 0) (i32.const 0)))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-true-arg-num-vs-void
    (block (br_if 0 (i32.const 0) (i32.const 1)))
  ))
  "type mismatch"
)

(assert_invalid
  (module (func $type-false-arg-void-vs-num (result i32)
    (block (result i32) (br_if 0 (nop) (i32.const 0)) (i32.const 1))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-true-arg-void-vs-num (result i32)
    (block (result i32) (br_if 0 (nop) (i32.const 1)) (i32.const 1))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-false-arg-num-vs-num (result i32)
    (block (result i32)
      (drop (br_if 0 (i64.const 1) (i32.const 0))) (i32.const 1)
    )
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-true-arg-num-vs-num (result i32)
    (block (result i32)
      (drop (br_if 0 (i64.const 1) (i32.const 0))) (i32.const 1)
    )
  ))
  "type mismatch"
)

(assert_invalid
  (module (func $type-cond-empty-vs-i32
    (block (br_if 0))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-cond-void-vs-i32
    (block (br_if 0 (nop)))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-cond-num-vs-i32
    (block (br_if 0 (i64.const 0)))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-arg-cond-void-vs-i32 (result i32)
    (block (result i32) (br_if 0 (i32.const 0) (nop)) (i32.const 1))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-arg-void-vs-num-nested (result i32)
    (block (result i32) (i32.const 0) (block (br_if 1 (i32.const 1))))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-arg-cond-num-vs-i32 (result i32)
    (block (result i32) (br_if 0 (i32.const 0) (i64.const 0)) (i32.const 1))
  ))
  "type mismatch"
)

(assert_invalid
  (module
    (func $type-1st-cond-empty-in-then
      (block
        (i32.const 0) (i32.const 0)
        (if (result i32) (then (br_if 0)))
      )
      (i32.eqz) (drop)
    )
  )
  "type mismatch"
)
(assert_invalid
  (module
    (func $type-2nd-cond-empty-in-then
      (block
        (i32.const 0) (i32.const 0)
        (if (result i32) (then (br_if 0 (i32.const 1))))
      )
      (i32.eqz) (drop)
    )
  )
  "type mismatch"
)
(assert_invalid
  (module
    (func $type-1st-cond-empty-in-return
      (block (result i32)
        (return (br_if 0))
      )
      (i32.eqz) (drop)
    )
  )
  "type mismatch"
)
(assert_invalid
  (module
    (func $type-2nd-cond-empty-in-return
      (block (result i32)
        (return (br_if 0 (i32.const 1)))
      )
      (i32.eqz) (drop)
    )
  )
  "type mismatch"
)


(assert_invalid
  (module (func $unbound-label (br_if 1 (i32.const 1))))
  "unknown label"
)
(assert_invalid
  (module (func $unbound-nested-label (block (block (br_if 5 (i32.const 1))))))
  "unknown label"
)
(assert_invalid
  (module (func $large-label (br_if 0x10000001 (i32.const 1))))
  "unknown label"
)
;)
