;; Test `br_if` operator

(module
  (func (export "as-block-last-value") (param i32) (result i32)
    (block (result i32)
      (call $dummy) (call $dummy) (br_if 0 (i32.const 11) (local.get 0))
    )
  )

)

(assert_return (invoke "as-block-first-value" (i32.const 0)) (i32.const 11))
(assert_return (invoke "as-block-first-value" (i32.const 1)) (i32.const 10))

