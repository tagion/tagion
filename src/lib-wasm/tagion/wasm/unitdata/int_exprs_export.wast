;; Test that x+1<y+1 is not folded to x<y

(module
  (func $i32.no_fold_cmp_s_offset (param $x i32) (param $y i32) (result i32)
    (i32.lt_s (i32.add (local.get $x) (i32.const 1)) (i32.add (local.get $y) (i32.const 1))))
  (export "i32.no_fold_cmp_s_offset" $i32.no_fold_cmp_s_offset)
  (func $i32.no_fold_cmp_u_offset (param $x i32) (param $y i32) (result i32)
    (i32.lt_u (i32.add (local.get $x) (i32.const 1)) (i32.add (local.get $y) (i32.const 1))))
  (export "i32.no_fold_cmp_u_offset" $i32.no_fold_cmp_u_offset)

  (func $i64.no_fold_cmp_s_offset (param $x i64) (param $y i64) (result i32)
    (i64.lt_s (i64.add (local.get $x) (i64.const 1)) (i64.add (local.get $y) (i64.const 1))))
  (export "i64.no_fold_cmp_s_offset" $i64.no_fold_cmp_s_offset)
  (func $i64.no_fold_cmp_u_offset (param $x i64) (param $y i64) (result i32)
    (i64.lt_u (i64.add (local.get $x) (i64.const 1)) (i64.add (local.get $y) (i64.const 1))))
  (export "i64.no_fold_cmp_u_offset" $i64.no_fold_cmp_u_offset)
)

(assert_return (invoke "i32.no_fold_cmp_s_offset" (i32.const 0x7fffffff) (i32.const 0)) (i32.const 1))
(assert_return (invoke "i32.no_fold_cmp_u_offset" (i32.const 0xffffffff) (i32.const 0)) (i32.const 1))
(assert_return (invoke "i64.no_fold_cmp_s_offset" (i64.const 0x7fffffffffffffff) (i64.const 0)) (i32.const 1))
(assert_return (invoke "i64.no_fold_cmp_u_offset" (i64.const 0xffffffffffffffff) (i64.const 0)) (i32.const 1))

;; Test that wrap(extend_s(x)) is not folded to x

(module
  (func $i64.no_fold_wrap_extend_s (param $x i64) (result i64)
    (i64.extend_i32_s (i32.wrap_i64 (local.get $x))))
  (export "i64.no_fold_wrap_extend_s" $i64.no_fold_wrap_extend_s)
)

(assert_return (invoke "i64.no_fold_wrap_extend_s" (i64.const 0x0010203040506070)) (i64.const 0x0000000040506070))
(assert_return (invoke "i64.no_fold_wrap_extend_s" (i64.const 0x00a0b0c0d0e0f0a0)) (i64.const 0xffffffffd0e0f0a0))

;; Test that wrap(extend_u(x)) is not folded to x

(module
  (func $i64.no_fold_wrap_extend_u (param $x i64) (result i64)
    (i64.extend_i32_u (i32.wrap_i64 (local.get $x))))
  (export "i64.no_fold_wrap_extend_u" $i64.no_fold_wrap_extend_u)
)

(assert_return (invoke "i64.no_fold_wrap_extend_u" (i64.const 0x0010203040506070)) (i64.const 0x0000000040506070))

;; Test that x<<n>>n is not folded to x

(module
  (func $i32.no_fold_shl_shr_s (param $x i32) (result i32)
    (i32.shr_s (i32.shl (local.get $x) (i32.const 1)) (i32.const 1)))
  (export "i32.no_fold_shl_shr_s" $i32.no_fold_shl_shr_s)
  (func $i32.no_fold_shl_shr_u (param $x i32) (result i32)
    (i32.shr_u (i32.shl (local.get $x) (i32.const 1)) (i32.const 1)))
  (export "i32.no_fold_shl_shr_u" $i32.no_fold_shl_shr_u)

  (func $i64.no_fold_shl_shr_s (param $x i64) (result i64)
    (i64.shr_s (i64.shl (local.get $x) (i64.const 1)) (i64.const 1)))
  (export "i64.no_fold_shl_shr_s" $i64.no_fold_shl_shr_s)
  (func $i64.no_fold_shl_shr_u (param $x i64) (result i64)
    (i64.shr_u (i64.shl (local.get $x) (i64.const 1)) (i64.const 1)))
  (export "i64.no_fold_shl_shr_u" $i64.no_fold_shl_shr_u)
)

(assert_return (invoke "i32.no_fold_shl_shr_s" (i32.const 0x80000000)) (i32.const 0))
(assert_return (invoke "i32.no_fold_shl_shr_u" (i32.const 0x80000000)) (i32.const 0))
(assert_return (invoke "i64.no_fold_shl_shr_s" (i64.const 0x8000000000000000)) (i64.const 0))
(assert_return (invoke "i64.no_fold_shl_shr_u" (i64.const 0x8000000000000000)) (i64.const 0))

;; Test that x>>n<<n is not folded to x

(module
  (func $i32.no_fold_shr_s_shl (param $x i32) (result i32)
    (i32.shl (i32.shr_s (local.get $x) (i32.const 1)) (i32.const 1)))
  (export "i32.no_fold_shr_s_shl" $i32.no_fold_shr_s_shl)
  (func $i32.no_fold_shr_u_shl (param $x i32) (result i32)
    (i32.shl (i32.shr_u (local.get $x) (i32.const 1)) (i32.const 1)))
  (export "i32.no_fold_shr_u_shl" $i32.no_fold_shr_u_shl)

  (func $i64.no_fold_shr_s_shl (param $x i64) (result i64)
    (i64.shl (i64.shr_s (local.get $x) (i64.const 1)) (i64.const 1)))
  (export "i64.no_fold_shr_s_shl" $i64.no_fold_shr_s_shl)
  (func $i64.no_fold_shr_u_shl (param $x i64) (result i64)
    (i64.shl (i64.shr_u (local.get $x) (i64.const 1)) (i64.const 1)))
  (export "i64.no_fold_shr_u_shl" $i64.no_fold_shr_u_shl)
)

(assert_return (invoke "i32.no_fold_shr_s_shl" (i32.const 1)) (i32.const 0))
(assert_return (invoke "i32.no_fold_shr_u_shl" (i32.const 1)) (i32.const 0))
(assert_return (invoke "i64.no_fold_shr_s_shl" (i64.const 1)) (i64.const 0))
(assert_return (invoke "i64.no_fold_shr_u_shl" (i64.const 1)) (i64.const 0))

;; Test that x/n*n is not folded to x

(module
  (func $i32.no_fold_div_s_mul (param $x i32) (result i32)
    (i32.mul (i32.div_s (local.get $x) (i32.const 6)) (i32.const 6)))
  (export "i32.no_fold_div_s_mul" $i32.no_fold_div_s_mul)
  (func $i32.no_fold_div_u_mul (param $x i32) (result i32)
    (i32.mul (i32.div_u (local.get $x) (i32.const 6)) (i32.const 6)))
  (export "i32.no_fold_div_u_mul" $i32.no_fold_div_u_mul)

  (func $i64.no_fold_div_s_mul (param $x i64) (result i64)
    (i64.mul (i64.div_s (local.get $x) (i64.const 6)) (i64.const 6)))
  (export "i64.no_fold_div_s_mul" $i64.no_fold_div_s_mul)
  (func $i64.no_fold_div_u_mul (param $x i64) (result i64)
    (i64.mul (i64.div_u (local.get $x) (i64.const 6)) (i64.const 6)))
  (export "i64.no_fold_div_u_mul" $i64.no_fold_div_u_mul)
)

(assert_return (invoke "i32.no_fold_div_s_mul" (i32.const 1)) (i32.const 0))
(assert_return (invoke "i32.no_fold_div_u_mul" (i32.const 1)) (i32.const 0))
(assert_return (invoke "i64.no_fold_div_s_mul" (i64.const 1)) (i64.const 0))
(assert_return (invoke "i64.no_fold_div_u_mul" (i64.const 1)) (i64.const 0))

;; Test that x*n/n is not folded to x

(module
  (func $i32.no_fold_mul_div_s (param $x i32) (result i32)
    (i32.div_s (i32.mul (local.get $x) (i32.const 6)) (i32.const 6)))
  (export "i32.no_fold_mul_div_s" $i32.no_fold_mul_div_s)
  (func $i32.no_fold_mul_div_u (param $x i32) (result i32)
    (i32.div_u (i32.mul (local.get $x) (i32.const 6)) (i32.const 6)))
  (export "i32.no_fold_mul_div_u" $i32.no_fold_mul_div_u)

  (func $i64.no_fold_mul_div_s (param $x i64) (result i64)
    (i64.div_s (i64.mul (local.get $x) (i64.const 6)) (i64.const 6)))
  (export "i64.no_fold_mul_div_s" $i64.no_fold_mul_div_s)
  (func $i64.no_fold_mul_div_u (param $x i64) (result i64)
    (i64.div_u (i64.mul (local.get $x) (i64.const 6)) (i64.const 6)))
  (export "i64.no_fold_mul_div_u" $i64.no_fold_mul_div_u)
)

(assert_return (invoke "i32.no_fold_mul_div_s" (i32.const 0x80000000)) (i32.const 0))
(assert_return (invoke "i32.no_fold_mul_div_u" (i32.const 0x80000000)) (i32.const 0))
(assert_return (invoke "i64.no_fold_mul_div_s" (i64.const 0x8000000000000000)) (i64.const 0))
(assert_return (invoke "i64.no_fold_mul_div_u" (i64.const 0x8000000000000000)) (i64.const 0))

;; Test that x/n where n is a known power of 2 is not folded to shr_s

(module
  (func $i32.no_fold_div_s_2 (param $x i32) (result i32)
    (i32.div_s (local.get $x) (i32.const 2)))
  (export "i32.no_fold_div_s_2" $i32.no_fold_div_s_2)

  (func $i64.no_fold_div_s_2 (param $x i64) (result i64)
    (i64.div_s (local.get $x) (i64.const 2)))
  (export "i64.no_fold_div_s_2" $i64.no_fold_div_s_2)
)

(assert_return (invoke "i32.no_fold_div_s_2" (i32.const -11)) (i32.const -5))
(assert_return (invoke "i64.no_fold_div_s_2" (i64.const -11)) (i64.const -5))

;; Test that x%n where n is a known power of 2 is not folded to and

(module
  (func $i32.no_fold_rem_s_2 (param $x i32) (result i32)
    (i32.rem_s (local.get $x) (i32.const 2)))
  (export "i32.no_fold_rem_s_2" $i32.no_fold_rem_s_2)

  (func $i64.no_fold_rem_s_2 (param $x i64) (result i64)
    (i64.rem_s (local.get $x) (i64.const 2)))
  (export "i64.no_fold_rem_s_2" $i64.no_fold_rem_s_2)
)

(assert_return (invoke "i32.no_fold_rem_s_2" (i32.const -11)) (i32.const -1))
(assert_return (invoke "i64.no_fold_rem_s_2" (i64.const -11)) (i64.const -1))

;; Test that x/3 works

(module
  (func $i32.div_s_3 (param $x i32) (result i32)
    (i32.div_s (local.get $x) (i32.const 3)))
  (export "i32.div_s_3" $i32.div_s_3)
  (func $i32.div_u_3 (param $x i32) (result i32)
    (i32.div_u (local.get $x) (i32.const 3)))
  (export "i32.div_u_3" $i32.div_u_3)

  (func $i64.div_s_3 (param $x i64) (result i64)
    (i64.div_s (local.get $x) (i64.const 3)))
  (export "i64.div_s_3" $i64.div_s_3)
  (func $i64.div_u_3 (param $x i64) (result i64)
    (i64.div_u (local.get $x) (i64.const 3)))
  (export "i64.div_u_3" $i64.div_u_3)
)

(assert_return (invoke "i32.div_s_3" (i32.const 71)) (i32.const 23))
(assert_return (invoke "i32.div_s_3" (i32.const 0x60000000)) (i32.const 0x20000000))
(assert_return (invoke "i32.div_u_3" (i32.const 71)) (i32.const 23))
(assert_return (invoke "i32.div_u_3" (i32.const 0xc0000000)) (i32.const 0x40000000))
(assert_return (invoke "i64.div_s_3" (i64.const 71)) (i64.const 23))
(assert_return (invoke "i64.div_s_3" (i64.const 0x3000000000000000)) (i64.const 0x1000000000000000))
(assert_return (invoke "i64.div_u_3" (i64.const 71)) (i64.const 23))
(assert_return (invoke "i64.div_u_3" (i64.const 0xc000000000000000)) (i64.const 0x4000000000000000))

;; Test that x/5 works

(module
  (func $i32.div_s_5 (param $x i32) (result i32)
    (i32.div_s (local.get $x) (i32.const 5)))
  (export "i32.div_s_5" $i32.div_s_5)
  (func $i32.div_u_5 (param $x i32) (result i32)
    (i32.div_u (local.get $x) (i32.const 5)))
  (export "i32.div_u_5" $i32.div_u_5)

  (func $i64.div_s_5 (param $x i64) (result i64)
    (i64.div_s (local.get $x) (i64.const 5)))
  (export "i64.div_s_5" $i64.div_s_5)
  (func $i64.div_u_5 (param $x i64) (result i64)
    (i64.div_u (local.get $x) (i64.const 5)))
  (export "i64.div_u_5" $i64.div_u_5)
)

(assert_return (invoke "i32.div_s_5" (i32.const 71)) (i32.const 14))
(assert_return (invoke "i32.div_s_5" (i32.const 0x50000000)) (i32.const 0x10000000))
(assert_return (invoke "i32.div_u_5" (i32.const 71)) (i32.const 14))
(assert_return (invoke "i32.div_u_5" (i32.const 0xa0000000)) (i32.const 0x20000000))
(assert_return (invoke "i64.div_s_5" (i64.const 71)) (i64.const 14))
(assert_return (invoke "i64.div_s_5" (i64.const 0x5000000000000000)) (i64.const 0x1000000000000000))
(assert_return (invoke "i64.div_u_5" (i64.const 71)) (i64.const 14))
(assert_return (invoke "i64.div_u_5" (i64.const 0xa000000000000000)) (i64.const 0x2000000000000000))

;; Test that x/7 works

(module
  (func $i32.div_s_7 (param $x i32) (result i32)
    (i32.div_s (local.get $x) (i32.const 7)))
  (export "i32.div_s_7" $i32.div_s_7)
  (func $i32.div_u_7 (param $x i32) (result i32)
    (i32.div_u (local.get $x) (i32.const 7)))
  (export "i32.div_u_7" $i32.div_u_7)

  (func $i64.div_s_7 (param $x i64) (result i64)
    (i64.div_s (local.get $x) (i64.const 7)))
  (export "i64.div_s_7" $i64.div_s_7)
  (func $i64.div_u_7 (param $x i64) (result i64)
    (i64.div_u (local.get $x) (i64.const 7)))
  (export "i64.div_u_7" $i64.div_u_7)
)

(assert_return (invoke "i32.div_s_7" (i32.const 71)) (i32.const 10))
(assert_return (invoke "i32.div_s_7" (i32.const 0x70000000)) (i32.const 0x10000000))
(assert_return (invoke "i32.div_u_7" (i32.const 71)) (i32.const 10))
(assert_return (invoke "i32.div_u_7" (i32.const 0xe0000000)) (i32.const 0x20000000))
(assert_return (invoke "i64.div_s_7" (i64.const 71)) (i64.const 10))
(assert_return (invoke "i64.div_s_7" (i64.const 0x7000000000000000)) (i64.const 0x1000000000000000))
(assert_return (invoke "i64.div_u_7" (i64.const 71)) (i64.const 10))
(assert_return (invoke "i64.div_u_7" (i64.const 0xe000000000000000)) (i64.const 0x2000000000000000))

;; Test that x%3 works

(module
  (func $i32.rem_s_3 (param $x i32) (result i32)
    (i32.rem_s (local.get $x) (i32.const 3)))
  (export "i32.rem_s_3" $i32.rem_s_3)
  (func $i32.rem_u_3 (param $x i32) (result i32)
    (i32.rem_u (local.get $x) (i32.const 3)))
  (export "i32.rem_u_3" $i32.rem_u_3)

  (func $i64.rem_s_3 (param $x i64) (result i64)
    (i64.rem_s (local.get $x) (i64.const 3)))
  (export "i64.rem_s_3" $i64.rem_s_3)
  (func $i64.rem_u_3 (param $x i64) (result i64)
    (i64.rem_u (local.get $x) (i64.const 3)))
  (export "i64.rem_u_3" $i64.rem_u_3)
)

(assert_return (invoke "i32.rem_s_3" (i32.const 71)) (i32.const 2))
(assert_return (invoke "i32.rem_s_3" (i32.const 0x60000000)) (i32.const 0))
(assert_return (invoke "i32.rem_u_3" (i32.const 71)) (i32.const 2))
(assert_return (invoke "i32.rem_u_3" (i32.const 0xc0000000)) (i32.const 0))
(assert_return (invoke "i64.rem_s_3" (i64.const 71)) (i64.const 2))
(assert_return (invoke "i64.rem_s_3" (i64.const 0x3000000000000000)) (i64.const 0))
(assert_return (invoke "i64.rem_u_3" (i64.const 71)) (i64.const 2))
(assert_return (invoke "i64.rem_u_3" (i64.const 0xc000000000000000)) (i64.const 0))

;; Test that x%5 works

(module
  (func $i32.rem_s_5 (param $x i32) (result i32)
    (i32.rem_s (local.get $x) (i32.const 5)))
  (export "i32.rem_s_5" $i32.rem_s_5)
  (func $i32.rem_u_5 (param $x i32) (result i32)
    (i32.rem_u (local.get $x) (i32.const 5)))
  (export "i32.rem_u_5" $i32.rem_u_5)

  (func $i64.rem_s_5 (param $x i64) (result i64)
    (i64.rem_s (local.get $x) (i64.const 5)))
  (export "i64.rem_s_5" $i64.rem_s_5)
  (func $i64.rem_u_5 (param $x i64) (result i64)
    (i64.rem_u (local.get $x) (i64.const 5)))
  (export "i64.rem_u_5" $i64.rem_u_5)
)

(assert_return (invoke "i32.rem_s_5" (i32.const 71)) (i32.const 1))
(assert_return (invoke "i32.rem_s_5" (i32.const 0x50000000)) (i32.const 0))
(assert_return (invoke "i32.rem_u_5" (i32.const 71)) (i32.const 1))
(assert_return (invoke "i32.rem_u_5" (i32.const 0xa0000000)) (i32.const 0))
(assert_return (invoke "i64.rem_s_5" (i64.const 71)) (i64.const 1))
(assert_return (invoke "i64.rem_s_5" (i64.const 0x5000000000000000)) (i64.const 0))
(assert_return (invoke "i64.rem_u_5" (i64.const 71)) (i64.const 1))
(assert_return (invoke "i64.rem_u_5" (i64.const 0xa000000000000000)) (i64.const 0))

;; Test that x%7 works

(module
  (func $i32.rem_s_7 (param $x i32) (result i32)
    (i32.rem_s (local.get $x) (i32.const 7)))
  (export "i32.rem_s_7" $i32.rem_s_7)
  (func $i32.rem_u_7 (param $x i32) (result i32)
    (i32.rem_u (local.get $x) (i32.const 7)))
  (export "i32.rem_u_7" $i32.rem_u_7)

  (func $i64.rem_s_7 (param $x i64) (result i64)
    (i64.rem_s (local.get $x) (i64.const 7)))
  (export "i64.rem_s_7" $i64.rem_s_7)
  (func $i64.rem_u_7 (param $x i64) (result i64)
    (i64.rem_u (local.get $x) (i64.const 7)))
  (export "i64.rem_u_7" $i64.rem_u_7)
)

(assert_return (invoke "i32.rem_s_7" (i32.const 71)) (i32.const 1))
(assert_return (invoke "i32.rem_s_7" (i32.const 0x70000000)) (i32.const 0))
(assert_return (invoke "i32.rem_u_7" (i32.const 71)) (i32.const 1))
(assert_return (invoke "i32.rem_u_7" (i32.const 0xe0000000)) (i32.const 0))
(assert_return (invoke "i64.rem_s_7" (i64.const 71)) (i64.const 1))
(assert_return (invoke "i64.rem_s_7" (i64.const 0x7000000000000000)) (i64.const 0))
(assert_return (invoke "i64.rem_u_7" (i64.const 71)) (i64.const 1))
(assert_return (invoke "i64.rem_u_7" (i64.const 0xe000000000000000)) (i64.const 0))
