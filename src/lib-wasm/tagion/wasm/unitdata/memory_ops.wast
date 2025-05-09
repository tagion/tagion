;; Test memory section structure
(module
  (memory 1024 (segment 0 "ABC\a7D") (segment 20 "WASM"))

  ;; Data section
  (func $data (result i32)
    (i32.and
      (i32.and
        (i32.and
          (i32.eq (i32.load8_u (i32.const 0)) (i32.const 65))
          (i32.eq (i32.load8_u (i32.const 3)) (i32.const 167))
        )
        (i32.and
          (i32.eq (i32.load8_u (i32.const 6)) (i32.const 0))
          (i32.eq (i32.load8_u (i32.const 19)) (i32.const 0))
        )
      )
      (i32.and
        (i32.and
          (i32.eq (i32.load8_u (i32.const 20)) (i32.const 87))
          (i32.eq (i32.load8_u (i32.const 23)) (i32.const 77))
        )
        (i32.and
          (i32.eq (i32.load8_u (i32.const 24)) (i32.const 0))
          (i32.eq (i32.load8_u (i32.const 1023)) (i32.const 0))
        )
      )
    )
  )

  ;; Aligned read/write
  (func $aligned (result i32)
    (local i32 i32 i32)
    (set_local 0 (i32.const 10))
    (label
      (loop
        (if
          (i32.eq (get_local 0) (i32.const 0))
          (br 1)
        )
        (set_local 2 (i32.mul (get_local 0) (i32.const 4)))
        (i32.store (get_local 2) (get_local 0))
        (set_local 1 (i32.load (get_local 2)))
        (if
          (i32.ne (get_local 0) (get_local 1))
          (return (i32.const 0))
        )
        (set_local 0 (i32.sub (get_local 0) (i32.const 1)))
        (br 0)
      )
    )
    (return (i32.const 1))
  )

  ;; Unaligned read/write
  (func $unaligned (result i32)
    (local i32 f64 f64)
    (set_local 0 (i32.const 10))
    (label
      (loop
        (if
          (i32.eq (get_local 0) (i32.const 0))
          (br 1)
        )
        (set_local 2 (f64.convert_s/i32 (get_local 0)))
        (f64.store align=1 (get_local 0) (get_local 2))
        (set_local 1 (f64.load align=1 (get_local 0)))
        (if
          (f64.ne (get_local 2) (get_local 1))
          (return (i32.const 0))
        )
        (set_local 0 (i32.sub (get_local 0) (i32.const 1)))
        (br 0)
      )
    )
    (return (i32.const 1))
  )

  ;; Memory cast
  (func $cast (result f64)
    (i64.store (i32.const 8) (i64.const -12345))
    (if
      (f64.eq
        (f64.load (i32.const 8))
        (f64.reinterpret/i64 (i64.const -12345))
      )
      (return (f64.const 0))
    )
    (i64.store align=1 (i32.const 9) (i64.const 0))
    (i32.store16 align=1 (i32.const 15) (i32.const 16453))
    (return (f64.load align=1 (i32.const 9)))
  )

  ;; Sign and zero extending memory loads
  (func $i32_load8_s (param $i i32) (result i32)
	(i32.store8 (i32.const 8) (get_local $i))
	(return (i32.load8_s (i32.const 8)))
  )
  (func $i32_load8_u (param $i i32) (result i32)
	(i32.store8 (i32.const 8) (get_local $i))
	(return (i32.load8_u (i32.const 8)))
  )
  (func $i32_load16_s (param $i i32) (result i32)
	(i32.store16 (i32.const 8) (get_local $i))
	(return (i32.load16_s (i32.const 8)))
  )
  (func $i32_load16_u (param $i i32) (result i32)
	(i32.store16 (i32.const 8) (get_local $i))
	(return (i32.load16_u (i32.const 8)))
  )
  (func $i64_load8_s (param $i i64) (result i64)
	(i64.store8 (i32.const 8) (get_local $i))
	(return (i64.load8_s (i32.const 8)))
  )
  (func $i64_load8_u (param $i i64) (result i64)
	(i64.store8 (i32.const 8) (get_local $i))
	(return (i64.load8_u (i32.const 8)))
  )
  (func $i64_load16_s (param $i i64) (result i64)
	(i64.store16 (i32.const 8) (get_local $i))
	(return (i64.load16_s (i32.const 8)))
  )
  (func $i64_load16_u (param $i i64) (result i64)
	(i64.store16 (i32.const 8) (get_local $i))
	(return (i64.load16_u (i32.const 8)))
  )
  (func $i64_load32_s (param $i i64) (result i64)
	(i64.store32 (i32.const 8) (get_local $i))
	(return (i64.load32_s (i32.const 8)))
  )
  (func $i64_load32_u (param $i i64) (result i64)
	(i64.store32 (i32.const 8) (get_local $i))
	(return (i64.load32_u (i32.const 8)))
  )

  (export "data" $data)
  (export "aligned" $aligned)
  (export "unaligned" $unaligned)
  (export "cast" $cast)
  (export "i32_load8_s" $i32_load8_s)
  (export "i32_load8_u" $i32_load8_u)
  (export "i32_load16_s" $i32_load16_s)
  (export "i32_load16_u" $i32_load16_u)
  (export "i64_load8_s" $i64_load8_s)
  (export "i64_load8_u" $i64_load8_u)
  (export "i64_load16_s" $i64_load16_s)
  (export "i64_load16_u" $i64_load16_u)
  (export "i64_load32_s" $i64_load32_s)
  (export "i64_load32_u" $i64_load32_u)
)

(assert_return (invoke "data") (i32.const 1))
(assert_return (invoke "aligned") (i32.const 1))
(assert_return (invoke "unaligned") (i32.const 1))
(assert_return (invoke "cast") (f64.const 42.0))

(assert_return (invoke "i32_load8_s" (i32.const -1)) (i32.const -1))
(assert_return (invoke "i32_load8_u" (i32.const -1)) (i32.const 255))
(assert_return (invoke "i32_load16_s" (i32.const -1)) (i32.const -1))
(assert_return (invoke "i32_load16_u" (i32.const -1)) (i32.const 65535))

(assert_return (invoke "i32_load8_s" (i32.const 100)) (i32.const 100))
(assert_return (invoke "i32_load8_u" (i32.const 200)) (i32.const 200))
(assert_return (invoke "i32_load16_s" (i32.const 20000)) (i32.const 20000))
(assert_return (invoke "i32_load16_u" (i32.const 40000)) (i32.const 40000))

(assert_return (invoke "i64_load8_s" (i64.const -1)) (i64.const -1))
(assert_return (invoke "i64_load8_u" (i64.const -1)) (i64.const 255))
(assert_return (invoke "i64_load16_s" (i64.const -1)) (i64.const -1))
(assert_return (invoke "i64_load16_u" (i64.const -1)) (i64.const 65535))
(assert_return (invoke "i64_load32_s" (i64.const -1)) (i64.const -1))
(assert_return (invoke "i64_load32_u" (i64.const -1)) (i64.const 4294967295))

(assert_return (invoke "i64_load8_s" (i64.const 100)) (i64.const 100))
(assert_return (invoke "i64_load8_u" (i64.const 200)) (i64.const 200))
(assert_return (invoke "i64_load16_s" (i64.const 20000)) (i64.const 20000))
(assert_return (invoke "i64_load16_u" (i64.const 40000)) (i64.const 40000))
(assert_return (invoke "i64_load32_s" (i64.const 20000)) (i64.const 20000))
(assert_return (invoke "i64_load32_u" (i64.const 40000)) (i64.const 40000))
