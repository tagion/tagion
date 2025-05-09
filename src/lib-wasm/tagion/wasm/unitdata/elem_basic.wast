;; Test the element section

;; Syntax
(module
  (table $t 10 funcref)
  (func $f)
  (func $g)

  ;; Passive
  (elem funcref)
  (;
  (elem funcref (ref.func $f) (item ref.func $f) (item (ref.null func)) (ref.func $g))
  ;)
  (elem func $g)
  
  (elem func $f $f $g $g)
  (;
  (elem $p1 funcref)
  (elem $p2 funcref (ref.func $f) (ref.func $f) (ref.null func) (ref.func $g))
;)
  (elem $p3 func)
  (elem $p4 func $f $f $g $g)

  ;; Active
  (elem (table $t) (i32.const 0) funcref)
  (;
  (elem (table $t) (i32.const 0) funcref (ref.func $f) (ref.null func))
  ;)
  (elem (table $t) (i32.const 0) func)
  (elem (table $t) (i32.const 0) func $f $g)
  (elem (table $t) (offset (i32.const 0)) funcref)
  (elem (table $t) (offset (i32.const 0)) func $f $g)
  (elem (table 0) (i32.const 0) func)
  (elem (table 0x0) (i32.const 0) func $f $f)
  (elem (table 0x000) (offset (i32.const 0)) func)
  (elem (table 0) (offset (i32.const 0)) func $f $f)
  (elem (table $t) (i32.const 0) func)
  (elem (table $t) (i32.const 0) func $f $f)
  (elem (table $t) (offset (i32.const 0)) func)
  (elem (table $t) (offset (i32.const 0)) func $f $f)
  
  (elem (offset (i32.const 0)))
  (;
  (elem (offset (i32.const 0)) funcref (ref.func $f) (ref.null func))
  ;)
  (elem (offset (i32.const 0)) func $f $f)
  
  (elem (offset (i32.const 0)) $f $f)
  (elem (i32.const 0))
  (;
  (elem (i32.const 0) funcref (ref.func $f) (ref.null func))
  ;)
  (elem (i32.const 0) func $f $f)
  (;
  (elem (i32.const 0) $f $f)
  (elem (i32.const 0) funcref (item (ref.func $f)) (item (ref.null func)))
  ;)
  (elem $a1 (table $t) (i32.const 0) funcref)
  ;;(elem $a2 (table $t) (i32.const 0) funcref (ref.func $f) (ref.null func))
  (elem $a3 (table $t) (i32.const 0) func)
  (elem $a4 (table $t) (i32.const 0) func $f $g)
  (elem $a9 (table $t) (offset (i32.const 0)) funcref)
  (elem $a10 (table $t) (offset (i32.const 0)) func $f $g)
  (elem $a11 (table 0) (i32.const 0) func)
  (elem $a12 (table 0x0) (i32.const 0) func $f $f)
  (elem $a13 (table 0x000) (offset (i32.const 0)) func)
  (elem $a14 (table 0) (offset (i32.const 0)) func $f $f)
  (elem $a15 (table $t) (i32.const 0) func)
  (elem $a16 (table $t) (i32.const 0) func $f $f)
  (elem $a17 (table $t) (offset (i32.const 0)) func)
  (elem $a18 (table $t) (offset (i32.const 0)) func $f $f)
  (elem $a19 (offset (i32.const 0)))
  
  ;;(elem $a20 (offset (i32.const 0)) funcref (ref.func $f) (ref.null func))
  (elem $a21 (offset (i32.const 0)) func $f $f)
  (elem $a22 (offset (i32.const 0)) $f $f)
  (elem $a23 (i32.const 0))
  ;;(elem $a24 (i32.const 0) funcref (ref.func $f) (ref.null func))
  (elem $a25 (i32.const 0) func $f $f)
  (elem $a26 (i32.const 0) $f $f)

  ;; Declarative
  (elem declare funcref)
  (;
  (elem declare funcref (ref.func $f) (ref.func $f) (ref.null func) (ref.func $g))
;)
  (elem declare func)

  (elem declare func $f $f $g $g)

  (elem $d1 declare funcref)
;;  (elem $d2 declare funcref (ref.func $f) (ref.func $f) (ref.null func) (ref.func $g))
  (elem $d3 declare func)
  (elem $d4 declare func $f $f $g $g)
    
)


