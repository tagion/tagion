;; Test aligned and unaligned read/write

(module
  (memory 1)

  ;; $default: natural alignment, $1: align=1, $2: align=2, $4: align=4, $8: align=8

  (func (export "f32_align_switch") (param i32) (result f32)
    (local f32 f32)
    (local.set 1 (f32.const 10.0))
    (block $4
      (block $2
        (block $1
          (block $default
            (block $0
              (br_table $0 $default $1 $2 $4 (local.get 0))
            ) ;; 0
            (f32.store (i32.const 0) (local.get 1))
            (local.set 2 (f32.load (i32.const 0)))
            (br $4)
          ) ;; default
          (f32.store align=1 (i32.const 0) (local.get 1))
          (local.set 2 (f32.load align=1 (i32.const 0)))
          (br $4)
        ) ;; 1
        (f32.store align=2 (i32.const 0) (local.get 1))
        (local.set 2 (f32.load align=2 (i32.const 0)))
        (br $4)
      ) ;; 2
      (f32.store align=4 (i32.const 0) (local.get 1))
      (local.set 2 (f32.load align=4 (i32.const 0)))
    ) ;; 4
    (local.get 2)
  )

  (func (export "f64_align_switch") (param i32) (result f64)
    (local f64 f64)
    (local.set 1 (f64.const 10.0))
    (block $8
      (block $4
        (block $2
          (block $1
            (block $default
              (block $0
                (br_table $0 $default $1 $2 $4 $8 (local.get 0))
              ) ;; 0
              (f64.store (i32.const 0) (local.get 1))
              (local.set 2 (f64.load (i32.const 0)))
              (br $8)
            ) ;; default
            (f64.store align=1 (i32.const 0) (local.get 1))
            (local.set 2 (f64.load align=1 (i32.const 0)))
            (br $8)
          ) ;; 1
          (f64.store align=2 (i32.const 0) (local.get 1))
          (local.set 2 (f64.load align=2 (i32.const 0)))
          (br $8)
        ) ;; 2
        (f64.store align=4 (i32.const 0) (local.get 1))
        (local.set 2 (f64.load align=4 (i32.const 0)))
        (br $8)
      ) ;; 4
      (f64.store align=8 (i32.const 0) (local.get 1))
      (local.set 2 (f64.load align=8 (i32.const 0)))
    ) ;; 8
    (local.get 2)
  )

  ;; $8s: i32/i64.load8_s, $8u: i32/i64.load8_u, $16s: i32/i64.load16_s, $16u: i32/i64.load16_u, $32: i32.load
  ;; $32s: i64.load32_s, $32u: i64.load32_u, $64: i64.load

  (func (export "i32_align_switch") (param i32 i32) (result i32)
    (local i32 i32)
    (local.set 2 (i32.const 10))
    (block $32
      (block $16u
        (block $16s
          (block $8u
            (block $8s
              (block $0
                (br_table $0 $8s $8u $16s $16u $32 (local.get 0))
              ) ;; 0
              (if (i32.eq (local.get 1) (i32.const 0))
                (then
                  (i32.store8 (i32.const 0) (local.get 2))
                  (local.set 3 (i32.load8_s (i32.const 0)))
                )
              )
              (if (i32.eq (local.get 1) (i32.const 1))
                (then
                  (i32.store8 align=1 (i32.const 0) (local.get 2))
                  (local.set 3 (i32.load8_s align=1 (i32.const 0)))
                )
              )
              (br $32)
            ) ;; 8s
            (if (i32.eq (local.get 1) (i32.const 0))
              (then
                (i32.store8 (i32.const 0) (local.get 2))
                (local.set 3 (i32.load8_u (i32.const 0)))
              )
            )
            (if (i32.eq (local.get 1) (i32.const 1))
              (then
                (i32.store8 align=1 (i32.const 0) (local.get 2))
                (local.set 3 (i32.load8_u align=1 (i32.const 0)))
              )
            )
            (br $32)
          ) ;; 8u
          (if (i32.eq (local.get 1) (i32.const 0))
            (then
              (i32.store16 (i32.const 0) (local.get 2))
              (local.set 3 (i32.load16_s (i32.const 0)))
            )
          )
          (if (i32.eq (local.get 1) (i32.const 1))
            (then
              (i32.store16 align=1 (i32.const 0) (local.get 2))
              (local.set 3 (i32.load16_s align=1 (i32.const 0)))
            )
          )
          (if (i32.eq (local.get 1) (i32.const 2))
            (then
              (i32.store16 align=2 (i32.const 0) (local.get 2))
              (local.set 3 (i32.load16_s align=2 (i32.const 0)))
            )
          )
          (br $32)
        ) ;; 16s
        (if (i32.eq (local.get 1) (i32.const 0))
          (then
            (i32.store16 (i32.const 0) (local.get 2))
            (local.set 3 (i32.load16_u (i32.const 0)))
          )
        )
        (if (i32.eq (local.get 1) (i32.const 1))
          (then
            (i32.store16 align=1 (i32.const 0) (local.get 2))
            (local.set 3 (i32.load16_u align=1 (i32.const 0)))
          )
        )
        (if (i32.eq (local.get 1) (i32.const 2))
          (then
            (i32.store16 align=2 (i32.const 0) (local.get 2))
            (local.set 3 (i32.load16_u align=2 (i32.const 0)))
          )
        )
        (br $32)
      ) ;; 16u
      (if (i32.eq (local.get 1) (i32.const 0))
        (then
          (i32.store (i32.const 0) (local.get 2))
          (local.set 3 (i32.load (i32.const 0)))
        )
      )
      (if (i32.eq (local.get 1) (i32.const 1))
        (then
          (i32.store align=1 (i32.const 0) (local.get 2))
          (local.set 3 (i32.load align=1 (i32.const 0)))
        )
      )
      (if (i32.eq (local.get 1) (i32.const 2))
        (then
          (i32.store align=2 (i32.const 0) (local.get 2))
          (local.set 3 (i32.load align=2 (i32.const 0)))
        )
      )
      (if (i32.eq (local.get 1) (i32.const 4))
        (then
          (i32.store align=4 (i32.const 0) (local.get 2))
          (local.set 3 (i32.load align=4 (i32.const 0)))
        )
      )
    ) ;; 32
    (local.get 3)
  )

  (func (export "i64_align_switch") (param i32 i32) (result i64)
    (local i64 i64)
    (local.set 2 (i64.const 10))
    (block $64
      (block $32u
        (block $32s
          (block $16u
            (block $16s
              (block $8u
                (block $8s
                  (block $0
                    (br_table $0 $8s $8u $16s $16u $32s $32u $64 (local.get 0))
                  ) ;; 0
                  (if (i32.eq (local.get 1) (i32.const 0))
                    (then
                      (i64.store8 (i32.const 0) (local.get 2))
                      (local.set 3 (i64.load8_s (i32.const 0)))
                    )
                  )
                  (if (i32.eq (local.get 1) (i32.const 1))
                    (then
                      (i64.store8 align=1 (i32.const 0) (local.get 2))
                      (local.set 3 (i64.load8_s align=1 (i32.const 0)))
                    )
                  )
                  (br $64)
                ) ;; 8s
                (if (i32.eq (local.get 1) (i32.const 0))
                  (then
                    (i64.store8 (i32.const 0) (local.get 2))
                    (local.set 3 (i64.load8_u (i32.const 0)))
                  )
                )
                (if (i32.eq (local.get 1) (i32.const 1))
                  (then
                    (i64.store8 align=1 (i32.const 0) (local.get 2))
                    (local.set 3 (i64.load8_u align=1 (i32.const 0)))
                  )
                )
                (br $64)
              ) ;; 8u
              (if (i32.eq (local.get 1) (i32.const 0))
                (then
                  (i64.store16 (i32.const 0) (local.get 2))
                  (local.set 3 (i64.load16_s (i32.const 0)))
                )
              )
              (if (i32.eq (local.get 1) (i32.const 1))
                (then
                  (i64.store16 align=1 (i32.const 0) (local.get 2))
                  (local.set 3 (i64.load16_s align=1 (i32.const 0)))
                )
              )
              (if (i32.eq (local.get 1) (i32.const 2))
                (then
                  (i64.store16 align=2 (i32.const 0) (local.get 2))
                  (local.set 3 (i64.load16_s align=2 (i32.const 0)))
                )
              )
              (br $64)
            ) ;; 16s
            (if (i32.eq (local.get 1) (i32.const 0))
              (then
                (i64.store16 (i32.const 0) (local.get 2))
                (local.set 3 (i64.load16_u (i32.const 0)))
              )
            )
            (if (i32.eq (local.get 1) (i32.const 1))
              (then
                (i64.store16 align=1 (i32.const 0) (local.get 2))
                (local.set 3 (i64.load16_u align=1 (i32.const 0)))
              )
            )
            (if (i32.eq (local.get 1) (i32.const 2))
              (then
                (i64.store16 align=2 (i32.const 0) (local.get 2))
                (local.set 3 (i64.load16_u align=2 (i32.const 0)))
              )
            )
            (br $64)
          ) ;; 16u
          (if (i32.eq (local.get 1) (i32.const 0))
            (then
              (i64.store32 (i32.const 0) (local.get 2))
              (local.set 3 (i64.load32_s (i32.const 0)))
            )
          )
          (if (i32.eq (local.get 1) (i32.const 1))
            (then
              (i64.store32 align=1 (i32.const 0) (local.get 2))
              (local.set 3 (i64.load32_s align=1 (i32.const 0)))
            )
          )
          (if (i32.eq (local.get 1) (i32.const 2))
            (then
              (i64.store32 align=2 (i32.const 0) (local.get 2))
              (local.set 3 (i64.load32_s align=2 (i32.const 0)))
            )
          )
          (if (i32.eq (local.get 1) (i32.const 4))
            (then
              (i64.store32 align=4 (i32.const 0) (local.get 2))
              (local.set 3 (i64.load32_s align=4 (i32.const 0)))
            )
          )
          (br $64)
        ) ;; 32s
        (if (i32.eq (local.get 1) (i32.const 0))
          (then
            (i64.store32 (i32.const 0) (local.get 2))
            (local.set 3 (i64.load32_u (i32.const 0)))
          )
        )
        (if (i32.eq (local.get 1) (i32.const 1))
          (then
            (i64.store32 align=1 (i32.const 0) (local.get 2))
            (local.set 3 (i64.load32_u align=1 (i32.const 0)))
          )
        )
        (if (i32.eq (local.get 1) (i32.const 2))
          (then
            (i64.store32 align=2 (i32.const 0) (local.get 2))
            (local.set 3 (i64.load32_u align=2 (i32.const 0)))
          )
        )
        (if (i32.eq (local.get 1) (i32.const 4))
          (then
            (i64.store32 align=4 (i32.const 0) (local.get 2))
            (local.set 3 (i64.load32_u align=4 (i32.const 0)))
          )
        )
        (br $64)
      ) ;; 32u
      (if (i32.eq (local.get 1) (i32.const 0))
        (then
          (i64.store (i32.const 0) (local.get 2))
          (local.set 3 (i64.load (i32.const 0)))
        )
      )
      (if (i32.eq (local.get 1) (i32.const 1))
        (then
          (i64.store align=1 (i32.const 0) (local.get 2))
          (local.set 3 (i64.load align=1 (i32.const 0)))
        )
      )
      (if (i32.eq (local.get 1) (i32.const 2))
        (then
          (i64.store align=2 (i32.const 0) (local.get 2))
          (local.set 3 (i64.load align=2 (i32.const 0)))
        )
      )
      (if (i32.eq (local.get 1) (i32.const 4))
        (then
          (i64.store align=4 (i32.const 0) (local.get 2))
          (local.set 3 (i64.load align=4 (i32.const 0)))
        )
      )
      (if (i32.eq (local.get 1) (i32.const 8))
        (then
          (i64.store align=8 (i32.const 0) (local.get 2))
          (local.set 3 (i64.load align=8 (i32.const 0)))
        )
      )
    ) ;; 64
    (local.get 3)
  )
)

(assert_return (invoke "f32_align_switch" (i32.const 0)) (f32.const 10.0))
(assert_return (invoke "f32_align_switch" (i32.const 1)) (f32.const 10.0))
(assert_return (invoke "f32_align_switch" (i32.const 2)) (f32.const 10.0))
(assert_return (invoke "f32_align_switch" (i32.const 3)) (f32.const 10.0))

(assert_return (invoke "f64_align_switch" (i32.const 0)) (f64.const 10.0))
(assert_return (invoke "f64_align_switch" (i32.const 1)) (f64.const 10.0))
(assert_return (invoke "f64_align_switch" (i32.const 2)) (f64.const 10.0))
(assert_return (invoke "f64_align_switch" (i32.const 3)) (f64.const 10.0))
(assert_return (invoke "f64_align_switch" (i32.const 4)) (f64.const 10.0))

(assert_return (invoke "i32_align_switch" (i32.const 0) (i32.const 0)) (i32.const 10))
(assert_return (invoke "i32_align_switch" (i32.const 0) (i32.const 1)) (i32.const 10))
(assert_return (invoke "i32_align_switch" (i32.const 1) (i32.const 0)) (i32.const 10))
(assert_return (invoke "i32_align_switch" (i32.const 1) (i32.const 1)) (i32.const 10))
(assert_return (invoke "i32_align_switch" (i32.const 2) (i32.const 0)) (i32.const 10))
(assert_return (invoke "i32_align_switch" (i32.const 2) (i32.const 1)) (i32.const 10))
(assert_return (invoke "i32_align_switch" (i32.const 2) (i32.const 2)) (i32.const 10))
(assert_return (invoke "i32_align_switch" (i32.const 3) (i32.const 0)) (i32.const 10))
(assert_return (invoke "i32_align_switch" (i32.const 3) (i32.const 1)) (i32.const 10))
(assert_return (invoke "i32_align_switch" (i32.const 3) (i32.const 2)) (i32.const 10))
(assert_return (invoke "i32_align_switch" (i32.const 4) (i32.const 0)) (i32.const 10))
(assert_return (invoke "i32_align_switch" (i32.const 4) (i32.const 1)) (i32.const 10))
(assert_return (invoke "i32_align_switch" (i32.const 4) (i32.const 2)) (i32.const 10))
(assert_return (invoke "i32_align_switch" (i32.const 4) (i32.const 4)) (i32.const 10))

(assert_return (invoke "i64_align_switch" (i32.const 0) (i32.const 0)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 0) (i32.const 1)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 1) (i32.const 0)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 1) (i32.const 1)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 2) (i32.const 0)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 2) (i32.const 1)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 2) (i32.const 2)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 3) (i32.const 0)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 3) (i32.const 1)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 3) (i32.const 2)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 4) (i32.const 0)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 4) (i32.const 1)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 4) (i32.const 2)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 4) (i32.const 4)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 5) (i32.const 0)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 5) (i32.const 1)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 5) (i32.const 2)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 5) (i32.const 4)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 6) (i32.const 0)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 6) (i32.const 1)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 6) (i32.const 2)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 6) (i32.const 4)) (i64.const 10))
(assert_return (invoke "i64_align_switch" (i32.const 6) (i32.const 8)) (i64.const 10))


