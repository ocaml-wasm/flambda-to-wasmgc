(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the Q Public License version 1.0.               *)
(*                                                                     *)
(***********************************************************************)

(* $Id: nucleic.ml 7017 2005-08-12 09:22:04Z xleroy $ *)

[@@@ocaml.warning "-27"]

(* Use floating-point arithmetic *)

external ( + ) : float -> float -> float = "%addfloat"

external ( - ) : float -> float -> float = "%subfloat"

external ( * ) : float -> float -> float = "%mulfloat"

external ( / ) : float -> float -> float = "%divfloat"

(* -- MATH UTILITIES --------------------------------------------------------*)

let constant_pi = 3.14159265358979323846

let constant_minus_pi = -3.14159265358979323846

let constant_pi2 = 1.57079632679489661923

let constant_minus_pi2 = -1.57079632679489661923

(* -- POINTS ----------------------------------------------------------------*)

type pt =
  { x : float
  ; y : float
  ; z : float
  }

let pt_sub p1 p2 = { x = p1.x - p2.x; y = p1.y - p2.y; z = p1.z - p2.z }

let pt_dist p1 p2 =
  let dx = p1.x - p2.x and dy = p1.y - p2.y and dz = p1.z - p2.z in
  sqrt ((dx * dx) + (dy * dy) + (dz * dz))

let pt_phi p =
  let b = atan2 p.x p.z in
  atan2 ((cos b * p.z) + (sin b * p.x)) p.y

let pt_theta p = atan2 p.x p.z

(* -- COORDINATE TRANSFORMATIONS --------------------------------------------*)

(*
   The notation for the transformations follows "Paul, R.P. (1981) Robot
   Manipulators.  MIT Press." with the exception that our transformation
   matrices don't have the perspective terms and are the transpose of
   Paul's one.  See also "M\"antyl\"a, M. (1985) An Introduction to
   Solid Modeling, Computer Science Press" Appendix A.

   The components of a transformation matrix are named like this:

    a  b  c
    d  e  f
    g  h  i
   tx ty tz

   The components tx, ty, and tz are the translation vector.
*)

type tfo =
  { a : float
  ; b : float
  ; c : float
  ; d : float
  ; e : float
  ; f : float
  ; g : float
  ; h : float
  ; i : float
  ; tx : float
  ; ty : float
  ; tz : float
  }

let tfo_id =
  { a = 1.0
  ; b = 0.0
  ; c = 0.0
  ; d = 0.0
  ; e = 1.0
  ; f = 0.0
  ; g = 0.0
  ; h = 0.0
  ; i = 1.0
  ; tx = 0.0
  ; ty = 0.0
  ; tz = 0.0
  }

(*
   The function "tfo-apply" multiplies a transformation matrix, tfo, by a
   point vector, p.  The result is a new point.
*)

let tfo_apply t p =
  { x = (p.x * t.a) + (p.y * t.d) + (p.z * t.g) + t.tx
  ; y = (p.x * t.b) + (p.y * t.e) + (p.z * t.h) + t.ty
  ; z = (p.x * t.c) + (p.y * t.f) + (p.z * t.i) + t.tz
  }

(*
   The function "tfo-combine" multiplies two transformation matrices A and B.
   The result is a new matrix which cumulates the transformations described
   by A and B.
*)

let tfo_combine a b =
  (* <HAND_CSE> *)
  (* Hand elimination of common subexpressions.
     Assumes lots of float registers (32 is perfect, 16 still OK).
     Loses on the I386, of course. *)
  let a_a = a.a
  and a_b = a.b
  and a_c = a.c
  and a_d = a.d
  and a_e = a.e
  and a_f = a.f
  and a_g = a.g
  and a_h = a.h
  and a_i = a.i
  and a_tx = a.tx
  and a_ty = a.ty
  and a_tz = a.tz
  and b_a = b.a
  and b_b = b.b
  and b_c = b.c
  and b_d = b.d
  and b_e = b.e
  and b_f = b.f
  and b_g = b.g
  and b_h = b.h
  and b_i = b.i
  and b_tx = b.tx
  and b_ty = b.ty
  and b_tz = b.tz in
  { a = (a_a * b_a) + (a_b * b_d) + (a_c * b_g)
  ; b = (a_a * b_b) + (a_b * b_e) + (a_c * b_h)
  ; c = (a_a * b_c) + (a_b * b_f) + (a_c * b_i)
  ; d = (a_d * b_a) + (a_e * b_d) + (a_f * b_g)
  ; e = (a_d * b_b) + (a_e * b_e) + (a_f * b_h)
  ; f = (a_d * b_c) + (a_e * b_f) + (a_f * b_i)
  ; g = (a_g * b_a) + (a_h * b_d) + (a_i * b_g)
  ; h = (a_g * b_b) + (a_h * b_e) + (a_i * b_h)
  ; i = (a_g * b_c) + (a_h * b_f) + (a_i * b_i)
  ; tx = (a_tx * b_a) + (a_ty * b_d) + (a_tz * b_g) + b_tx
  ; ty = (a_tx * b_b) + (a_ty * b_e) + (a_tz * b_h) + b_ty
  ; tz = (a_tx * b_c) + (a_ty * b_f) + (a_tz * b_i) + b_tz
  }

(* </HAND_CSE> *)
(* Original without CSE *)
(* <NO_CSE> *)
(***
    { a = ((a.a * b.a) + (a.b * b.d) + (a.c * b.g));
      b = ((a.a * b.b) + (a.b * b.e) + (a.c * b.h));
      c = ((a.a * b.c) + (a.b * b.f) + (a.c * b.i));
      d = ((a.d * b.a) + (a.e * b.d) + (a.f * b.g));
      e = ((a.d * b.b) + (a.e * b.e) + (a.f * b.h));
      f = ((a.d * b.c) + (a.e * b.f) + (a.f * b.i));
      g = ((a.g * b.a) + (a.h * b.d) + (a.i * b.g));
      h = ((a.g * b.b) + (a.h * b.e) + (a.i * b.h));
      i = ((a.g * b.c) + (a.h * b.f) + (a.i * b.i));
      tx = ((a.tx * b.a) + (a.ty * b.d) + (a.tz * b.g) + b.tx);
      ty = ((a.tx * b.b) + (a.ty * b.e) + (a.tz * b.h) + b.ty);
      tz = ((a.tx * b.c) + (a.ty * b.f) + (a.tz * b.i) + b.tz)
    }
  ***)
(* </NO_CSE> *)

(*
   The function "tfo-inv-ortho" computes the inverse of a homogeneous
   transformation matrix.
*)

let tfo_inv_ortho t =
  { a = t.a
  ; b = t.d
  ; c = t.g
  ; d = t.b
  ; e = t.e
  ; f = t.h
  ; g = t.c
  ; h = t.f
  ; i = t.i
  ; tx = -.((t.a * t.tx) + (t.b * t.ty) + (t.c * t.tz))
  ; ty = -.((t.d * t.tx) + (t.e * t.ty) + (t.f * t.tz))
  ; tz = -.((t.g * t.tx) + (t.h * t.ty) + (t.i * t.tz))
  }

(*
   Given three points p1, p2, and p3, the function "tfo-align" computes
   a transformation matrix such that point p1 gets mapped to (0,0,0), p2 gets
   mapped to the Y axis and p3 gets mapped to the YZ plane.
*)

let tfo_align p1 p2 p3 =
  let x31 = p3.x - p1.x in
  let y31 = p3.y - p1.y in
  let z31 = p3.z - p1.z in
  let rotpy = pt_sub p2 p1 in
  let phi = pt_phi rotpy in
  let theta = pt_theta rotpy in
  let sinp = sin phi in
  let sint = sin theta in
  let cosp = cos phi in
  let cost = cos theta in
  let sinpsint = sinp * sint in
  let sinpcost = sinp * cost in
  let cospsint = cosp * sint in
  let cospcost = cosp * cost in
  let rotpz =
    { x = (cost * x31) - (sint * z31)
    ; y = (sinpsint * x31) + (cosp * y31) + (sinpcost * z31)
    ; z = (cospsint * x31) + -.(sinp * y31) + (cospcost * z31)
    }
  in
  let rho = pt_theta rotpz in
  let cosr = cos rho in
  let sinr = sin rho in
  let x = -.(p1.x * cost) + (p1.z * sint) in
  let y = -.(p1.x * sinpsint) - (p1.y * cosp) - (p1.z * sinpcost) in
  let z = -.(p1.x * cospsint) + (p1.y * sinp) - (p1.z * cospcost) in
  { a = (cost * cosr) - (cospsint * sinr)
  ; b = sinpsint
  ; c = (cost * sinr) + (cospsint * cosr)
  ; d = sinp * sinr
  ; e = cosp
  ; f = -.(sinp * cosr)
  ; g = -.(sint * cosr) - (cospcost * sinr)
  ; h = sinpcost
  ; i = -.(sint * sinr) + (cospcost * cosr)
  ; tx = (x * cosr) - (z * sinr)
  ; ty = y
  ; tz = (x * sinr) + (z * cosr)
  }

(* -- NUCLEIC ACID CONFORMATIONS DATA BASE ----------------------------------*)

(*
   Numbering of atoms follows the paper:

   IUPAC-IUB Joint Commission on Biochemical Nomenclature (JCBN)
   (1983) Abbreviations and Symbols for the Description of
   Conformations of Polynucleotide Chains.  Eur. J. Biochem 131,
   9-15.
*)

(* Define remaining atoms for each nucleotide type. *)

type nuc_specific =
  | A of pt * pt * pt * pt * pt * pt * pt * pt
  | C of pt * pt * pt * pt * pt * pt
  | G of pt * pt * pt * pt * pt * pt * pt * pt * pt
  | U of pt * pt * pt * pt * pt

(*
   A n6 n7 n9 c8 h2 h61 h62 h8
   C n4 o2 h41 h42 h5 h6
   G n2 n7 n9 c8 o6 h1 h21 h22 h8
   U o2 o4 h3 h5 h6
*)

(* Define part common to all 4 nucleotide types. *)

type nuc =
  | N of
      tfo
      * tfo
      * tfo
      * tfo
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * pt
      * nuc_specific

(*
    dgf_base_tfo  ; defines the standard position for wc and wc_dumas
    p_o3'_275_tfo ; defines the standard position for the connect function
    p_o3'_180_tfo
    p_o3'_60_tfo
    p o1p o2p o5' c5' h5' h5'' c4' h4' o4' c1' h1' c2' h2'' o2' h2' c3'
    h3' o3' n1 n3 c2 c4 c5 c6
*)

let is_A = function
  | N
      ( dgf_base_tfo
      , p_o3'_275_tfo
      , p_o3'_180_tfo
      , p_o3'_60_tfo
      , p
      , o1p
      , o2p
      , o5'
      , c5'
      , h5'
      , h5''
      , c4'
      , h4'
      , o4'
      , c1'
      , h1'
      , c2'
      , h2''
      , o2'
      , h2'
      , c3'
      , h3'
      , o3'
      , n1
      , n3
      , c2
      , c4
      , c5
      , c6
      , A (_, _, _, _, _, _, _, _) ) -> true
  | _ -> false

let is_C = function
  | N
      ( dgf_base_tfo
      , p_o3'_275_tfo
      , p_o3'_180_tfo
      , p_o3'_60_tfo
      , p
      , o1p
      , o2p
      , o5'
      , c5'
      , h5'
      , h5''
      , c4'
      , h4'
      , o4'
      , c1'
      , h1'
      , c2'
      , h2''
      , o2'
      , h2'
      , c3'
      , h3'
      , o3'
      , n1
      , n3
      , c2
      , c4
      , c5
      , c6
      , C (_, _, _, _, _, _) ) -> true
  | _ -> false

let is_G = function
  | N
      ( dgf_base_tfo
      , p_o3'_275_tfo
      , p_o3'_180_tfo
      , p_o3'_60_tfo
      , p
      , o1p
      , o2p
      , o5'
      , c5'
      , h5'
      , h5''
      , c4'
      , h4'
      , o4'
      , c1'
      , h1'
      , c2'
      , h2''
      , o2'
      , h2'
      , c3'
      , h3'
      , o3'
      , n1
      , n3
      , c2
      , c4
      , c5
      , c6
      , G (_, _, _, _, _, _, _, _, _) ) -> true
  | _ -> false

let nuc_C1'
    (N
        ( dgf_base_tfo
        , p_o3'_275_tfo
        , p_o3'_180_tfo
        , p_o3'_60_tfo
        , p
        , o1p
        , o2p
        , o5'
        , c5'
        , h5'
        , h5''
        , c4'
        , h4'
        , o4'
        , c1'
        , h1'
        , c2'
        , h2''
        , o2'
        , h2'
        , c3'
        , h3'
        , o3'
        , n1
        , n3
        , c2
        , c4
        , c5
        , c6
        , _ )) =
  c1'

let nuc_C2
    (N
        ( dgf_base_tfo
        , p_o3'_275_tfo
        , p_o3'_180_tfo
        , p_o3'_60_tfo
        , p
        , o1p
        , o2p
        , o5'
        , c5'
        , h5'
        , h5''
        , c4'
        , h4'
        , o4'
        , c1'
        , h1'
        , c2'
        , h2''
        , o2'
        , h2'
        , c3'
        , h3'
        , o3'
        , n1
        , n3
        , c2
        , c4
        , c5
        , c6
        , _ )) =
  c2

let nuc_C3'
    (N
        ( dgf_base_tfo
        , p_o3'_275_tfo
        , p_o3'_180_tfo
        , p_o3'_60_tfo
        , p
        , o1p
        , o2p
        , o5'
        , c5'
        , h5'
        , h5''
        , c4'
        , h4'
        , o4'
        , c1'
        , h1'
        , c2'
        , h2''
        , o2'
        , h2'
        , c3'
        , h3'
        , o3'
        , n1
        , n3
        , c2
        , c4
        , c5
        , c6
        , _ )) =
  c3'

let nuc_C4
    (N
        ( dgf_base_tfo
        , p_o3'_275_tfo
        , p_o3'_180_tfo
        , p_o3'_60_tfo
        , p
        , o1p
        , o2p
        , o5'
        , c5'
        , h5'
        , h5''
        , c4'
        , h4'
        , o4'
        , c1'
        , h1'
        , c2'
        , h2''
        , o2'
        , h2'
        , c3'
        , h3'
        , o3'
        , n1
        , n3
        , c2
        , c4
        , c5
        , c6
        , _ )) =
  c4

let nuc_C4'
    (N
        ( dgf_base_tfo
        , p_o3'_275_tfo
        , p_o3'_180_tfo
        , p_o3'_60_tfo
        , p
        , o1p
        , o2p
        , o5'
        , c5'
        , h5'
        , h5''
        , c4'
        , h4'
        , o4'
        , c1'
        , h1'
        , c2'
        , h2''
        , o2'
        , h2'
        , c3'
        , h3'
        , o3'
        , n1
        , n3
        , c2
        , c4
        , c5
        , c6
        , _ )) =
  c4'

let nuc_N1
    (N
        ( dgf_base_tfo
        , p_o3'_275_tfo
        , p_o3'_180_tfo
        , p_o3'_60_tfo
        , p
        , o1p
        , o2p
        , o5'
        , c5'
        , h5'
        , h5''
        , c4'
        , h4'
        , o4'
        , c1'
        , h1'
        , c2'
        , h2''
        , o2'
        , h2'
        , c3'
        , h3'
        , o3'
        , n1
        , n3
        , c2
        , c4
        , c5
        , c6
        , _ )) =
  n1

let nuc_O3'
    (N
        ( dgf_base_tfo
        , p_o3'_275_tfo
        , p_o3'_180_tfo
        , p_o3'_60_tfo
        , p
        , o1p
        , o2p
        , o5'
        , c5'
        , h5'
        , h5''
        , c4'
        , h4'
        , o4'
        , c1'
        , h1'
        , c2'
        , h2''
        , o2'
        , h2'
        , c3'
        , h3'
        , o3'
        , n1
        , n3
        , c2
        , c4
        , c5
        , c6
        , _ )) =
  o3'

let nuc_P
    (N
        ( dgf_base_tfo
        , p_o3'_275_tfo
        , p_o3'_180_tfo
        , p_o3'_60_tfo
        , p
        , o1p
        , o2p
        , o5'
        , c5'
        , h5'
        , h5''
        , c4'
        , h4'
        , o4'
        , c1'
        , h1'
        , c2'
        , h2''
        , o2'
        , h2'
        , c3'
        , h3'
        , o3'
        , n1
        , n3
        , c2
        , c4
        , c5
        , c6
        , _ )) =
  p

let nuc_dgf_base_tfo
    (N
        ( dgf_base_tfo
        , p_o3'_275_tfo
        , p_o3'_180_tfo
        , p_o3'_60_tfo
        , p
        , o1p
        , o2p
        , o5'
        , c5'
        , h5'
        , h5''
        , c4'
        , h4'
        , o4'
        , c1'
        , h1'
        , c2'
        , h2''
        , o2'
        , h2'
        , c3'
        , h3'
        , o3'
        , n1
        , n3
        , c2
        , c4
        , c5
        , c6
        , _ )) =
  dgf_base_tfo

let nuc_p_o3'_180_tfo
    (N
        ( dgf_base_tfo
        , p_o3'_275_tfo
        , p_o3'_180_tfo
        , p_o3'_60_tfo
        , p
        , o1p
        , o2p
        , o5'
        , c5'
        , h5'
        , h5''
        , c4'
        , h4'
        , o4'
        , c1'
        , h1'
        , c2'
        , h2''
        , o2'
        , h2'
        , c3'
        , h3'
        , o3'
        , n1
        , n3
        , c2
        , c4
        , c5
        , c6
        , _ )) =
  p_o3'_180_tfo

let nuc_p_o3'_275_tfo
    (N
        ( dgf_base_tfo
        , p_o3'_275_tfo
        , p_o3'_180_tfo
        , p_o3'_60_tfo
        , p
        , o1p
        , o2p
        , o5'
        , c5'
        , h5'
        , h5''
        , c4'
        , h4'
        , o4'
        , c1'
        , h1'
        , c2'
        , h2''
        , o2'
        , h2'
        , c3'
        , h3'
        , o3'
        , n1
        , n3
        , c2
        , c4
        , c5
        , c6
        , _ )) =
  p_o3'_275_tfo

let nuc_p_o3'_60_tfo
    (N
        ( dgf_base_tfo
        , p_o3'_275_tfo
        , p_o3'_180_tfo
        , p_o3'_60_tfo
        , p
        , o1p
        , o2p
        , o5'
        , c5'
        , h5'
        , h5''
        , c4'
        , h4'
        , o4'
        , c1'
        , h1'
        , c2'
        , h2''
        , o2'
        , h2'
        , c3'
        , h3'
        , o3'
        , n1
        , n3
        , c2
        , c4
        , c5
        , c6
        , _ )) =
  p_o3'_60_tfo

let rA_N9 = function
  | N
      ( dgf_base_tfo
      , p_o3'_275_tfo
      , p_o3'_180_tfo
      , p_o3'_60_tfo
      , p
      , o1p
      , o2p
      , o5'
      , c5'
      , h5'
      , h5''
      , c4'
      , h4'
      , o4'
      , c1'
      , h1'
      , c2'
      , h2''
      , o2'
      , h2'
      , c3'
      , h3'
      , o3'
      , n1
      , n3
      , c2
      , c4
      , c5
      , c6
      , A (n6, n7, n9, c8, h2, h61, h62, h8) ) -> n9
  | _ -> assert false

let rG_N9 = function
  | N
      ( dgf_base_tfo
      , p_o3'_275_tfo
      , p_o3'_180_tfo
      , p_o3'_60_tfo
      , p
      , o1p
      , o2p
      , o5'
      , c5'
      , h5'
      , h5''
      , c4'
      , h4'
      , o4'
      , c1'
      , h1'
      , c2'
      , h2''
      , o2'
      , h2'
      , c3'
      , h3'
      , o3'
      , n1
      , n3
      , c2
      , c4
      , c5
      , c6
      , G (n2, n7, n9, c8, o6, h1, h21, h22, h8) ) -> n9
  | _ -> assert false

(* Database of nucleotide conformations: *)

let rA =
  N
    ( { a = -0.0018
      ; b = -0.8207
      ; c = 0.5714
      ; (* dgf_base_tfo *)
        d = 0.2679
      ; e = -0.5509
      ; f = -0.7904
      ; g = 0.9634
      ; h = 0.1517
      ; i = 0.2209
      ; tx = 0.0073
      ; ty = 8.4030
      ; tz = 0.6232
    }
    , { a = -0.8143
      ; b = -0.5091
      ; c = -0.2788
      ; (* P_O3'_275_tfo *)
        d = -0.0433
      ; e = -0.4257
      ; f = 0.9038
      ; g = -0.5788
      ; h = 0.7480
      ; i = 0.3246
      ; tx = 1.5227
      ; ty = 6.9114
      ; tz = -7.0765
    }
    , { a = 0.3822
      ; b = -0.7477
      ; c = 0.5430
      ; (* P_O3'_180_tfo *)
        d = 0.4552
      ; e = 0.6637
      ; f = 0.5935
      ; g = -0.8042
      ; h = 0.0203
      ; i = 0.5941
      ; tx = -6.9472
      ; ty = -4.1186
      ; tz = -5.9108
    }
    , { a = 0.5640
      ; b = 0.8007
      ; c = -0.2022
      ; (* P_O3'_60_tfo *)
        d = -0.8247
      ; e = 0.5587
      ; f = -0.0878
      ; g = 0.0426
      ; h = 0.2162
      ; i = 0.9754
      ; tx = 6.2694
      ; ty = -7.0540
      ; tz = 3.3316
    }
    , { x = 2.8930; y = 8.5380; z = -3.3280 }
      , (* P    *)
      { x = 1.6980; y = 7.6960; z = -3.5570 }
      , (* O1P  *)
      { x = 3.2260; y = 9.5010; z = -4.4020 }
      , (* O2P  *)
      { x = 4.1590; y = 7.6040; z = -3.0340 }
      , (* O5'  *)
      { x = 5.4550; y = 8.2120; z = -2.8810 }
      , (* C5'  *)
      { x = 5.4546; y = 8.8508; z = -1.9978 }
      , (* H5'  *)
      { x = 5.7588; y = 8.6625; z = -3.8259 }
      , (* H5'' *)
      { x = 6.4970; y = 7.1480; z = -2.5980 }
      , (* C4'  *)
      { x = 7.4896; y = 7.5919; z = -2.5214 }
      , (* H4'  *)
      { x = 6.1630; y = 6.4860; z = -1.3440 }
      , (* O4'  *)
      { x = 6.5400; y = 5.1200; z = -1.4190 }
      , (* C1'  *)
      { x = 7.2763; y = 4.9681; z = -0.6297 }
      , (* H1'  *)
      { x = 7.1940; y = 4.8830; z = -2.7770 }
      , (* C2'  *)
      { x = 6.8667; y = 3.9183; z = -3.1647 }
      , (* H2'' *)
      { x = 8.5860; y = 5.0910; z = -2.6140 }
      , (* O2'  *)
      { x = 8.9510; y = 4.7626; z = -1.7890 }
      , (* H2'  *)
      { x = 6.5720; y = 6.0040; z = -3.6090 }
      , (* C3'  *)
      { x = 5.5636; y = 5.7066; z = -3.8966 }
      , (* H3'  *)
      { x = 7.3801; y = 6.3562; z = -4.7350 }
      , (* O3'  *)
      { x = 4.7150; y = 0.4910; z = -0.1360 }
      , (* N1   *)
      { x = 6.3490; y = 2.1730; z = -0.6020 }
      , (* N3   *)
      { x = 5.9530; y = 0.9650; z = -0.2670 }
      , (* C2   *)
      { x = 5.2900; y = 2.9790; z = -0.8260 }
      , (* C4   *)
      { x = 3.9720; y = 2.6390; z = -0.7330 }
      , (* C5   *)
      { x = 3.6770; y = 1.3160; z = -0.3660 }
      , (* C6 *)
      A
        ( { x = 2.4280; y = 0.8450; z = -0.2360 }
          , (* N6   *)
          { x = 3.1660; y = 3.7290; z = -1.0360 }
          , (* N7   *)
          { x = 5.3170; y = 4.2990; z = -1.1930 }
          , (* N9   *)
          { x = 4.0100; y = 4.6780; z = -1.2990 }
          , (* C8   *)
          { x = 6.6890; y = 0.1903; z = -0.0518 }
          , (* H2   *)
          { x = 1.6470; y = 1.4460; z = -0.4040 }
          , (* H61  *)
          { x = 2.2780; y = -0.1080; z = -0.0280 }
          , (* H62  *)
          { x = 3.4421; y = 5.5744; z = -1.5482 } ) )

(* H8   *)

let rA01 =
  N
    ( { a = -0.0043
      ; b = -0.8175
      ; c = 0.5759
      ; (* dgf_base_tfo *)
        d = 0.2617
      ; e = -0.5567
      ; f = -0.7884
      ; g = 0.9651
      ; h = 0.1473
      ; i = 0.2164
      ; tx = 0.0359
      ; ty = 8.3929
      ; tz = 0.5532
    }
    , { a = -0.8143
      ; b = -0.5091
      ; c = -0.2788
      ; (* P_O3'_275_tfo *)
        d = -0.0433
      ; e = -0.4257
      ; f = 0.9038
      ; g = -0.5788
      ; h = 0.7480
      ; i = 0.3246
      ; tx = 1.5227
      ; ty = 6.9114
      ; tz = -7.0765
    }
    , { a = 0.3822
      ; b = -0.7477
      ; c = 0.5430
      ; (* P_O3'_180_tfo *)
        d = 0.4552
      ; e = 0.6637
      ; f = 0.5935
      ; g = -0.8042
      ; h = 0.0203
      ; i = 0.5941
      ; tx = -6.9472
      ; ty = -4.1186
      ; tz = -5.9108
    }
    , { a = 0.5640
      ; b = 0.8007
      ; c = -0.2022
      ; (* P_O3'_60_tfo *)
        d = -0.8247
      ; e = 0.5587
      ; f = -0.0878
      ; g = 0.0426
      ; h = 0.2162
      ; i = 0.9754
      ; tx = 6.2694
      ; ty = -7.0540
      ; tz = 3.3316
    }
    , { x = 2.8930; y = 8.5380; z = -3.3280 }
      , (* P    *)
      { x = 1.6980; y = 7.6960; z = -3.5570 }
      , (* O1P  *)
      { x = 3.2260; y = 9.5010; z = -4.4020 }
      , (* O2P  *)
      { x = 4.1590; y = 7.6040; z = -3.0340 }
      , (* O5'  *)
      { x = 5.4352; y = 8.2183; z = -2.7757 }
      , (* C5'  *)
      { x = 5.3830; y = 8.7883; z = -1.8481 }
      , (* H5'  *)
      { x = 5.7729; y = 8.7436; z = -3.6691 }
      , (* H5'' *)
      { x = 6.4830; y = 7.1518; z = -2.5252 }
      , (* C4'  *)
      { x = 7.4749; y = 7.5972; z = -2.4482 }
      , (* H4'  *)
      { x = 6.1626; y = 6.4620; z = -1.2827 }
      , (* O4'  *)
      { x = 6.5431; y = 5.0992; z = -1.3905 }
      , (* C1'  *)
      { x = 7.2871; y = 4.9328; z = -0.6114 }
      , (* H1'  *)
      { x = 7.1852; y = 4.8935; z = -2.7592 }
      , (* C2'  *)
      { x = 6.8573; y = 3.9363; z = -3.1645 }
      , (* H2'' *)
      { x = 8.5780; y = 5.1025; z = -2.6046 }
      , (* O2'  *)
      { x = 8.9516; y = 4.7577; z = -1.7902 }
      , (* H2'  *)
      { x = 6.5522; y = 6.0300; z = -3.5612 }
      , (* C3'  *)
      { x = 5.5420; y = 5.7356; z = -3.8459 }
      , (* H3'  *)
      { x = 7.3487; y = 6.4089; z = -4.6867 }
      , (* O3'  *)
      { x = 4.7442; y = 0.4514; z = -0.1390 }
      , (* N1   *)
      { x = 6.3687; y = 2.1459; z = -0.5926 }
      , (* N3   *)
      { x = 5.9795; y = 0.9335; z = -0.2657 }
      , (* C2   *)
      { x = 5.3052; y = 2.9471; z = -0.8125 }
      , (* C4   *)
      { x = 3.9891; y = 2.5987; z = -0.7230 }
      , (* C5   *)
      { x = 3.7016; y = 1.2717; z = -0.3647 }
      , (* C6 *)
      A
        ( { x = 2.4553; y = 0.7925; z = -0.2390 }
          , (* N6   *)
          { x = 3.1770; y = 3.6859; z = -1.0198 }
          , (* N7   *)
          { x = 5.3247; y = 4.2695; z = -1.1710 }
          , (* N9   *)
          { x = 4.0156; y = 4.6415; z = -1.2759 }
          , (* C8   *)
          { x = 6.7198; y = 0.1618; z = -0.0547 }
          , (* H2   *)
          { x = 1.6709; y = 1.3900; z = -0.4039 }
          , (* H61  *)
          { x = 2.3107; y = -0.1627; z = -0.0373 }
          , (* H62  *)
          { x = 3.4426; y = 5.5361; z = -1.5199 } ) )

(* H8   *)

let rA02 =
  N
    ( { a = 0.5566
      ; b = 0.0449
      ; c = 0.8296
      ; (* dgf_base_tfo *)
        d = 0.5125
      ; e = 0.7673
      ; f = -0.3854
      ; g = -0.6538
      ; h = 0.6397
      ; i = 0.4041
      ; tx = -9.1161
      ; ty = -3.7679
      ; tz = -2.9968
    }
    , { a = -0.8143
      ; b = -0.5091
      ; c = -0.2788
      ; (* P_O3'_275_tfo *)
        d = -0.0433
      ; e = -0.4257
      ; f = 0.9038
      ; g = -0.5788
      ; h = 0.7480
      ; i = 0.3246
      ; tx = 1.5227
      ; ty = 6.9114
      ; tz = -7.0765
    }
    , { a = 0.3822
      ; b = -0.7477
      ; c = 0.5430
      ; (* P_O3'_180_tfo *)
        d = 0.4552
      ; e = 0.6637
      ; f = 0.5935
      ; g = -0.8042
      ; h = 0.0203
      ; i = 0.5941
      ; tx = -6.9472
      ; ty = -4.1186
      ; tz = -5.9108
    }
    , { a = 0.5640
      ; b = 0.8007
      ; c = -0.2022
      ; (* P_O3'_60_tfo *)
        d = -0.8247
      ; e = 0.5587
      ; f = -0.0878
      ; g = 0.0426
      ; h = 0.2162
      ; i = 0.9754
      ; tx = 6.2694
      ; ty = -7.0540
      ; tz = 3.3316
    }
    , { x = 2.8930; y = 8.5380; z = -3.3280 }
      , (* P    *)
      { x = 1.6980; y = 7.6960; z = -3.5570 }
      , (* O1P  *)
      { x = 3.2260; y = 9.5010; z = -4.4020 }
      , (* O2P  *)
      { x = 4.1590; y = 7.6040; z = -3.0340 }
      , (* O5'  *)
      { x = 4.5778; y = 6.6594; z = -4.0364 }
      , (* C5'  *)
      { x = 4.9220; y = 7.1963; z = -4.9204 }
      , (* H5'  *)
      { x = 3.7996; y = 5.9091; z = -4.1764 }
      , (* H5'' *)
      { x = 5.7873; y = 5.8869; z = -3.5482 }
      , (* C4'  *)
      { x = 6.0405; y = 5.0875; z = -4.2446 }
      , (* H4'  *)
      { x = 6.9135; y = 6.8036; z = -3.4310 }
      , (* O4'  *)
      { x = 7.7293; y = 6.4084; z = -2.3392 }
      , (* C1'  *)
      { x = 8.7078; y = 6.1815; z = -2.7624 }
      , (* H1'  *)
      { x = 7.1305; y = 5.1418; z = -1.7347 }
      , (* C2'  *)
      { x = 7.2040; y = 5.1982; z = -0.6486 }
      , (* H2'' *)
      { x = 7.7417; y = 4.0392; z = -2.3813 }
      , (* O2'  *)
      { x = 8.6785; y = 4.1443; z = -2.5630 }
      , (* H2'  *)
      { x = 5.6666; y = 5.2728; z = -2.1536 }
      , (* C3'  *)
      { x = 5.1747; y = 5.9805; z = -1.4863 }
      , (* H3'  *)
      { x = 4.9997; y = 4.0086; z = -2.1973 }
      , (* O3'  *)
      { x = 10.3245; y = 8.5459; z = 1.5467 }
      , (* N1   *)
      { x = 9.8051; y = 6.9432; z = -0.1497 }
      , (* N3   *)
      { x = 10.5175; y = 7.4328; z = 0.8408 }
      , (* C2   *)
      { x = 8.7523; y = 7.7422; z = -0.4228 }
      , (* C4   *)
      { x = 8.4257; y = 8.9060; z = 0.2099 }
      , (* C5   *)
      { x = 9.2665; y = 9.3242; z = 1.2540 }
      , (* C6 *)
      A
        ( { x = 9.0664; y = 10.4462; z = 1.9610 }
          , (* N6   *)
          { x = 7.2750; y = 9.4537; z = -0.3428 }
          , (* N7   *)
          { x = 7.7962; y = 7.5519; z = -1.3859 }
          , (* N9   *)
          { x = 6.9479; y = 8.6157; z = -1.2771 }
          , (* C8   *)
          { x = 11.4063; y = 6.9047; z = 1.1859 }
          , (* H2   *)
          { x = 8.2845; y = 11.0341; z = 1.7552 }
          , (* H61  *)
          { x = 9.6584; y = 10.6647; z = 2.7198 }
          , (* H62  *)
          { x = 6.0430; y = 8.9853; z = -1.7594 } ) )

(* H8   *)

let rA03 =
  N
    ( { a = -0.5021
      ; b = 0.0731
      ; c = 0.8617
      ; (* dgf_base_tfo *)
        d = -0.8112
      ; e = 0.3054
      ; f = -0.4986
      ; g = -0.2996
      ; h = -0.9494
      ; i = -0.0940
      ; tx = 6.4273
      ; ty = -5.1944
      ; tz = -3.7807
    }
    , { a = -0.8143
      ; b = -0.5091
      ; c = -0.2788
      ; (* P_O3'_275_tfo *)
        d = -0.0433
      ; e = -0.4257
      ; f = 0.9038
      ; g = -0.5788
      ; h = 0.7480
      ; i = 0.3246
      ; tx = 1.5227
      ; ty = 6.9114
      ; tz = -7.0765
    }
    , { a = 0.3822
      ; b = -0.7477
      ; c = 0.5430
      ; (* P_O3'_180_tfo *)
        d = 0.4552
      ; e = 0.6637
      ; f = 0.5935
      ; g = -0.8042
      ; h = 0.0203
      ; i = 0.5941
      ; tx = -6.9472
      ; ty = -4.1186
      ; tz = -5.9108
    }
    , { a = 0.5640
      ; b = 0.8007
      ; c = -0.2022
      ; (* P_O3'_60_tfo *)
        d = -0.8247
      ; e = 0.5587
      ; f = -0.0878
      ; g = 0.0426
      ; h = 0.2162
      ; i = 0.9754
      ; tx = 6.2694
      ; ty = -7.0540
      ; tz = 3.3316
    }
    , { x = 2.8930; y = 8.5380; z = -3.3280 }
      , (* P    *)
      { x = 1.6980; y = 7.6960; z = -3.5570 }
      , (* O1P  *)
      { x = 3.2260; y = 9.5010; z = -4.4020 }
      , (* O2P  *)
      { x = 4.1590; y = 7.6040; z = -3.0340 }
      , (* O5'  *)
      { x = 4.1214; y = 6.7116; z = -1.9049 }
      , (* C5'  *)
      { x = 3.3465; y = 5.9610; z = -2.0607 }
      , (* H5'  *)
      { x = 4.0789; y = 7.2928; z = -0.9837 }
      , (* H5'' *)
      { x = 5.4170; y = 5.9293; z = -1.8186 }
      , (* C4'  *)
      { x = 5.4506; y = 5.3400; z = -0.9023 }
      , (* H4'  *)
      { x = 5.5067; y = 5.0417; z = -2.9703 }
      , (* O4'  *)
      { x = 6.8650; y = 4.9152; z = -3.3612 }
      , (* C1'  *)
      { x = 7.1090; y = 3.8577; z = -3.2603 }
      , (* H1'  *)
      { x = 7.7152; y = 5.7282; z = -2.3894 }
      , (* C2'  *)
      { x = 8.5029; y = 6.2356; z = -2.9463 }
      , (* H2'' *)
      { x = 8.1036; y = 4.8568; z = -1.3419 }
      , (* O2'  *)
      { x = 8.3270; y = 3.9651; z = -1.6184 }
      , (* H2'  *)
      { x = 6.7003; y = 6.7565; z = -1.8911 }
      , (* C3'  *)
      { x = 6.5898; y = 7.5329; z = -2.6482 }
      , (* H3'  *)
      { x = 7.0505; y = 7.2878; z = -0.6105 }
      , (* O3'  *)
      { x = 9.6740; y = 4.7656; z = -7.6614 }
      , (* N1   *)
      { x = 9.0739; y = 4.3013; z = -5.3941 }
      , (* N3   *)
      { x = 9.8416; y = 4.2192; z = -6.4581 }
      , (* C2   *)
      { x = 7.9885; y = 5.0632; z = -5.6446 }
      , (* C4   *)
      { x = 7.6822; y = 5.6856; z = -6.8194 }
      , (* C5   *)
      { x = 8.5831; y = 5.5215; z = -7.8840 }
      , (* C6 *)
      A
        ( { x = 8.4084; y = 6.0747; z = -9.0933 }
          , (* N6   *)
          { x = 6.4857; y = 6.3816; z = -6.7035 }
          , (* N7   *)
          { x = 6.9740; y = 5.3703; z = -4.7760 }
          , (* N9   *)
          { x = 6.1133; y = 6.1613; z = -5.4808 }
          , (* C8   *)
          { x = 10.7627; y = 3.6375; z = -6.4220 }
          , (* H2   *)
          { x = 7.6031; y = 6.6390; z = -9.2733 }
          , (* H61  *)
          { x = 9.1004; y = 5.9708; z = -9.7893 }
          , (* H62  *)
          { x = 5.1705; y = 6.6830; z = -5.3167 } ) )

(* H8   *)

let rA04 =
  N
    ( { a = -0.5426
      ; b = -0.8175
      ; c = 0.1929
      ; (* dgf_base_tfo *)
        d = 0.8304
      ; e = -0.5567
      ; f = -0.0237
      ; g = 0.1267
      ; h = 0.1473
      ; i = 0.9809
      ; tx = -0.5075
      ; ty = 8.3929
      ; tz = 0.2229
    }
    , { a = -0.8143
      ; b = -0.5091
      ; c = -0.2788
      ; (* P_O3'_275_tfo *)
        d = -0.0433
      ; e = -0.4257
      ; f = 0.9038
      ; g = -0.5788
      ; h = 0.7480
      ; i = 0.3246
      ; tx = 1.5227
      ; ty = 6.9114
      ; tz = -7.0765
    }
    , { a = 0.3822
      ; b = -0.7477
      ; c = 0.5430
      ; (* P_O3'_180_tfo *)
        d = 0.4552
      ; e = 0.6637
      ; f = 0.5935
      ; g = -0.8042
      ; h = 0.0203
      ; i = 0.5941
      ; tx = -6.9472
      ; ty = -4.1186
      ; tz = -5.9108
    }
    , { a = 0.5640
      ; b = 0.8007
      ; c = -0.2022
      ; (* P_O3'_60_tfo *)
        d = -0.8247
      ; e = 0.5587
      ; f = -0.0878
      ; g = 0.0426
      ; h = 0.2162
      ; i = 0.9754
      ; tx = 6.2694
      ; ty = -7.0540
      ; tz = 3.3316
    }
    , { x = 2.8930; y = 8.5380; z = -3.3280 }
      , (* P    *)
      { x = 1.6980; y = 7.6960; z = -3.5570 }
      , (* O1P  *)
      { x = 3.2260; y = 9.5010; z = -4.4020 }
      , (* O2P  *)
      { x = 4.1590; y = 7.6040; z = -3.0340 }
      , (* O5'  *)
      { x = 5.4352; y = 8.2183; z = -2.7757 }
      , (* C5'  *)
      { x = 5.3830; y = 8.7883; z = -1.8481 }
      , (* H5'  *)
      { x = 5.7729; y = 8.7436; z = -3.6691 }
      , (* H5'' *)
      { x = 6.4830; y = 7.1518; z = -2.5252 }
      , (* C4'  *)
      { x = 7.4749; y = 7.5972; z = -2.4482 }
      , (* H4'  *)
      { x = 6.1626; y = 6.4620; z = -1.2827 }
      , (* O4'  *)
      { x = 6.5431; y = 5.0992; z = -1.3905 }
      , (* C1'  *)
      { x = 7.2871; y = 4.9328; z = -0.6114 }
      , (* H1'  *)
      { x = 7.1852; y = 4.8935; z = -2.7592 }
      , (* C2'  *)
      { x = 6.8573; y = 3.9363; z = -3.1645 }
      , (* H2'' *)
      { x = 8.5780; y = 5.1025; z = -2.6046 }
      , (* O2'  *)
      { x = 8.9516; y = 4.7577; z = -1.7902 }
      , (* H2'  *)
      { x = 6.5522; y = 6.0300; z = -3.5612 }
      , (* C3'  *)
      { x = 5.5420; y = 5.7356; z = -3.8459 }
      , (* H3'  *)
      { x = 7.3487; y = 6.4089; z = -4.6867 }
      , (* O3'  *)
      { x = 3.6343; y = 2.6680; z = 2.0783 }
      , (* N1   *)
      { x = 5.4505; y = 3.9805; z = 1.2446 }
      , (* N3   *)
      { x = 4.7540; y = 3.3816; z = 2.1851 }
      , (* C2   *)
      { x = 4.8805; y = 3.7951; z = 0.0354 }
      , (* C4   *)
      { x = 3.7416; y = 3.0925; z = -0.2305 }
      , (* C5   *)
      { x = 3.0873; y = 2.4980; z = 0.8606 }
      , (* C6 *)
      A
        ( { x = 1.9600; y = 1.7805; z = 0.7462 }
          , (* N6   *)
          { x = 3.4605; y = 3.1184; z = -1.5906 }
          , (* N7   *)
          { x = 5.3247; y = 4.2695; z = -1.1710 }
          , (* N9   *)
          { x = 4.4244; y = 3.8244; z = -2.0953 }
          , (* C8   *)
          { x = 5.0814; y = 3.4352; z = 3.2234 }
          , (* H2   *)
          { x = 1.5423; y = 1.6454; z = -0.1520 }
          , (* H61  *)
          { x = 1.5716; y = 1.3398; z = 1.5392 }
          , (* H62  *)
          { x = 4.2675; y = 3.8876; z = -3.1721 } ) )

(* H8   *)

let rA05 =
  N
    ( { a = -0.5891
      ; b = 0.0449
      ; c = 0.8068
      ; (* dgf_base_tfo *)
        d = 0.5375
      ; e = 0.7673
      ; f = 0.3498
      ; g = -0.6034
      ; h = 0.6397
      ; i = -0.4762
      ; tx = -0.3019
      ; ty = -3.7679
      ; tz = -9.5913
    }
    , { a = -0.8143
      ; b = -0.5091
      ; c = -0.2788
      ; (* P_O3'_275_tfo *)
        d = -0.0433
      ; e = -0.4257
      ; f = 0.9038
      ; g = -0.5788
      ; h = 0.7480
      ; i = 0.3246
      ; tx = 1.5227
      ; ty = 6.9114
      ; tz = -7.0765
    }
    , { a = 0.3822
      ; b = -0.7477
      ; c = 0.5430
      ; (* P_O3'_180_tfo *)
        d = 0.4552
      ; e = 0.6637
      ; f = 0.5935
      ; g = -0.8042
      ; h = 0.0203
      ; i = 0.5941
      ; tx = -6.9472
      ; ty = -4.1186
      ; tz = -5.9108
    }
    , { a = 0.5640
      ; b = 0.8007
      ; c = -0.2022
      ; (* P_O3'_60_tfo *)
        d = -0.8247
      ; e = 0.5587
      ; f = -0.0878
      ; g = 0.0426
      ; h = 0.2162
      ; i = 0.9754
      ; tx = 6.2694
      ; ty = -7.0540
      ; tz = 3.3316
    }
    , { x = 2.8930; y = 8.5380; z = -3.3280 }
      , (* P    *)
      { x = 1.6980; y = 7.6960; z = -3.5570 }
      , (* O1P  *)
      { x = 3.2260; y = 9.5010; z = -4.4020 }
      , (* O2P  *)
      { x = 4.1590; y = 7.6040; z = -3.0340 }
      , (* O5'  *)
      { x = 4.5778; y = 6.6594; z = -4.0364 }
      , (* C5'  *)
      { x = 4.9220; y = 7.1963; z = -4.9204 }
      , (* H5'  *)
      { x = 3.7996; y = 5.9091; z = -4.1764 }
      , (* H5'' *)
      { x = 5.7873; y = 5.8869; z = -3.5482 }
      , (* C4'  *)
      { x = 6.0405; y = 5.0875; z = -4.2446 }
      , (* H4'  *)
      { x = 6.9135; y = 6.8036; z = -3.4310 }
      , (* O4'  *)
      { x = 7.7293; y = 6.4084; z = -2.3392 }
      , (* C1'  *)
      { x = 8.7078; y = 6.1815; z = -2.7624 }
      , (* H1'  *)
      { x = 7.1305; y = 5.1418; z = -1.7347 }
      , (* C2'  *)
      { x = 7.2040; y = 5.1982; z = -0.6486 }
      , (* H2'' *)
      { x = 7.7417; y = 4.0392; z = -2.3813 }
      , (* O2'  *)
      { x = 8.6785; y = 4.1443; z = -2.5630 }
      , (* H2'  *)
      { x = 5.6666; y = 5.2728; z = -2.1536 }
      , (* C3'  *)
      { x = 5.1747; y = 5.9805; z = -1.4863 }
      , (* H3'  *)
      { x = 4.9997; y = 4.0086; z = -2.1973 }
      , (* O3'  *)
      { x = 10.2594; y = 10.6774; z = -1.0056 }
      , (* N1   *)
      { x = 9.7528; y = 8.7080; z = -2.2631 }
      , (* N3   *)
      { x = 10.4471; y = 9.7876; z = -1.9791 }
      , (* C2   *)
      { x = 8.7271; y = 8.5575; z = -1.3991 }
      , (* C4   *)
      { x = 8.4100; y = 9.3803; z = -0.3580 }
      , (* C5   *)
      { x = 9.2294; y = 10.5030; z = -0.1574 }
      , (* C6 *)
      A
        ( { x = 9.0349; y = 11.3951; z = 0.8250 }
          , (* N6   *)
          { x = 7.2891; y = 8.9068; z = 0.3121 }
          , (* N7   *)
          { x = 7.7962; y = 7.5519; z = -1.3859 }
          , (* N9   *)
          { x = 6.9702; y = 7.8292; z = -0.3353 }
          , (* C8   *)
          { x = 11.3132; y = 10.0537; z = -2.5851 }
          , (* H2   *)
          { x = 8.2741; y = 11.2784; z = 1.4629 }
          , (* H61  *)
          { x = 9.6733; y = 12.1368; z = 0.9529 }
          , (* H62  *)
          { x = 6.0888; y = 7.3990; z = 0.1403 } ) )

(* H8   *)

let rA06 =
  N
    ( { a = -0.9815
      ; b = 0.0731
      ; c = -0.1772
      ; (* dgf_base_tfo *)
        d = 0.1912
      ; e = 0.3054
      ; f = -0.9328
      ; g = -0.0141
      ; h = -0.9494
      ; i = -0.3137
      ; tx = 5.7506
      ; ty = -5.1944
      ; tz = 4.7470
    }
    , { a = -0.8143
      ; b = -0.5091
      ; c = -0.2788
      ; (* P_O3'_275_tfo *)
        d = -0.0433
      ; e = -0.4257
      ; f = 0.9038
      ; g = -0.5788
      ; h = 0.7480
      ; i = 0.3246
      ; tx = 1.5227
      ; ty = 6.9114
      ; tz = -7.0765
    }
    , { a = 0.3822
      ; b = -0.7477
      ; c = 0.5430
      ; (* P_O3'_180_tfo *)
        d = 0.4552
      ; e = 0.6637
      ; f = 0.5935
      ; g = -0.8042
      ; h = 0.0203
      ; i = 0.5941
      ; tx = -6.9472
      ; ty = -4.1186
      ; tz = -5.9108
    }
    , { a = 0.5640
      ; b = 0.8007
      ; c = -0.2022
      ; (* P_O3'_60_tfo *)
        d = -0.8247
      ; e = 0.5587
      ; f = -0.0878
      ; g = 0.0426
      ; h = 0.2162
      ; i = 0.9754
      ; tx = 6.2694
      ; ty = -7.0540
      ; tz = 3.3316
    }
    , { x = 2.8930; y = 8.5380; z = -3.3280 }
      , (* P    *)
      { x = 1.6980; y = 7.6960; z = -3.5570 }
      , (* O1P  *)
      { x = 3.2260; y = 9.5010; z = -4.4020 }
      , (* O2P  *)
      { x = 4.1590; y = 7.6040; z = -3.0340 }
      , (* O5'  *)
      { x = 4.1214; y = 6.7116; z = -1.9049 }
      , (* C5'  *)
      { x = 3.3465; y = 5.9610; z = -2.0607 }
      , (* H5'  *)
      { x = 4.0789; y = 7.2928; z = -0.9837 }
      , (* H5'' *)
      { x = 5.4170; y = 5.9293; z = -1.8186 }
      , (* C4'  *)
      { x = 5.4506; y = 5.3400; z = -0.9023 }
      , (* H4'  *)
      { x = 5.5067; y = 5.0417; z = -2.9703 }
      , (* O4'  *)
      { x = 6.8650; y = 4.9152; z = -3.3612 }
      , (* C1'  *)
      { x = 7.1090; y = 3.8577; z = -3.2603 }
      , (* H1'  *)
      { x = 7.7152; y = 5.7282; z = -2.3894 }
      , (* C2'  *)
      { x = 8.5029; y = 6.2356; z = -2.9463 }
      , (* H2'' *)
      { x = 8.1036; y = 4.8568; z = -1.3419 }
      , (* O2'  *)
      { x = 8.3270; y = 3.9651; z = -1.6184 }
      , (* H2'  *)
      { x = 6.7003; y = 6.7565; z = -1.8911 }
      , (* C3'  *)
      { x = 6.5898; y = 7.5329; z = -2.6482 }
      , (* H3'  *)
      { x = 7.0505; y = 7.2878; z = -0.6105 }
      , (* O3'  *)
      { x = 6.6624; y = 3.5061; z = -8.2986 }
      , (* N1   *)
      { x = 6.5810; y = 3.2570; z = -5.9221 }
      , (* N3   *)
      { x = 6.5151; y = 2.8263; z = -7.1625 }
      , (* C2   *)
      { x = 6.8364; y = 4.5817; z = -5.8882 }
      , (* C4   *)
      { x = 7.0116; y = 5.4064; z = -6.9609 }
      , (* C5   *)
      { x = 6.9173; y = 4.8260; z = -8.2361 }
      , (* C6 *)
      A
        ( { x = 7.0668; y = 5.5163; z = -9.3763 }
          , (* N6   *)
          { x = 7.2573; y = 6.7070; z = -6.5394 }
          , (* N7   *)
          { x = 6.9740; y = 5.3703; z = -4.7760 }
          , (* N9   *)
          { x = 7.2238; y = 6.6275; z = -5.2453 }
          , (* C8   *)
          { x = 6.3146; y = 1.7741; z = -7.3641 }
          , (* H2   *)
          { x = 7.2568; y = 6.4972; z = -9.3456 }
          , (* H61  *)
          { x = 7.0437; y = 5.0478; z = -10.2446 }
          , (* H62  *)
          { x = 7.4108; y = 7.6227; z = -4.8418 } ) )

(* H8   *)

let rA07 =
  N
    ( { a = 0.2379
      ; b = 0.1310
      ; c = -0.9624
      ; (* dgf_base_tfo *)
        d = -0.5876
      ; e = -0.7696
      ; f = -0.2499
      ; g = -0.7734
      ; h = 0.6249
      ; i = -0.1061
      ; tx = 30.9870
      ; ty = -26.9344
      ; tz = 42.6416
    }
    , { a = 0.7529
      ; b = 0.1548
      ; c = 0.6397
      ; (* P_O3'_275_tfo *)
        d = 0.2952
      ; e = -0.9481
      ; f = -0.1180
      ; g = 0.5882
      ; h = 0.2777
      ; i = -0.7595
      ; tx = -58.8919
      ; ty = -11.3095
      ; tz = 6.0866
    }
    , { a = -0.0239
      ; b = 0.9667
      ; c = -0.2546
      ; (* P_O3'_180_tfo *)
        d = 0.9731
      ; e = -0.0359
      ; f = -0.2275
      ; g = -0.2290
      ; h = -0.2532
      ; i = -0.9399
      ; tx = 3.5401
      ; ty = -29.7913
      ; tz = 52.2796
    }
    , { a = -0.8912
      ; b = -0.4531
      ; c = 0.0242
      ; (* P_O3'_60_tfo *)
        d = -0.1183
      ; e = 0.1805
      ; f = -0.9764
      ; g = 0.4380
      ; h = -0.8730
      ; i = -0.2145
      ; tx = 19.9023
      ; ty = 54.8054
      ; tz = 15.2799
    }
    , { x = 41.8210; y = 8.3880; z = 43.5890 }
      , (* P    *)
      { x = 42.5400; y = 8.0450; z = 44.8330 }
      , (* O1P  *)
      { x = 42.2470; y = 9.6920; z = 42.9910 }
      , (* O2P  *)
      { x = 40.2550; y = 8.2030; z = 43.7340 }
      , (* O5'  *)
      { x = 39.3505; y = 8.4697; z = 42.6565 }
      , (* C5'  *)
      { x = 39.1377; y = 7.5433; z = 42.1230 }
      , (* H5'  *)
      { x = 39.7203; y = 9.3119; z = 42.0717 }
      , (* H5'' *)
      { x = 38.0405; y = 8.9195; z = 43.2869 }
      , (* C4'  *)
      { x = 37.3687; y = 9.3036; z = 42.5193 }
      , (* H4'  *)
      { x = 37.4319; y = 7.8146; z = 43.9387 }
      , (* O4'  *)
      { x = 37.1959; y = 8.1354; z = 45.3237 }
      , (* C1'  *)
      { x = 36.1788; y = 8.5202; z = 45.3970 }
      , (* H1'  *)
      { x = 38.1721; y = 9.2328; z = 45.6504 }
      , (* C2'  *)
      { x = 39.1555; y = 8.7939; z = 45.8188 }
      , (* H2'' *)
      { x = 37.7862; y = 10.0617; z = 46.7013 }
      , (* O2'  *)
      { x = 37.3087; y = 9.6229; z = 47.4092 }
      , (* H2'  *)
      { x = 38.1844; y = 10.0268; z = 44.3367 }
      , (* C3'  *)
      { x = 39.1578; y = 10.5054; z = 44.2289 }
      , (* H3'  *)
      { x = 37.0547; y = 10.9127; z = 44.3441 }
      , (* O3'  *)
      { x = 34.8811; y = 4.2072; z = 47.5784 }
      , (* N1   *)
      { x = 35.1084; y = 6.1336; z = 46.1818 }
      , (* N3   *)
      { x = 34.4108; y = 5.1360; z = 46.7207 }
      , (* C2   *)
      { x = 36.3908; y = 6.1224; z = 46.6053 }
      , (* C4   *)
      { x = 36.9819; y = 5.2334; z = 47.4697 }
      , (* C5   *)
      { x = 36.1786; y = 4.1985; z = 48.0035 }
      , (* C6 *)
      A
        ( { x = 36.6103; y = 3.2749; z = 48.8452 }
          , (* N6   *)
          { x = 38.3236; y = 5.5522; z = 47.6595 }
          , (* N7   *)
          { x = 37.3887; y = 7.0024; z = 46.2437 }
          , (* N9   *)
          { x = 38.5055; y = 6.6096; z = 46.9057 }
          , (* C8   *)
          { x = 33.3553; y = 5.0152; z = 46.4771 }
          , (* H2   *)
          { x = 37.5730; y = 3.2804; z = 49.1507 }
          , (* H61  *)
          { x = 35.9775; y = 2.5638; z = 49.1828 }
          , (* H62  *)
          { x = 39.5461; y = 6.9184; z = 47.0041 } ) )

(* H8   *)

let rA08 =
  N
    ( { a = 0.1084
      ; b = -0.0895
      ; c = -0.9901
      ; (* dgf_base_tfo *)
        d = 0.9789
      ; e = -0.1638
      ; f = 0.1220
      ; g = -0.1731
      ; h = -0.9824
      ; i = 0.0698
      ; tx = -2.9039
      ; ty = 47.2655
      ; tz = 33.0094
    }
    , { a = 0.7529
      ; b = 0.1548
      ; c = 0.6397
      ; (* P_O3'_275_tfo *)
        d = 0.2952
      ; e = -0.9481
      ; f = -0.1180
      ; g = 0.5882
      ; h = 0.2777
      ; i = -0.7595
      ; tx = -58.8919
      ; ty = -11.3095
      ; tz = 6.0866
    }
    , { a = -0.0239
      ; b = 0.9667
      ; c = -0.2546
      ; (* P_O3'_180_tfo *)
        d = 0.9731
      ; e = -0.0359
      ; f = -0.2275
      ; g = -0.2290
      ; h = -0.2532
      ; i = -0.9399
      ; tx = 3.5401
      ; ty = -29.7913
      ; tz = 52.2796
    }
    , { a = -0.8912
      ; b = -0.4531
      ; c = 0.0242
      ; (* P_O3'_60_tfo *)
        d = -0.1183
      ; e = 0.1805
      ; f = -0.9764
      ; g = 0.4380
      ; h = -0.8730
      ; i = -0.2145
      ; tx = 19.9023
      ; ty = 54.8054
      ; tz = 15.2799
    }
    , { x = 41.8210; y = 8.3880; z = 43.5890 }
      , (* P    *)
      { x = 42.5400; y = 8.0450; z = 44.8330 }
      , (* O1P  *)
      { x = 42.2470; y = 9.6920; z = 42.9910 }
      , (* O2P  *)
      { x = 40.2550; y = 8.2030; z = 43.7340 }
      , (* O5'  *)
      { x = 39.4850; y = 8.9301; z = 44.6977 }
      , (* C5'  *)
      { x = 39.0638; y = 9.8199; z = 44.2296 }
      , (* H5'  *)
      { x = 40.0757; y = 9.0713; z = 45.6029 }
      , (* H5'' *)
      { x = 38.3102; y = 8.0414; z = 45.0789 }
      , (* C4'  *)
      { x = 37.7842; y = 8.4637; z = 45.9351 }
      , (* H4'  *)
      { x = 37.4200; y = 7.9453; z = 43.9769 }
      , (* O4'  *)
      { x = 37.2249; y = 6.5609; z = 43.6273 }
      , (* C1'  *)
      { x = 36.3360; y = 6.2168; z = 44.1561 }
      , (* H1'  *)
      { x = 38.4347; y = 5.8414; z = 44.1590 }
      , (* C2'  *)
      { x = 39.2688; y = 5.9974; z = 43.4749 }
      , (* H2'' *)
      { x = 38.2344; y = 4.4907; z = 44.4348 }
      , (* O2'  *)
      { x = 37.6374; y = 4.0386; z = 43.8341 }
      , (* H2'  *)
      { x = 38.6926; y = 6.6079; z = 45.4637 }
      , (* C3'  *)
      { x = 39.7585; y = 6.5640; z = 45.6877 }
      , (* H3'  *)
      { x = 37.8238; y = 6.0705; z = 46.4723 }
      , (* O3'  *)
      { x = 33.9162; y = 6.2598; z = 39.7758 }
      , (* N1   *)
      { x = 34.6709; y = 6.5759; z = 42.0215 }
      , (* N3   *)
      { x = 33.7257; y = 6.5186; z = 41.0858 }
      , (* C2   *)
      { x = 35.8935; y = 6.3324; z = 41.5018 }
      , (* C4   *)
      { x = 36.2105; y = 6.0601; z = 40.1932 }
      , (* C5   *)
      { x = 35.1538; y = 6.0151; z = 39.2537 }
      , (* C6 *)
      A
        ( { x = 35.3088; y = 5.7642; z = 37.9649 }
          , (* N6   *)
          { x = 37.5818; y = 5.8677; z = 40.0507 }
          , (* N7   *)
          { x = 37.0932; y = 6.3197; z = 42.1810 }
          , (* N9   *)
          { x = 38.0509; y = 6.0354; z = 41.2635 }
          , (* C8   *)
          { x = 32.6830; y = 6.6898; z = 41.3532 }
          , (* H2   *)
          { x = 36.2305; y = 5.5855; z = 37.5925 }
          , (* H61  *)
          { x = 34.5056; y = 5.7512; z = 37.3528 }
          , (* H62  *)
          { x = 39.1318; y = 5.8993; z = 41.2285 } ) )

(* H8   *)

let rA09 =
  N
    ( { a = 0.8467
      ; b = 0.4166
      ; c = -0.3311
      ; (* dgf_base_tfo *)
        d = -0.3962
      ; e = 0.9089
      ; f = 0.1303
      ; g = 0.3552
      ; h = 0.0209
      ; i = 0.9346
      ; tx = -42.7319
      ; ty = -26.6223
      ; tz = -29.8163
    }
    , { a = 0.7529
      ; b = 0.1548
      ; c = 0.6397
      ; (* P_O3'_275_tfo *)
        d = 0.2952
      ; e = -0.9481
      ; f = -0.1180
      ; g = 0.5882
      ; h = 0.2777
      ; i = -0.7595
      ; tx = -58.8919
      ; ty = -11.3095
      ; tz = 6.0866
    }
    , { a = -0.0239
      ; b = 0.9667
      ; c = -0.2546
      ; (* P_O3'_180_tfo *)
        d = 0.9731
      ; e = -0.0359
      ; f = -0.2275
      ; g = -0.2290
      ; h = -0.2532
      ; i = -0.9399
      ; tx = 3.5401
      ; ty = -29.7913
      ; tz = 52.2796
    }
    , { a = -0.8912
      ; b = -0.4531
      ; c = 0.0242
      ; (* P_O3'_60_tfo *)
        d = -0.1183
      ; e = 0.1805
      ; f = -0.9764
      ; g = 0.4380
      ; h = -0.8730
      ; i = -0.2145
      ; tx = 19.9023
      ; ty = 54.8054
      ; tz = 15.2799
    }
    , { x = 41.8210; y = 8.3880; z = 43.5890 }
      , (* P    *)
      { x = 42.5400; y = 8.0450; z = 44.8330 }
      , (* O1P  *)
      { x = 42.2470; y = 9.6920; z = 42.9910 }
      , (* O2P  *)
      { x = 40.2550; y = 8.2030; z = 43.7340 }
      , (* O5'  *)
      { x = 39.3505; y = 8.4697; z = 42.6565 }
      , (* C5'  *)
      { x = 39.1377; y = 7.5433; z = 42.1230 }
      , (* H5'  *)
      { x = 39.7203; y = 9.3119; z = 42.0717 }
      , (* H5'' *)
      { x = 38.0405; y = 8.9195; z = 43.2869 }
      , (* C4'  *)
      { x = 37.6479; y = 8.1347; z = 43.9335 }
      , (* H4'  *)
      { x = 38.2691; y = 10.0933; z = 44.0524 }
      , (* O4'  *)
      { x = 37.3999; y = 11.1488; z = 43.5973 }
      , (* C1'  *)
      { x = 36.5061; y = 11.1221; z = 44.2206 }
      , (* H1'  *)
      { x = 37.0364; y = 10.7838; z = 42.1836 }
      , (* C2'  *)
      { x = 37.8636; y = 11.0489; z = 41.5252 }
      , (* H2'' *)
      { x = 35.8275; y = 11.3133; z = 41.7379 }
      , (* O2'  *)
      { x = 35.6214; y = 12.1896; z = 42.0714 }
      , (* H2'  *)
      { x = 36.9316; y = 9.2556; z = 42.2837 }
      , (* C3'  *)
      { x = 37.1778; y = 8.8260; z = 41.3127 }
      , (* H3'  *)
      { x = 35.6285; y = 8.9334; z = 42.7926 }
      , (* O3'  *)
      { x = 38.1482; y = 15.2833; z = 46.4641 }
      , (* N1   *)
      { x = 37.3641; y = 13.0968; z = 45.9007 }
      , (* N3   *)
      { x = 37.5032; y = 14.1288; z = 46.7300 }
      , (* C2   *)
      { x = 37.9570; y = 13.3377; z = 44.7113 }
      , (* C4   *)
      { x = 38.6397; y = 14.4660; z = 44.3267 }
      , (* C5   *)
      { x = 38.7473; y = 15.5229; z = 45.2609 }
      , (* C6 *)
      A
        ( { x = 39.3720; y = 16.6649; z = 45.0297 }
          , (* N6   *)
          { x = 39.1079; y = 14.3351; z = 43.0223 }
          , (* N7   *)
          { x = 38.0132; y = 12.4868; z = 43.6280 }
          , (* N9   *)
          { x = 38.7058; y = 13.1402; z = 42.6620 }
          , (* C8   *)
          { x = 37.0731; y = 14.0857; z = 47.7306 }
          , (* H2   *)
          { x = 39.8113; y = 16.8281; z = 44.1350 }
          , (* H61  *)
          { x = 39.4100; y = 17.3741; z = 45.7478 }
          , (* H62  *)
          { x = 39.0412; y = 12.9660; z = 41.6397 } ) )

(* H8   *)

let rA10 =
  N
    ( { a = 0.7063
      ; b = 0.6317
      ; c = -0.3196
      ; (* dgf_base_tfo *)
        d = -0.0403
      ; e = -0.4149
      ; f = -0.9090
      ; g = -0.7068
      ; h = 0.6549
      ; i = -0.2676
      ; tx = 6.4402
      ; ty = -52.1496
      ; tz = 30.8246
    }
    , { a = 0.7529
      ; b = 0.1548
      ; c = 0.6397
      ; (* P_O3'_275_tfo *)
        d = 0.2952
      ; e = -0.9481
      ; f = -0.1180
      ; g = 0.5882
      ; h = 0.2777
      ; i = -0.7595
      ; tx = -58.8919
      ; ty = -11.3095
      ; tz = 6.0866
    }
    , { a = -0.0239
      ; b = 0.9667
      ; c = -0.2546
      ; (* P_O3'_180_tfo *)
        d = 0.9731
      ; e = -0.0359
      ; f = -0.2275
      ; g = -0.2290
      ; h = -0.2532
      ; i = -0.9399
      ; tx = 3.5401
      ; ty = -29.7913
      ; tz = 52.2796
    }
    , { a = -0.8912
      ; b = -0.4531
      ; c = 0.0242
      ; (* P_O3'_60_tfo *)
        d = -0.1183
      ; e = 0.1805
      ; f = -0.9764
      ; g = 0.4380
      ; h = -0.8730
      ; i = -0.2145
      ; tx = 19.9023
      ; ty = 54.8054
      ; tz = 15.2799
    }
    , { x = 41.8210; y = 8.3880; z = 43.5890 }
      , (* P    *)
      { x = 42.5400; y = 8.0450; z = 44.8330 }
      , (* O1P  *)
      { x = 42.2470; y = 9.6920; z = 42.9910 }
      , (* O2P  *)
      { x = 40.2550; y = 8.2030; z = 43.7340 }
      , (* O5'  *)
      { x = 39.4850; y = 8.9301; z = 44.6977 }
      , (* C5'  *)
      { x = 39.0638; y = 9.8199; z = 44.2296 }
      , (* H5'  *)
      { x = 40.0757; y = 9.0713; z = 45.6029 }
      , (* H5'' *)
      { x = 38.3102; y = 8.0414; z = 45.0789 }
      , (* C4'  *)
      { x = 37.7099; y = 7.8166; z = 44.1973 }
      , (* H4'  *)
      { x = 38.8012; y = 6.8321; z = 45.6380 }
      , (* O4'  *)
      { x = 38.2431; y = 6.6413; z = 46.9529 }
      , (* C1'  *)
      { x = 37.3505; y = 6.0262; z = 46.8385 }
      , (* H1'  *)
      { x = 37.8484; y = 8.0156; z = 47.4214 }
      , (* C2'  *)
      { x = 38.7381; y = 8.5406; z = 47.7690 }
      , (* H2'' *)
      { x = 36.8286; y = 8.0368; z = 48.3701 }
      , (* O2'  *)
      { x = 36.8392; y = 7.3063; z = 48.9929 }
      , (* H2'  *)
      { x = 37.3576; y = 8.6512; z = 46.1132 }
      , (* C3'  *)
      { x = 37.5207; y = 9.7275; z = 46.1671 }
      , (* H3'  *)
      { x = 35.9985; y = 8.2392; z = 45.9032 }
      , (* O3'  *)
      { x = 39.9117; y = 2.2278; z = 48.8527 }
      , (* N1   *)
      { x = 38.6207; y = 3.6941; z = 47.4757 }
      , (* N3   *)
      { x = 38.9872; y = 2.4888; z = 47.9057 }
      , (* C2   *)
      { x = 39.2961; y = 4.6720; z = 48.1174 }
      , (* C4   *)
      { x = 40.2546; y = 4.5307; z = 49.0912 }
      , (* C5   *)
      { x = 40.5932; y = 3.2189; z = 49.4985 }
      , (* C6 *)
      A
        ( { x = 41.4938; y = 2.9317; z = 50.4229 }
          , (* N6   *)
          { x = 40.7195; y = 5.7755; z = 49.5060 }
          , (* N7   *)
          { x = 39.1730; y = 6.0305; z = 47.9170 }
          , (* N9   *)
          { x = 40.0413; y = 6.6250; z = 48.7728 }
          , (* C8   *)
          { x = 38.5257; y = 1.5960; z = 47.4838 }
          , (* H2   *)
          { x = 41.9907; y = 3.6753; z = 50.8921 }
          , (* H61  *)
          { x = 41.6848; y = 1.9687; z = 50.6599 }
          , (* H62  *)
          { x = 40.3571; y = 7.6321; z = 49.0452 } ) )

(* H8   *)

let rAs = [ rA01; rA02; rA03; rA04; rA05; rA06; rA07; rA08; rA09; rA10 ]

let rC =
  N
    ( { a = -0.0359
      ; b = -0.8071
      ; c = 0.5894
      ; (* dgf_base_tfo *)
        d = -0.2669
      ; e = 0.5761
      ; f = 0.7726
      ; g = -0.9631
      ; h = -0.1296
      ; i = -0.2361
      ; tx = 0.1584
      ; ty = 8.3434
      ; tz = 0.5434
    }
    , { a = -0.8313
      ; b = -0.4738
      ; c = -0.2906
      ; (* P_O3'_275_tfo *)
        d = 0.0649
      ; e = 0.4366
      ; f = -0.8973
      ; g = 0.5521
      ; h = -0.7648
      ; i = -0.3322
      ; tx = 1.6833
      ; ty = 6.8060
      ; tz = -7.0011
    }
    , { a = 0.3445
      ; b = -0.7630
      ; c = 0.5470
      ; (* P_O3'_180_tfo *)
        d = -0.4628
      ; e = -0.6450
      ; f = -0.6082
      ; g = 0.8168
      ; h = -0.0436
      ; i = -0.5753
      ; tx = -6.8179
      ; ty = -3.9778
      ; tz = -5.9887
    }
    , { a = 0.5855
      ; b = 0.7931
      ; c = -0.1682
      ; (* P_O3'_60_tfo *)
        d = 0.8103
      ; e = -0.5790
      ; f = 0.0906
      ; g = -0.0255
      ; h = -0.1894
      ; i = -0.9816
      ; tx = 6.1203
      ; ty = -7.1051
      ; tz = 3.1984
    }
    , { x = 2.6760; y = -8.4960; z = 3.2880 }
      , (* P    *)
      { x = 1.4950; y = -7.6230; z = 3.4770 }
      , (* O1P  *)
      { x = 2.9490; y = -9.4640; z = 4.3740 }
      , (* O2P  *)
      { x = 3.9730; y = -7.5950; z = 3.0340 }
      , (* O5'  *)
      { x = 5.2430; y = -8.2420; z = 2.8260 }
      , (* C5'  *)
      { x = 5.1974; y = -8.8497; z = 1.9223 }
      , (* H5'  *)
      { x = 5.5548; y = -8.7348; z = 3.7469 }
      , (* H5'' *)
      { x = 6.3140; y = -7.2060; z = 2.5510 }
      , (* C4'  *)
      { x = 7.2954; y = -7.6762; z = 2.4898 }
      , (* H4'  *)
      { x = 6.0140; y = -6.5420; z = 1.2890 }
      , (* O4'  *)
      { x = 6.4190; y = -5.1840; z = 1.3620 }
      , (* C1'  *)
      { x = 7.1608; y = -5.0495; z = 0.5747 }
      , (* H1'  *)
      { x = 7.0760; y = -4.9560; z = 2.7270 }
      , (* C2'  *)
      { x = 6.7770; y = -3.9803; z = 3.1099 }
      , (* H2'' *)
      { x = 8.4500; y = -5.1930; z = 2.5810 }
      , (* O2'  *)
      { x = 8.8309; y = -4.8755; z = 1.7590 }
      , (* H2'  *)
      { x = 6.4060; y = -6.0590; z = 3.5580 }
      , (* C3'  *)
      { x = 5.4021; y = -5.7313; z = 3.8281 }
      , (* H3'  *)
      { x = 7.1570; y = -6.4240; z = 4.7070 }
      , (* O3'  *)
      { x = 5.2170; y = -4.3260; z = 1.1690 }
      , (* N1   *)
      { x = 4.2960; y = -2.2560; z = 0.6290 }
      , (* N3   *)
      { x = 5.4330; y = -3.0200; z = 0.7990 }
      , (* C2   *)
      { x = 2.9930; y = -2.6780; z = 0.7940 }
      , (* C4   *)
      { x = 2.8670; y = -4.0630; z = 1.1830 }
      , (* C5   *)
      { x = 3.9570; y = -4.8300; z = 1.3550 }
      , (* C6 *)
      C
        ( { x = 2.0187; y = -1.8047; z = 0.5874 }
          , (* N4   *)
          { x = 6.5470; y = -2.5560; z = 0.6290 }
          , (* O2   *)
          { x = 1.0684; y = -2.1236; z = 0.7109 }
          , (* H41  *)
          { x = 2.2344; y = -0.8560; z = 0.3162 }
          , (* H42  *)
          { x = 1.8797; y = -4.4972; z = 1.3404 }
          , (* H5   *)
          { x = 3.8479; y = -5.8742; z = 1.6480 } ) )

(* H6   *)

let rC01 =
  N
    ( { a = -0.0137
      ; b = -0.8012
      ; c = 0.5983
      ; (* dgf_base_tfo *)
        d = -0.2523
      ; e = 0.5817
      ; f = 0.7733
      ; g = -0.9675
      ; h = -0.1404
      ; i = -0.2101
      ; tx = 0.2031
      ; ty = 8.3874
      ; tz = 0.4228
    }
    , { a = -0.8313
      ; b = -0.4738
      ; c = -0.2906
      ; (* P_O3'_275_tfo *)
        d = 0.0649
      ; e = 0.4366
      ; f = -0.8973
      ; g = 0.5521
      ; h = -0.7648
      ; i = -0.3322
      ; tx = 1.6833
      ; ty = 6.8060
      ; tz = -7.0011
    }
    , { a = 0.3445
      ; b = -0.7630
      ; c = 0.5470
      ; (* P_O3'_180_tfo *)
        d = -0.4628
      ; e = -0.6450
      ; f = -0.6082
      ; g = 0.8168
      ; h = -0.0436
      ; i = -0.5753
      ; tx = -6.8179
      ; ty = -3.9778
      ; tz = -5.9887
    }
    , { a = 0.5855
      ; b = 0.7931
      ; c = -0.1682
      ; (* P_O3'_60_tfo *)
        d = 0.8103
      ; e = -0.5790
      ; f = 0.0906
      ; g = -0.0255
      ; h = -0.1894
      ; i = -0.9816
      ; tx = 6.1203
      ; ty = -7.1051
      ; tz = 3.1984
    }
    , { x = 2.6760; y = -8.4960; z = 3.2880 }
      , (* P    *)
      { x = 1.4950; y = -7.6230; z = 3.4770 }
      , (* O1P  *)
      { x = 2.9490; y = -9.4640; z = 4.3740 }
      , (* O2P  *)
      { x = 3.9730; y = -7.5950; z = 3.0340 }
      , (* O5'  *)
      { x = 5.2416; y = -8.2422; z = 2.8181 }
      , (* C5'  *)
      { x = 5.2050; y = -8.8128; z = 1.8901 }
      , (* H5'  *)
      { x = 5.5368; y = -8.7738; z = 3.7227 }
      , (* H5'' *)
      { x = 6.3232; y = -7.2037; z = 2.6002 }
      , (* C4'  *)
      { x = 7.3048; y = -7.6757; z = 2.5577 }
      , (* H4'  *)
      { x = 6.0635; y = -6.5092; z = 1.3456 }
      , (* O4'  *)
      { x = 6.4697; y = -5.1547; z = 1.4629 }
      , (* C1'  *)
      { x = 7.2354; y = -5.0043; z = 0.7018 }
      , (* H1'  *)
      { x = 7.0856; y = -4.9610; z = 2.8521 }
      , (* C2'  *)
      { x = 6.7777; y = -3.9935; z = 3.2487 }
      , (* H2'' *)
      { x = 8.4627; y = -5.1992; z = 2.7423 }
      , (* O2'  *)
      { x = 8.8693; y = -4.8638; z = 1.9399 }
      , (* H2'  *)
      { x = 6.3877; y = -6.0809; z = 3.6362 }
      , (* C3'  *)
      { x = 5.3770; y = -5.7562; z = 3.8834 }
      , (* H3'  *)
      { x = 7.1024; y = -6.4754; z = 4.7985 }
      , (* O3'  *)
      { x = 5.2764; y = -4.2883; z = 1.2538 }
      , (* N1   *)
      { x = 4.3777; y = -2.2062; z = 0.7229 }
      , (* N3   *)
      { x = 5.5069; y = -2.9779; z = 0.9088 }
      , (* C2   *)
      { x = 3.0693; y = -2.6246; z = 0.8500 }
      , (* C4   *)
      { x = 2.9279; y = -4.0146; z = 1.2149 }
      , (* C5   *)
      { x = 4.0101; y = -4.7892; z = 1.4017 }
      , (* C6 *)
      C
        ( { x = 2.1040; y = -1.7437; z = 0.6331 }
          , (* N4   *)
          { x = 6.6267; y = -2.5166; z = 0.7728 }
          , (* O2   *)
          { x = 1.1496; y = -2.0600; z = 0.7287 }
          , (* H41  *)
          { x = 2.3303; y = -0.7921; z = 0.3815 }
          , (* H42  *)
          { x = 1.9353; y = -4.4465; z = 1.3419 }
          , (* H5   *)
          { x = 3.8895; y = -5.8371; z = 1.6762 } ) )

(* H6   *)

let rC02 =
  N
    ( { a = 0.5141
      ; b = 0.0246
      ; c = 0.8574
      ; (* dgf_base_tfo *)
        d = -0.5547
      ; e = -0.7529
      ; f = 0.3542
      ; g = 0.6542
      ; h = -0.6577
      ; i = -0.3734
      ; tx = -9.1111
      ; ty = -3.4598
      ; tz = -3.2939
    }
    , { a = -0.8313
      ; b = -0.4738
      ; c = -0.2906
      ; (* P_O3'_275_tfo *)
        d = 0.0649
      ; e = 0.4366
      ; f = -0.8973
      ; g = 0.5521
      ; h = -0.7648
      ; i = -0.3322
      ; tx = 1.6833
      ; ty = 6.8060
      ; tz = -7.0011
    }
    , { a = 0.3445
      ; b = -0.7630
      ; c = 0.5470
      ; (* P_O3'_180_tfo *)
        d = -0.4628
      ; e = -0.6450
      ; f = -0.6082
      ; g = 0.8168
      ; h = -0.0436
      ; i = -0.5753
      ; tx = -6.8179
      ; ty = -3.9778
      ; tz = -5.9887
    }
    , { a = 0.5855
      ; b = 0.7931
      ; c = -0.1682
      ; (* P_O3'_60_tfo *)
        d = 0.8103
      ; e = -0.5790
      ; f = 0.0906
      ; g = -0.0255
      ; h = -0.1894
      ; i = -0.9816
      ; tx = 6.1203
      ; ty = -7.1051
      ; tz = 3.1984
    }
    , { x = 2.6760; y = -8.4960; z = 3.2880 }
      , (* P    *)
      { x = 1.4950; y = -7.6230; z = 3.4770 }
      , (* O1P  *)
      { x = 2.9490; y = -9.4640; z = 4.3740 }
      , (* O2P  *)
      { x = 3.9730; y = -7.5950; z = 3.0340 }
      , (* O5'  *)
      { x = 4.3825; y = -6.6585; z = 4.0489 }
      , (* C5'  *)
      { x = 4.6841; y = -7.2019; z = 4.9443 }
      , (* H5'  *)
      { x = 3.6189; y = -5.8889; z = 4.1625 }
      , (* H5'' *)
      { x = 5.6255; y = -5.9175; z = 3.5998 }
      , (* C4'  *)
      { x = 5.8732; y = -5.1228; z = 4.3034 }
      , (* H4'  *)
      { x = 6.7337; y = -6.8605; z = 3.5222 }
      , (* O4'  *)
      { x = 7.5932; y = -6.4923; z = 2.4548 }
      , (* C1'  *)
      { x = 8.5661; y = -6.2983; z = 2.9064 }
      , (* H1'  *)
      { x = 7.0527; y = -5.2012; z = 1.8322 }
      , (* C2'  *)
      { x = 7.1627; y = -5.2525; z = 0.7490 }
      , (* H2'' *)
      { x = 7.6666; y = -4.1249; z = 2.4880 }
      , (* O2'  *)
      { x = 8.5944; y = -4.2543; z = 2.6981 }
      , (* H2'  *)
      { x = 5.5661; y = -5.3029; z = 2.2009 }
      , (* C3'  *)
      { x = 5.0841; y = -6.0018; z = 1.5172 }
      , (* H3'  *)
      { x = 4.9062; y = -4.0452; z = 2.2042 }
      , (* O3'  *)
      { x = 7.6298; y = -7.6136; z = 1.4752 }
      , (* N1   *)
      { x = 8.6945; y = -8.7046; z = -0.2857 }
      , (* N3   *)
      { x = 8.6943; y = -7.6514; z = 0.6066 }
      , (* C2   *)
      { x = 7.7426; y = -9.6987; z = -0.3801 }
      , (* C4   *)
      { x = 6.6642; y = -9.5742; z = 0.5722 }
      , (* C5   *)
      { x = 6.6391; y = -8.5592; z = 1.4526 }
      , (* C6 *)
      C
        ( { x = 7.9033; y = -10.6371; z = -1.3010 }
          , (* N4   *)
          { x = 9.5840; y = -6.8186; z = 0.6136 }
          , (* O2   *)
          { x = 7.2009; y = -11.3604; z = -1.3619 }
          , (* H41  *)
          { x = 8.7058; y = -10.6168; z = -1.9140 }
          , (* H42  *)
          { x = 5.8585; y = -10.3083; z = 0.5822 }
          , (* H5   *)
          { x = 5.8197; y = -8.4773; z = 2.1667 } ) )

(* H6   *)

let rC03 =
  N
    ( { a = -0.4993
      ; b = 0.0476
      ; c = 0.8651
      ; (* dgf_base_tfo *)
        d = 0.8078
      ; e = -0.3353
      ; f = 0.4847
      ; g = 0.3132
      ; h = 0.9409
      ; i = 0.1290
      ; tx = 6.2989
      ; ty = -5.2303
      ; tz = -3.8577
    }
    , { a = -0.8313
      ; b = -0.4738
      ; c = -0.2906
      ; (* P_O3'_275_tfo *)
        d = 0.0649
      ; e = 0.4366
      ; f = -0.8973
      ; g = 0.5521
      ; h = -0.7648
      ; i = -0.3322
      ; tx = 1.6833
      ; ty = 6.8060
      ; tz = -7.0011
    }
    , { a = 0.3445
      ; b = -0.7630
      ; c = 0.5470
      ; (* P_O3'_180_tfo *)
        d = -0.4628
      ; e = -0.6450
      ; f = -0.6082
      ; g = 0.8168
      ; h = -0.0436
      ; i = -0.5753
      ; tx = -6.8179
      ; ty = -3.9778
      ; tz = -5.9887
    }
    , { a = 0.5855
      ; b = 0.7931
      ; c = -0.1682
      ; (* P_O3'_60_tfo *)
        d = 0.8103
      ; e = -0.5790
      ; f = 0.0906
      ; g = -0.0255
      ; h = -0.1894
      ; i = -0.9816
      ; tx = 6.1203
      ; ty = -7.1051
      ; tz = 3.1984
    }
    , { x = 2.6760; y = -8.4960; z = 3.2880 }
      , (* P    *)
      { x = 1.4950; y = -7.6230; z = 3.4770 }
      , (* O1P  *)
      { x = 2.9490; y = -9.4640; z = 4.3740 }
      , (* O2P  *)
      { x = 3.9730; y = -7.5950; z = 3.0340 }
      , (* O5'  *)
      { x = 3.9938; y = -6.7042; z = 1.9023 }
      , (* C5'  *)
      { x = 3.2332; y = -5.9343; z = 2.0319 }
      , (* H5'  *)
      { x = 3.9666; y = -7.2863; z = 0.9812 }
      , (* H5'' *)
      { x = 5.3098; y = -5.9546; z = 1.8564 }
      , (* C4'  *)
      { x = 5.3863; y = -5.3702; z = 0.9395 }
      , (* H4'  *)
      { x = 5.3851; y = -5.0642; z = 3.0076 }
      , (* O4'  *)
      { x = 6.7315; y = -4.9724; z = 3.4462 }
      , (* C1'  *)
      { x = 7.0033; y = -3.9202; z = 3.3619 }
      , (* H1'  *)
      { x = 7.5997; y = -5.8018; z = 2.4948 }
      , (* C2'  *)
      { x = 8.3627; y = -6.3254; z = 3.0707 }
      , (* H2'' *)
      { x = 8.0410; y = -4.9501; z = 1.4724 }
      , (* O2'  *)
      { x = 8.2781; y = -4.0644; z = 1.7570 }
      , (* H2'  *)
      { x = 6.5701; y = -6.8129; z = 1.9714 }
      , (* C3'  *)
      { x = 6.4186; y = -7.5809; z = 2.7299 }
      , (* H3'  *)
      { x = 6.9357; y = -7.3841; z = 0.7235 }
      , (* O3'  *)
      { x = 6.8024; y = -5.4718; z = 4.8475 }
      , (* N1   *)
      { x = 7.9218; y = -5.5700; z = 6.8877 }
      , (* N3   *)
      { x = 7.8908; y = -5.0886; z = 5.5944 }
      , (* C2   *)
      { x = 6.9789; y = -6.3827; z = 7.4823 }
      , (* C4   *)
      { x = 5.8742; y = -6.7319; z = 6.6202 }
      , (* C5   *)
      { x = 5.8182; y = -6.2769; z = 5.3570 }
      , (* C6 *)
      C
        ( { x = 7.1702; y = -6.7511; z = 8.7402 }
          , (* N4   *)
          { x = 8.7747; y = -4.3728; z = 5.1568 }
          , (* O2   *)
          { x = 6.4741; y = -7.3461; z = 9.1662 }
          , (* H41  *)
          { x = 7.9889; y = -6.4396; z = 9.2429 }
          , (* H42  *)
          { x = 5.0736; y = -7.3713; z = 6.9922 }
          , (* H5   *)
          { x = 4.9784; y = -6.5473; z = 4.7170 } ) )

(* H6   *)

let rC04 =
  N
    ( { a = -0.5669
      ; b = -0.8012
      ; c = 0.1918
      ; (* dgf_base_tfo *)
        d = -0.8129
      ; e = 0.5817
      ; f = 0.0273
      ; g = -0.1334
      ; h = -0.1404
      ; i = -0.9811
      ; tx = -0.3279
      ; ty = 8.3874
      ; tz = 0.3355
    }
    , { a = -0.8313
      ; b = -0.4738
      ; c = -0.2906
      ; (* P_O3'_275_tfo *)
        d = 0.0649
      ; e = 0.4366
      ; f = -0.8973
      ; g = 0.5521
      ; h = -0.7648
      ; i = -0.3322
      ; tx = 1.6833
      ; ty = 6.8060
      ; tz = -7.0011
    }
    , { a = 0.3445
      ; b = -0.7630
      ; c = 0.5470
      ; (* P_O3'_180_tfo *)
        d = -0.4628
      ; e = -0.6450
      ; f = -0.6082
      ; g = 0.8168
      ; h = -0.0436
      ; i = -0.5753
      ; tx = -6.8179
      ; ty = -3.9778
      ; tz = -5.9887
    }
    , { a = 0.5855
      ; b = 0.7931
      ; c = -0.1682
      ; (* P_O3'_60_tfo *)
        d = 0.8103
      ; e = -0.5790
      ; f = 0.0906
      ; g = -0.0255
      ; h = -0.1894
      ; i = -0.9816
      ; tx = 6.1203
      ; ty = -7.1051
      ; tz = 3.1984
    }
    , { x = 2.6760; y = -8.4960; z = 3.2880 }
      , (* P    *)
      { x = 1.4950; y = -7.6230; z = 3.4770 }
      , (* O1P  *)
      { x = 2.9490; y = -9.4640; z = 4.3740 }
      , (* O2P  *)
      { x = 3.9730; y = -7.5950; z = 3.0340 }
      , (* O5'  *)
      { x = 5.2416; y = -8.2422; z = 2.8181 }
      , (* C5'  *)
      { x = 5.2050; y = -8.8128; z = 1.8901 }
      , (* H5'  *)
      { x = 5.5368; y = -8.7738; z = 3.7227 }
      , (* H5'' *)
      { x = 6.3232; y = -7.2037; z = 2.6002 }
      , (* C4'  *)
      { x = 7.3048; y = -7.6757; z = 2.5577 }
      , (* H4'  *)
      { x = 6.0635; y = -6.5092; z = 1.3456 }
      , (* O4'  *)
      { x = 6.4697; y = -5.1547; z = 1.4629 }
      , (* C1'  *)
      { x = 7.2354; y = -5.0043; z = 0.7018 }
      , (* H1'  *)
      { x = 7.0856; y = -4.9610; z = 2.8521 }
      , (* C2'  *)
      { x = 6.7777; y = -3.9935; z = 3.2487 }
      , (* H2'' *)
      { x = 8.4627; y = -5.1992; z = 2.7423 }
      , (* O2'  *)
      { x = 8.8693; y = -4.8638; z = 1.9399 }
      , (* H2'  *)
      { x = 6.3877; y = -6.0809; z = 3.6362 }
      , (* C3'  *)
      { x = 5.3770; y = -5.7562; z = 3.8834 }
      , (* H3'  *)
      { x = 7.1024; y = -6.4754; z = 4.7985 }
      , (* O3'  *)
      { x = 5.2764; y = -4.2883; z = 1.2538 }
      , (* N1   *)
      { x = 3.8961; y = -3.0896; z = -0.1893 }
      , (* N3   *)
      { x = 5.0095; y = -3.8907; z = -0.0346 }
      , (* C2   *)
      { x = 3.0480; y = -2.6632; z = 0.8116 }
      , (* C4   *)
      { x = 3.4093; y = -3.1310; z = 2.1292 }
      , (* C5   *)
      { x = 4.4878; y = -3.9124; z = 2.3088 }
      , (* C6 *)
      C
        ( { x = 2.0216; y = -1.8941; z = 0.4804 }
          , (* N4   *)
          { x = 5.7005; y = -4.2164; z = -0.9842 }
          , (* O2   *)
          { x = 1.4067; y = -1.5873; z = 1.2205 }
          , (* H41  *)
          { x = 1.8721; y = -1.6319; z = -0.4835 }
          , (* H42  *)
          { x = 2.8048; y = -2.8507; z = 2.9918 }
          , (* H5   *)
          { x = 4.7491; y = -4.2593; z = 3.3085 } ) )

(* H6   *)

let rC05 =
  N
    ( { a = -0.6298
      ; b = 0.0246
      ; c = 0.7763
      ; (* dgf_base_tfo *)
        d = -0.5226
      ; e = -0.7529
      ; f = -0.4001
      ; g = 0.5746
      ; h = -0.6577
      ; i = 0.4870
      ; tx = -0.0208
      ; ty = -3.4598
      ; tz = -9.6882
    }
    , { a = -0.8313
      ; b = -0.4738
      ; c = -0.2906
      ; (* P_O3'_275_tfo *)
        d = 0.0649
      ; e = 0.4366
      ; f = -0.8973
      ; g = 0.5521
      ; h = -0.7648
      ; i = -0.3322
      ; tx = 1.6833
      ; ty = 6.8060
      ; tz = -7.0011
    }
    , { a = 0.3445
      ; b = -0.7630
      ; c = 0.5470
      ; (* P_O3'_180_tfo *)
        d = -0.4628
      ; e = -0.6450
      ; f = -0.6082
      ; g = 0.8168
      ; h = -0.0436
      ; i = -0.5753
      ; tx = -6.8179
      ; ty = -3.9778
      ; tz = -5.9887
    }
    , { a = 0.5855
      ; b = 0.7931
      ; c = -0.1682
      ; (* P_O3'_60_tfo *)
        d = 0.8103
      ; e = -0.5790
      ; f = 0.0906
      ; g = -0.0255
      ; h = -0.1894
      ; i = -0.9816
      ; tx = 6.1203
      ; ty = -7.1051
      ; tz = 3.1984
    }
    , { x = 2.6760; y = -8.4960; z = 3.2880 }
      , (* P    *)
      { x = 1.4950; y = -7.6230; z = 3.4770 }
      , (* O1P  *)
      { x = 2.9490; y = -9.4640; z = 4.3740 }
      , (* O2P  *)
      { x = 3.9730; y = -7.5950; z = 3.0340 }
      , (* O5'  *)
      { x = 4.3825; y = -6.6585; z = 4.0489 }
      , (* C5'  *)
      { x = 4.6841; y = -7.2019; z = 4.9443 }
      , (* H5'  *)
      { x = 3.6189; y = -5.8889; z = 4.1625 }
      , (* H5'' *)
      { x = 5.6255; y = -5.9175; z = 3.5998 }
      , (* C4'  *)
      { x = 5.8732; y = -5.1228; z = 4.3034 }
      , (* H4'  *)
      { x = 6.7337; y = -6.8605; z = 3.5222 }
      , (* O4'  *)
      { x = 7.5932; y = -6.4923; z = 2.4548 }
      , (* C1'  *)
      { x = 8.5661; y = -6.2983; z = 2.9064 }
      , (* H1'  *)
      { x = 7.0527; y = -5.2012; z = 1.8322 }
      , (* C2'  *)
      { x = 7.1627; y = -5.2525; z = 0.7490 }
      , (* H2'' *)
      { x = 7.6666; y = -4.1249; z = 2.4880 }
      , (* O2'  *)
      { x = 8.5944; y = -4.2543; z = 2.6981 }
      , (* H2'  *)
      { x = 5.5661; y = -5.3029; z = 2.2009 }
      , (* C3'  *)
      { x = 5.0841; y = -6.0018; z = 1.5172 }
      , (* H3'  *)
      { x = 4.9062; y = -4.0452; z = 2.2042 }
      , (* O3'  *)
      { x = 7.6298; y = -7.6136; z = 1.4752 }
      , (* N1   *)
      { x = 8.5977; y = -9.5977; z = 0.7329 }
      , (* N3   *)
      { x = 8.5951; y = -8.5745; z = 1.6594 }
      , (* C2   *)
      { x = 7.7372; y = -9.7371; z = -0.3364 }
      , (* C4   *)
      { x = 6.7596; y = -8.6801; z = -0.4476 }
      , (* C5   *)
      { x = 6.7338; y = -7.6721; z = 0.4408 }
      , (* C6 *)
      C
        ( { x = 7.8849; y = -10.7881; z = -1.1289 }
          , (* N4   *)
          { x = 9.3993; y = -8.5377; z = 2.5743 }
          , (* O2   *)
          { x = 7.2499; y = -10.8809; z = -1.9088 }
          , (* H41  *)
          { x = 8.6122; y = -11.4649; z = -0.9468 }
          , (* H42  *)
          { x = 6.0317; y = -8.6941; z = -1.2588 }
          , (* H5   *)
          { x = 5.9901; y = -6.8809; z = 0.3459 } ) )

(* H6   *)

let rC06 =
  N
    ( { a = -0.9837
      ; b = 0.0476
      ; c = -0.1733
      ; (* dgf_base_tfo *)
        d = -0.1792
      ; e = -0.3353
      ; f = 0.9249
      ; g = -0.0141
      ; h = 0.9409
      ; i = 0.3384
      ; tx = 5.7793
      ; ty = -5.2303
      ; tz = 4.5997
    }
    , { a = -0.8313
      ; b = -0.4738
      ; c = -0.2906
      ; (* P_O3'_275_tfo *)
        d = 0.0649
      ; e = 0.4366
      ; f = -0.8973
      ; g = 0.5521
      ; h = -0.7648
      ; i = -0.3322
      ; tx = 1.6833
      ; ty = 6.8060
      ; tz = -7.0011
    }
    , { a = 0.3445
      ; b = -0.7630
      ; c = 0.5470
      ; (* P_O3'_180_tfo *)
        d = -0.4628
      ; e = -0.6450
      ; f = -0.6082
      ; g = 0.8168
      ; h = -0.0436
      ; i = -0.5753
      ; tx = -6.8179
      ; ty = -3.9778
      ; tz = -5.9887
    }
    , { a = 0.5855
      ; b = 0.7931
      ; c = -0.1682
      ; (* P_O3'_60_tfo *)
        d = 0.8103
      ; e = -0.5790
      ; f = 0.0906
      ; g = -0.0255
      ; h = -0.1894
      ; i = -0.9816
      ; tx = 6.1203
      ; ty = -7.1051
      ; tz = 3.1984
    }
    , { x = 2.6760; y = -8.4960; z = 3.2880 }
      , (* P    *)
      { x = 1.4950; y = -7.6230; z = 3.4770 }
      , (* O1P  *)
      { x = 2.9490; y = -9.4640; z = 4.3740 }
      , (* O2P  *)
      { x = 3.9730; y = -7.5950; z = 3.0340 }
      , (* O5'  *)
      { x = 3.9938; y = -6.7042; z = 1.9023 }
      , (* C5'  *)
      { x = 3.2332; y = -5.9343; z = 2.0319 }
      , (* H5'  *)
      { x = 3.9666; y = -7.2863; z = 0.9812 }
      , (* H5'' *)
      { x = 5.3098; y = -5.9546; z = 1.8564 }
      , (* C4'  *)
      { x = 5.3863; y = -5.3702; z = 0.9395 }
      , (* H4'  *)
      { x = 5.3851; y = -5.0642; z = 3.0076 }
      , (* O4'  *)
      { x = 6.7315; y = -4.9724; z = 3.4462 }
      , (* C1'  *)
      { x = 7.0033; y = -3.9202; z = 3.3619 }
      , (* H1'  *)
      { x = 7.5997; y = -5.8018; z = 2.4948 }
      , (* C2'  *)
      { x = 8.3627; y = -6.3254; z = 3.0707 }
      , (* H2'' *)
      { x = 8.0410; y = -4.9501; z = 1.4724 }
      , (* O2'  *)
      { x = 8.2781; y = -4.0644; z = 1.7570 }
      , (* H2'  *)
      { x = 6.5701; y = -6.8129; z = 1.9714 }
      , (* C3'  *)
      { x = 6.4186; y = -7.5809; z = 2.7299 }
      , (* H3'  *)
      { x = 6.9357; y = -7.3841; z = 0.7235 }
      , (* O3'  *)
      { x = 6.8024; y = -5.4718; z = 4.8475 }
      , (* N1   *)
      { x = 6.6920; y = -5.0495; z = 7.1354 }
      , (* N3   *)
      { x = 6.6201; y = -4.5500; z = 5.8506 }
      , (* C2   *)
      { x = 6.9254; y = -6.3614; z = 7.4926 }
      , (* C4   *)
      { x = 7.1046; y = -7.2543; z = 6.3718 }
      , (* C5   *)
      { x = 7.0391; y = -6.7951; z = 5.1106 }
      , (* C6 *)
      C
        ( { x = 6.9614; y = -6.6648; z = 8.7815 }
          , (* N4   *)
          { x = 6.4083; y = -3.3696; z = 5.6340 }
          , (* O2   *)
          { x = 7.1329; y = -7.6280; z = 9.0324 }
          , (* H41  *)
          { x = 6.8204; y = -5.9469; z = 9.4777 }
          , (* H42  *)
          { x = 7.2954; y = -8.3135; z = 6.5440 }
          , (* H5   *)
          { x = 7.1753; y = -7.4798; z = 4.2735 } ) )

(* H6   *)

let rC07 =
  N
    ( { a = 0.0033
      ; b = 0.2720
      ; c = -0.9623
      ; (* dgf_base_tfo *)
        d = 0.3013
      ; e = -0.9179
      ; f = -0.2584
      ; g = -0.9535
      ; h = -0.2891
      ; i = -0.0850
      ; tx = 43.0403
      ; ty = 13.7233
      ; tz = 34.5710
    }
    , { a = 0.9187
      ; b = 0.2887
      ; c = 0.2694
      ; (* P_O3'_275_tfo *)
        d = 0.0302
      ; e = -0.7316
      ; f = 0.6811
      ; g = 0.3938
      ; h = -0.6176
      ; i = -0.6808
      ; tx = -48.4330
      ; ty = 26.3254
      ; tz = 13.6383
    }
    , { a = -0.1504
      ; b = 0.7744
      ; c = -0.6145
      ; (* P_O3'_180_tfo *)
        d = 0.7581
      ; e = 0.4893
      ; f = 0.4311
      ; g = 0.6345
      ; h = -0.4010
      ; i = -0.6607
      ; tx = -31.9784
      ; ty = -13.4285
      ; tz = 44.9650
    }
    , { a = -0.6236
      ; b = -0.7810
      ; c = -0.0337
      ; (* P_O3'_60_tfo *)
        d = -0.6890
      ; e = 0.5694
      ; f = -0.4484
      ; g = 0.3694
      ; h = -0.2564
      ; i = -0.8932
      ; tx = 12.1105
      ; ty = 30.8774
      ; tz = 46.0946
    }
    , { x = 33.3400; y = 11.0980; z = 46.1750 }
      , (* P    *)
      { x = 34.5130; y = 10.2320; z = 46.4660 }
      , (* O1P  *)
      { x = 33.4130; y = 12.3960; z = 46.9340 }
      , (* O2P  *)
      { x = 31.9810; y = 10.3390; z = 46.4820 }
      , (* O5'  *)
      { x = 30.8152; y = 11.1619; z = 46.2003 }
      , (* C5'  *)
      { x = 30.4519; y = 10.9454; z = 45.1957 }
      , (* H5'  *)
      { x = 31.0379; y = 12.2016; z = 46.4400 }
      , (* H5'' *)
      { x = 29.7081; y = 10.7448; z = 47.1428 }
      , (* C4'  *)
      { x = 28.8710; y = 11.4416; z = 47.0982 }
      , (* H4'  *)
      { x = 29.2550; y = 9.4394; z = 46.8162 }
      , (* O4'  *)
      { x = 29.3907; y = 8.5625; z = 47.9460 }
      , (* C1'  *)
      { x = 28.4416; y = 8.5669; z = 48.4819 }
      , (* H1'  *)
      { x = 30.4468; y = 9.2031; z = 48.7952 }
      , (* C2'  *)
      { x = 31.4222; y = 8.9651; z = 48.3709 }
      , (* H2'' *)
      { x = 30.3701; y = 8.9157; z = 50.1624 }
      , (* O2'  *)
      { x = 30.0652; y = 8.0304; z = 50.3740 }
      , (* H2'  *)
      { x = 30.1622; y = 10.6879; z = 48.6120 }
      , (* C3'  *)
      { x = 31.0952; y = 11.2399; z = 48.7254 }
      , (* H3'  *)
      { x = 29.1076; y = 11.1535; z = 49.4702 }
      , (* O3'  *)
      { x = 29.7883; y = 7.2209; z = 47.5235 }
      , (* N1   *)
      { x = 29.1825; y = 5.0438; z = 46.8275 }
      , (* N3   *)
      { x = 28.8008; y = 6.2912; z = 47.2263 }
      , (* C2   *)
      { x = 30.4888; y = 4.6890; z = 46.7186 }
      , (* C4   *)
      { x = 31.5034; y = 5.6405; z = 47.0249 }
      , (* C5   *)
      { x = 31.1091; y = 6.8691; z = 47.4156 }
      , (* C6 *)
      C
        ( { x = 30.8109; y = 3.4584; z = 46.3336 }
          , (* N4   *)
          { x = 27.6171; y = 6.5989; z = 47.3189 }
          , (* O2   *)
          { x = 31.7923; y = 3.2301; z = 46.2638 }
          , (* H41  *)
          { x = 30.0880; y = 2.7857; z = 46.1215 }
          , (* H42  *)
          { x = 32.5542; y = 5.3634; z = 46.9395 }
          , (* H5   *)
          { x = 31.8523; y = 7.6279; z = 47.6603 } ) )

(* H6   *)

let rC08 =
  N
    ( { a = 0.0797
      ; b = -0.6026
      ; c = -0.7941
      ; (* dgf_base_tfo *)
        d = 0.7939
      ; e = 0.5201
      ; f = -0.3150
      ; g = 0.6028
      ; h = -0.6054
      ; i = 0.5198
      ; tx = -36.8341
      ; ty = 41.5293
      ; tz = 1.6628
    }
    , { a = 0.9187
      ; b = 0.2887
      ; c = 0.2694
      ; (* P_O3'_275_tfo *)
        d = 0.0302
      ; e = -0.7316
      ; f = 0.6811
      ; g = 0.3938
      ; h = -0.6176
      ; i = -0.6808
      ; tx = -48.4330
      ; ty = 26.3254
      ; tz = 13.6383
    }
    , { a = -0.1504
      ; b = 0.7744
      ; c = -0.6145
      ; (* P_O3'_180_tfo *)
        d = 0.7581
      ; e = 0.4893
      ; f = 0.4311
      ; g = 0.6345
      ; h = -0.4010
      ; i = -0.6607
      ; tx = -31.9784
      ; ty = -13.4285
      ; tz = 44.9650
    }
    , { a = -0.6236
      ; b = -0.7810
      ; c = -0.0337
      ; (* P_O3'_60_tfo *)
        d = -0.6890
      ; e = 0.5694
      ; f = -0.4484
      ; g = 0.3694
      ; h = -0.2564
      ; i = -0.8932
      ; tx = 12.1105
      ; ty = 30.8774
      ; tz = 46.0946
    }
    , { x = 33.3400; y = 11.0980; z = 46.1750 }
      , (* P    *)
      { x = 34.5130; y = 10.2320; z = 46.4660 }
      , (* O1P  *)
      { x = 33.4130; y = 12.3960; z = 46.9340 }
      , (* O2P  *)
      { x = 31.9810; y = 10.3390; z = 46.4820 }
      , (* O5'  *)
      { x = 31.8779; y = 9.9369; z = 47.8760 }
      , (* C5'  *)
      { x = 31.3239; y = 10.6931; z = 48.4322 }
      , (* H5'  *)
      { x = 32.8647; y = 9.6624; z = 48.2489 }
      , (* H5'' *)
      { x = 31.0429; y = 8.6773; z = 47.9401 }
      , (* C4'  *)
      { x = 31.0779; y = 8.2331; z = 48.9349 }
      , (* H4'  *)
      { x = 29.6956; y = 8.9669; z = 47.5983 }
      , (* O4'  *)
      { x = 29.2784; y = 8.1700; z = 46.4782 }
      , (* C1'  *)
      { x = 28.8006; y = 7.2731; z = 46.8722 }
      , (* H1'  *)
      { x = 30.5544; y = 7.7940; z = 45.7875 }
      , (* C2'  *)
      { x = 30.8837; y = 8.6410; z = 45.1856 }
      , (* H2'' *)
      { x = 30.5100; y = 6.6007; z = 45.0582 }
      , (* O2'  *)
      { x = 29.6694; y = 6.4168; z = 44.6326 }
      , (* H2'  *)
      { x = 31.5146; y = 7.5954; z = 46.9527 }
      , (* C3'  *)
      { x = 32.5255; y = 7.8261; z = 46.6166 }
      , (* H3'  *)
      { x = 31.3876; y = 6.2951; z = 47.5516 }
      , (* O3'  *)
      { x = 28.3976; y = 8.9302; z = 45.5933 }
      , (* N1   *)
      { x = 26.2155; y = 9.6135; z = 44.9910 }
      , (* N3   *)
      { x = 27.0281; y = 8.8961; z = 45.8192 }
      , (* C2   *)
      { x = 26.7044; y = 10.3489; z = 43.9595 }
      , (* C4   *)
      { x = 28.1088; y = 10.3837; z = 43.7247 }
      , (* C5   *)
      { x = 28.8978; y = 9.6708; z = 44.5535 }
      , (* C6 *)
      C
        ( { x = 25.8715; y = 11.0249; z = 43.1749 }
          , (* N4   *)
          { x = 26.5733; y = 8.2371; z = 46.7484 }
          , (* O2   *)
          { x = 26.2707; y = 11.5609; z = 42.4177 }
          , (* H41  *)
          { x = 24.8760; y = 10.9939; z = 43.3427 }
          , (* H42  *)
          { x = 28.5089; y = 10.9722; z = 42.8990 }
          , (* H5   *)
          { x = 29.9782; y = 9.6687; z = 44.4097 } ) )

(* H6   *)

let rC09 =
  N
    ( { a = 0.8727
      ; b = 0.4760
      ; c = -0.1091
      ; (* dgf_base_tfo *)
        d = -0.4188
      ; e = 0.6148
      ; f = -0.6682
      ; g = -0.2510
      ; h = 0.6289
      ; i = 0.7359
      ; tx = -8.1687
      ; ty = -52.0761
      ; tz = -25.0726
    }
    , { a = 0.9187
      ; b = 0.2887
      ; c = 0.2694
      ; (* P_O3'_275_tfo *)
        d = 0.0302
      ; e = -0.7316
      ; f = 0.6811
      ; g = 0.3938
      ; h = -0.6176
      ; i = -0.6808
      ; tx = -48.4330
      ; ty = 26.3254
      ; tz = 13.6383
    }
    , { a = -0.1504
      ; b = 0.7744
      ; c = -0.6145
      ; (* P_O3'_180_tfo *)
        d = 0.7581
      ; e = 0.4893
      ; f = 0.4311
      ; g = 0.6345
      ; h = -0.4010
      ; i = -0.6607
      ; tx = -31.9784
      ; ty = -13.4285
      ; tz = 44.9650
    }
    , { a = -0.6236
      ; b = -0.7810
      ; c = -0.0337
      ; (* P_O3'_60_tfo *)
        d = -0.6890
      ; e = 0.5694
      ; f = -0.4484
      ; g = 0.3694
      ; h = -0.2564
      ; i = -0.8932
      ; tx = 12.1105
      ; ty = 30.8774
      ; tz = 46.0946
    }
    , { x = 33.3400; y = 11.0980; z = 46.1750 }
      , (* P    *)
      { x = 34.5130; y = 10.2320; z = 46.4660 }
      , (* O1P  *)
      { x = 33.4130; y = 12.3960; z = 46.9340 }
      , (* O2P  *)
      { x = 31.9810; y = 10.3390; z = 46.4820 }
      , (* O5'  *)
      { x = 30.8152; y = 11.1619; z = 46.2003 }
      , (* C5'  *)
      { x = 30.4519; y = 10.9454; z = 45.1957 }
      , (* H5'  *)
      { x = 31.0379; y = 12.2016; z = 46.4400 }
      , (* H5'' *)
      { x = 29.7081; y = 10.7448; z = 47.1428 }
      , (* C4'  *)
      { x = 29.4506; y = 9.6945; z = 47.0059 }
      , (* H4'  *)
      { x = 30.1045; y = 10.9634; z = 48.4885 }
      , (* O4'  *)
      { x = 29.1794; y = 11.8418; z = 49.1490 }
      , (* C1'  *)
      { x = 28.4388; y = 11.2210; z = 49.6533 }
      , (* H1'  *)
      { x = 28.5211; y = 12.6008; z = 48.0367 }
      , (* C2'  *)
      { x = 29.1947; y = 13.3949; z = 47.7147 }
      , (* H2'' *)
      { x = 27.2316; y = 13.0683; z = 48.3134 }
      , (* O2'  *)
      { x = 27.0851; y = 13.3391; z = 49.2227 }
      , (* H2'  *)
      { x = 28.4131; y = 11.5507; z = 46.9391 }
      , (* C3'  *)
      { x = 28.4451; y = 12.0512; z = 45.9713 }
      , (* H3'  *)
      { x = 27.2707; y = 10.6955; z = 47.1097 }
      , (* O3'  *)
      { x = 29.8751; y = 12.7405; z = 50.0682 }
      , (* N1   *)
      { x = 30.7172; y = 13.1841; z = 52.2328 }
      , (* N3   *)
      { x = 30.0617; y = 12.3404; z = 51.3847 }
      , (* C2   *)
      { x = 31.1834; y = 14.3941; z = 51.8297 }
      , (* C4   *)
      { x = 30.9913; y = 14.8074; z = 50.4803 }
      , (* C5   *)
      { x = 30.3434; y = 13.9610; z = 49.6548 }
      , (* C6 *)
      C
        ( { x = 31.8090; y = 15.1847; z = 52.6957 }
          , (* N4   *)
          { x = 29.6470; y = 11.2494; z = 51.7616 }
          , (* O2   *)
          { x = 32.1422; y = 16.0774; z = 52.3606 }
          , (* H41  *)
          { x = 31.9392; y = 14.8893; z = 53.6527 }
          , (* H42  *)
          { x = 31.3632; y = 15.7771; z = 50.1491 }
          , (* H5   *)
          { x = 30.1742; y = 14.2374; z = 48.6141 } ) )

(* H6   *)

let rC10 =
  N
    ( { a = 0.1549
      ; b = 0.8710
      ; c = -0.4663
      ; (* dgf_base_tfo *)
        d = 0.6768
      ; e = -0.4374
      ; f = -0.5921
      ; g = -0.7197
      ; h = -0.2239
      ; i = -0.6572
      ; tx = 25.2447
      ; ty = -14.1920
      ; tz = 50.3201
    }
    , { a = 0.9187
      ; b = 0.2887
      ; c = 0.2694
      ; (* P_O3'_275_tfo *)
        d = 0.0302
      ; e = -0.7316
      ; f = 0.6811
      ; g = 0.3938
      ; h = -0.6176
      ; i = -0.6808
      ; tx = -48.4330
      ; ty = 26.3254
      ; tz = 13.6383
    }
    , { a = -0.1504
      ; b = 0.7744
      ; c = -0.6145
      ; (* P_O3'_180_tfo *)
        d = 0.7581
      ; e = 0.4893
      ; f = 0.4311
      ; g = 0.6345
      ; h = -0.4010
      ; i = -0.6607
      ; tx = -31.9784
      ; ty = -13.4285
      ; tz = 44.9650
    }
    , { a = -0.6236
      ; b = -0.7810
      ; c = -0.0337
      ; (* P_O3'_60_tfo *)
        d = -0.6890
      ; e = 0.5694
      ; f = -0.4484
      ; g = 0.3694
      ; h = -0.2564
      ; i = -0.8932
      ; tx = 12.1105
      ; ty = 30.8774
      ; tz = 46.0946
    }
    , { x = 33.3400; y = 11.0980; z = 46.1750 }
      , (* P    *)
      { x = 34.5130; y = 10.2320; z = 46.4660 }
      , (* O1P  *)
      { x = 33.4130; y = 12.3960; z = 46.9340 }
      , (* O2P  *)
      { x = 31.9810; y = 10.3390; z = 46.4820 }
      , (* O5'  *)
      { x = 31.8779; y = 9.9369; z = 47.8760 }
      , (* C5'  *)
      { x = 31.3239; y = 10.6931; z = 48.4322 }
      , (* H5'  *)
      { x = 32.8647; y = 9.6624; z = 48.2489 }
      , (* H5'' *)
      { x = 31.0429; y = 8.6773; z = 47.9401 }
      , (* C4'  *)
      { x = 30.0440; y = 8.8473; z = 47.5383 }
      , (* H4'  *)
      { x = 31.6749; y = 7.6351; z = 47.2119 }
      , (* O4'  *)
      { x = 31.9159; y = 6.5022; z = 48.0616 }
      , (* C1'  *)
      { x = 31.0691; y = 5.8243; z = 47.9544 }
      , (* H1'  *)
      { x = 31.9300; y = 7.0685; z = 49.4493 }
      , (* C2'  *)
      { x = 32.9024; y = 7.5288; z = 49.6245 }
      , (* H2'' *)
      { x = 31.5672; y = 6.1750; z = 50.4632 }
      , (* O2'  *)
      { x = 31.8416; y = 5.2663; z = 50.3200 }
      , (* H2'  *)
      { x = 30.8618; y = 8.1514; z = 49.3749 }
      , (* C3'  *)
      { x = 31.1122; y = 8.9396; z = 50.0850 }
      , (* H3'  *)
      { x = 29.5351; y = 7.6245; z = 49.5409 }
      , (* O3'  *)
      { x = 33.1890; y = 5.8629; z = 47.7343 }
      , (* N1   *)
      { x = 34.4004; y = 4.2636; z = 46.4828 }
      , (* N3   *)
      { x = 33.2062; y = 4.8497; z = 46.7851 }
      , (* C2   *)
      { x = 35.5600; y = 4.6374; z = 47.0822 }
      , (* C4   *)
      { x = 35.5444; y = 5.6751; z = 48.0577 }
      , (* C5   *)
      { x = 34.3565; y = 6.2450; z = 48.3432 }
      , (* C6 *)
      C
        ( { x = 36.6977; y = 4.0305; z = 46.7598 }
          , (* N4   *)
          { x = 32.1661; y = 4.5034; z = 46.2348 }
          , (* O2   *)
          { x = 37.5405; y = 4.3347; z = 47.2259 }
          , (* H41  *)
          { x = 36.7033; y = 3.2923; z = 46.0706 }
          , (* H42  *)
          { x = 36.4713; y = 5.9811; z = 48.5428 }
          , (* H5   *)
          { x = 34.2986; y = 7.0426; z = 49.0839 } ) )

(* H6   *)

let rCs = [ rC01; rC02; rC03; rC04; rC05; rC06; rC07; rC08; rC09; rC10 ]

let rG =
  N
    ( { a = -0.0018
      ; b = -0.8207
      ; c = 0.5714
      ; (* dgf_base_tfo *)
        d = 0.2679
      ; e = -0.5509
      ; f = -0.7904
      ; g = 0.9634
      ; h = 0.1517
      ; i = 0.2209
      ; tx = 0.0073
      ; ty = 8.4030
      ; tz = 0.6232
    }
    , { a = -0.8143
      ; b = -0.5091
      ; c = -0.2788
      ; (* P_O3'_275_tfo *)
        d = -0.0433
      ; e = -0.4257
      ; f = 0.9038
      ; g = -0.5788
      ; h = 0.7480
      ; i = 0.3246
      ; tx = 1.5227
      ; ty = 6.9114
      ; tz = -7.0765
    }
    , { a = 0.3822
      ; b = -0.7477
      ; c = 0.5430
      ; (* P_O3'_180_tfo *)
        d = 0.4552
      ; e = 0.6637
      ; f = 0.5935
      ; g = -0.8042
      ; h = 0.0203
      ; i = 0.5941
      ; tx = -6.9472
      ; ty = -4.1186
      ; tz = -5.9108
    }
    , { a = 0.5640
      ; b = 0.8007
      ; c = -0.2022
      ; (* P_O3'_60_tfo *)
        d = -0.8247
      ; e = 0.5587
      ; f = -0.0878
      ; g = 0.0426
      ; h = 0.2162
      ; i = 0.9754
      ; tx = 6.2694
      ; ty = -7.0540
      ; tz = 3.3316
    }
    , { x = 2.8930; y = 8.5380; z = -3.3280 }
      , (* P    *)
      { x = 1.6980; y = 7.6960; z = -3.5570 }
      , (* O1P  *)
      { x = 3.2260; y = 9.5010; z = -4.4020 }
      , (* O2P  *)
      { x = 4.1590; y = 7.6040; z = -3.0340 }
      , (* O5'  *)
      { x = 5.4550; y = 8.2120; z = -2.8810 }
      , (* C5'  *)
      { x = 5.4546; y = 8.8508; z = -1.9978 }
      , (* H5'  *)
      { x = 5.7588; y = 8.6625; z = -3.8259 }
      , (* H5'' *)
      { x = 6.4970; y = 7.1480; z = -2.5980 }
      , (* C4'  *)
      { x = 7.4896; y = 7.5919; z = -2.5214 }
      , (* H4'  *)
      { x = 6.1630; y = 6.4860; z = -1.3440 }
      , (* O4'  *)
      { x = 6.5400; y = 5.1200; z = -1.4190 }
      , (* C1'  *)
      { x = 7.2763; y = 4.9681; z = -0.6297 }
      , (* H1'  *)
      { x = 7.1940; y = 4.8830; z = -2.7770 }
      , (* C2'  *)
      { x = 6.8667; y = 3.9183; z = -3.1647 }
      , (* H2'' *)
      { x = 8.5860; y = 5.0910; z = -2.6140 }
      , (* O2'  *)
      { x = 8.9510; y = 4.7626; z = -1.7890 }
      , (* H2'  *)
      { x = 6.5720; y = 6.0040; z = -3.6090 }
      , (* C3'  *)
      { x = 5.5636; y = 5.7066; z = -3.8966 }
      , (* H3'  *)
      { x = 7.3801; y = 6.3562; z = -4.7350 }
      , (* O3'  *)
      { x = 4.7150; y = 0.4910; z = -0.1360 }
      , (* N1   *)
      { x = 6.3490; y = 2.1730; z = -0.6020 }
      , (* N3   *)
      { x = 5.9530; y = 0.9650; z = -0.2670 }
      , (* C2   *)
      { x = 5.2900; y = 2.9790; z = -0.8260 }
      , (* C4   *)
      { x = 3.9720; y = 2.6390; z = -0.7330 }
      , (* C5   *)
      { x = 3.6770; y = 1.3160; z = -0.3660 }
      , (* C6 *)
      G
        ( { x = 6.8426; y = 0.0056; z = -0.0019 }
          , (* N2   *)
          { x = 3.1660; y = 3.7290; z = -1.0360 }
          , (* N7   *)
          { x = 5.3170; y = 4.2990; z = -1.1930 }
          , (* N9   *)
          { x = 4.0100; y = 4.6780; z = -1.2990 }
          , (* C8   *)
          { x = 2.4280; y = 0.8450; z = -0.2360 }
          , (* O6   *)
          { x = 4.6151; y = -0.4677; z = 0.1305 }
          , (* H1   *)
          { x = 6.6463; y = -0.9463; z = 0.2729 }
          , (* H21  *)
          { x = 7.8170; y = 0.2642; z = -0.0640 }
          , (* H22  *)
          { x = 3.4421; y = 5.5744; z = -1.5482 } ) )

(* H8   *)

let rG01 =
  N
    ( { a = -0.0043
      ; b = -0.8175
      ; c = 0.5759
      ; (* dgf_base_tfo *)
        d = 0.2617
      ; e = -0.5567
      ; f = -0.7884
      ; g = 0.9651
      ; h = 0.1473
      ; i = 0.2164
      ; tx = 0.0359
      ; ty = 8.3929
      ; tz = 0.5532
    }
    , { a = -0.8143
      ; b = -0.5091
      ; c = -0.2788
      ; (* P_O3'_275_tfo *)
        d = -0.0433
      ; e = -0.4257
      ; f = 0.9038
      ; g = -0.5788
      ; h = 0.7480
      ; i = 0.3246
      ; tx = 1.5227
      ; ty = 6.9114
      ; tz = -7.0765
    }
    , { a = 0.3822
      ; b = -0.7477
      ; c = 0.5430
      ; (* P_O3'_180_tfo *)
        d = 0.4552
      ; e = 0.6637
      ; f = 0.5935
      ; g = -0.8042
      ; h = 0.0203
      ; i = 0.5941
      ; tx = -6.9472
      ; ty = -4.1186
      ; tz = -5.9108
    }
    , { a = 0.5640
      ; b = 0.8007
      ; c = -0.2022
      ; (* P_O3'_60_tfo *)
        d = -0.8247
      ; e = 0.5587
      ; f = -0.0878
      ; g = 0.0426
      ; h = 0.2162
      ; i = 0.9754
      ; tx = 6.2694
      ; ty = -7.0540
      ; tz = 3.3316
    }
    , { x = 2.8930; y = 8.5380; z = -3.3280 }
      , (* P    *)
      { x = 1.6980; y = 7.6960; z = -3.5570 }
      , (* O1P  *)
      { x = 3.2260; y = 9.5010; z = -4.4020 }
      , (* O2P  *)
      { x = 4.1590; y = 7.6040; z = -3.0340 }
      , (* O5'  *)
      { x = 5.4352; y = 8.2183; z = -2.7757 }
      , (* C5'  *)
      { x = 5.3830; y = 8.7883; z = -1.8481 }
      , (* H5'  *)
      { x = 5.7729; y = 8.7436; z = -3.6691 }
      , (* H5'' *)
      { x = 6.4830; y = 7.1518; z = -2.5252 }
      , (* C4'  *)
      { x = 7.4749; y = 7.5972; z = -2.4482 }
      , (* H4'  *)
      { x = 6.1626; y = 6.4620; z = -1.2827 }
      , (* O4'  *)
      { x = 6.5431; y = 5.0992; z = -1.3905 }
      , (* C1'  *)
      { x = 7.2871; y = 4.9328; z = -0.6114 }
      , (* H1'  *)
      { x = 7.1852; y = 4.8935; z = -2.7592 }
      , (* C2'  *)
      { x = 6.8573; y = 3.9363; z = -3.1645 }
      , (* H2'' *)
      { x = 8.5780; y = 5.1025; z = -2.6046 }
      , (* O2'  *)
      { x = 8.9516; y = 4.7577; z = -1.7902 }
      , (* H2'  *)
      { x = 6.5522; y = 6.0300; z = -3.5612 }
      , (* C3'  *)
      { x = 5.5420; y = 5.7356; z = -3.8459 }
      , (* H3'  *)
      { x = 7.3487; y = 6.4089; z = -4.6867 }
      , (* O3'  *)
      { x = 4.7442; y = 0.4514; z = -0.1390 }
      , (* N1   *)
      { x = 6.3687; y = 2.1459; z = -0.5926 }
      , (* N3   *)
      { x = 5.9795; y = 0.9335; z = -0.2657 }
      , (* C2   *)
      { x = 5.3052; y = 2.9471; z = -0.8125 }
      , (* C4   *)
      { x = 3.9891; y = 2.5987; z = -0.7230 }
      , (* C5   *)
      { x = 3.7016; y = 1.2717; z = -0.3647 }
      , (* C6 *)
      G
        ( { x = 6.8745; y = -0.0224; z = -0.0058 }
          , (* N2   *)
          { x = 3.1770; y = 3.6859; z = -1.0198 }
          , (* N7   *)
          { x = 5.3247; y = 4.2695; z = -1.1710 }
          , (* N9   *)
          { x = 4.0156; y = 4.6415; z = -1.2759 }
          , (* C8   *)
          { x = 2.4553; y = 0.7925; z = -0.2390 }
          , (* O6   *)
          { x = 4.6497; y = -0.5095; z = 0.1212 }
          , (* H1   *)
          { x = 6.6836; y = -0.9771; z = 0.2627 }
          , (* H21  *)
          { x = 7.8474; y = 0.2424; z = -0.0653 }
          , (* H22  *)
          { x = 3.4426; y = 5.5361; z = -1.5199 } ) )

(* H8   *)

let rG02 =
  N
    ( { a = 0.5566
      ; b = 0.0449
      ; c = 0.8296
      ; (* dgf_base_tfo *)
        d = 0.5125
      ; e = 0.7673
      ; f = -0.3854
      ; g = -0.6538
      ; h = 0.6397
      ; i = 0.4041
      ; tx = -9.1161
      ; ty = -3.7679
      ; tz = -2.9968
    }
    , { a = -0.8143
      ; b = -0.5091
      ; c = -0.2788
      ; (* P_O3'_275_tfo *)
        d = -0.0433
      ; e = -0.4257
      ; f = 0.9038
      ; g = -0.5788
      ; h = 0.7480
      ; i = 0.3246
      ; tx = 1.5227
      ; ty = 6.9114
      ; tz = -7.0765
    }
    , { a = 0.3822
      ; b = -0.7477
      ; c = 0.5430
      ; (* P_O3'_180_tfo *)
        d = 0.4552
      ; e = 0.6637
      ; f = 0.5935
      ; g = -0.8042
      ; h = 0.0203
      ; i = 0.5941
      ; tx = -6.9472
      ; ty = -4.1186
      ; tz = -5.9108
    }
    , { a = 0.5640
      ; b = 0.8007
      ; c = -0.2022
      ; (* P_O3'_60_tfo *)
        d = -0.8247
      ; e = 0.5587
      ; f = -0.0878
      ; g = 0.0426
      ; h = 0.2162
      ; i = 0.9754
      ; tx = 6.2694
      ; ty = -7.0540
      ; tz = 3.3316
    }
    , { x = 2.8930; y = 8.5380; z = -3.3280 }
      , (* P    *)
      { x = 1.6980; y = 7.6960; z = -3.5570 }
      , (* O1P  *)
      { x = 3.2260; y = 9.5010; z = -4.4020 }
      , (* O2P  *)
      { x = 4.1590; y = 7.6040; z = -3.0340 }
      , (* O5'  *)
      { x = 4.5778; y = 6.6594; z = -4.0364 }
      , (* C5'  *)
      { x = 4.9220; y = 7.1963; z = -4.9204 }
      , (* H5'  *)
      { x = 3.7996; y = 5.9091; z = -4.1764 }
      , (* H5'' *)
      { x = 5.7873; y = 5.8869; z = -3.5482 }
      , (* C4'  *)
      { x = 6.0405; y = 5.0875; z = -4.2446 }
      , (* H4'  *)
      { x = 6.9135; y = 6.8036; z = -3.4310 }
      , (* O4'  *)
      { x = 7.7293; y = 6.4084; z = -2.3392 }
      , (* C1'  *)
      { x = 8.7078; y = 6.1815; z = -2.7624 }
      , (* H1'  *)
      { x = 7.1305; y = 5.1418; z = -1.7347 }
      , (* C2'  *)
      { x = 7.2040; y = 5.1982; z = -0.6486 }
      , (* H2'' *)
      { x = 7.7417; y = 4.0392; z = -2.3813 }
      , (* O2'  *)
      { x = 8.6785; y = 4.1443; z = -2.5630 }
      , (* H2'  *)
      { x = 5.6666; y = 5.2728; z = -2.1536 }
      , (* C3'  *)
      { x = 5.1747; y = 5.9805; z = -1.4863 }
      , (* H3'  *)
      { x = 4.9997; y = 4.0086; z = -2.1973 }
      , (* O3'  *)
      { x = 10.3245; y = 8.5459; z = 1.5467 }
      , (* N1   *)
      { x = 9.8051; y = 6.9432; z = -0.1497 }
      , (* N3   *)
      { x = 10.5175; y = 7.4328; z = 0.8408 }
      , (* C2   *)
      { x = 8.7523; y = 7.7422; z = -0.4228 }
      , (* C4   *)
      { x = 8.4257; y = 8.9060; z = 0.2099 }
      , (* C5   *)
      { x = 9.2665; y = 9.3242; z = 1.2540 }
      , (* C6 *)
      G
        ( { x = 11.6077; y = 6.7966; z = 1.2752 }
          , (* N2   *)
          { x = 7.2750; y = 9.4537; z = -0.3428 }
          , (* N7   *)
          { x = 7.7962; y = 7.5519; z = -1.3859 }
          , (* N9   *)
          { x = 6.9479; y = 8.6157; z = -1.2771 }
          , (* C8   *)
          { x = 9.0664; y = 10.4462; z = 1.9610 }
          , (* O6   *)
          { x = 10.9838; y = 8.7524; z = 2.2697 }
          , (* H1   *)
          { x = 12.2274; y = 7.0896; z = 2.0170 }
          , (* H21  *)
          { x = 11.8502; y = 5.9398; z = 0.7984 }
          , (* H22  *)
          { x = 6.0430; y = 8.9853; z = -1.7594 } ) )

(* H8   *)

let rG03 =
  N
    ( { a = -0.5021
      ; b = 0.0731
      ; c = 0.8617
      ; (* dgf_base_tfo *)
        d = -0.8112
      ; e = 0.3054
      ; f = -0.4986
      ; g = -0.2996
      ; h = -0.9494
      ; i = -0.0940
      ; tx = 6.4273
      ; ty = -5.1944
      ; tz = -3.7807
    }
    , { a = -0.8143
      ; b = -0.5091
      ; c = -0.2788
      ; (* P_O3'_275_tfo *)
        d = -0.0433
      ; e = -0.4257
      ; f = 0.9038
      ; g = -0.5788
      ; h = 0.7480
      ; i = 0.3246
      ; tx = 1.5227
      ; ty = 6.9114
      ; tz = -7.0765
    }
    , { a = 0.3822
      ; b = -0.7477
      ; c = 0.5430
      ; (* P_O3'_180_tfo *)
        d = 0.4552
      ; e = 0.6637
      ; f = 0.5935
      ; g = -0.8042
      ; h = 0.0203
      ; i = 0.5941
      ; tx = -6.9472
      ; ty = -4.1186
      ; tz = -5.9108
    }
    , { a = 0.5640
      ; b = 0.8007
      ; c = -0.2022
      ; (* P_O3'_60_tfo *)
        d = -0.8247
      ; e = 0.5587
      ; f = -0.0878
      ; g = 0.0426
      ; h = 0.2162
      ; i = 0.9754
      ; tx = 6.2694
      ; ty = -7.0540
      ; tz = 3.3316
    }
    , { x = 2.8930; y = 8.5380; z = -3.3280 }
      , (* P    *)
      { x = 1.6980; y = 7.6960; z = -3.5570 }
      , (* O1P  *)
      { x = 3.2260; y = 9.5010; z = -4.4020 }
      , (* O2P  *)
      { x = 4.1590; y = 7.6040; z = -3.0340 }
      , (* O5'  *)
      { x = 4.1214; y = 6.7116; z = -1.9049 }
      , (* C5'  *)
      { x = 3.3465; y = 5.9610; z = -2.0607 }
      , (* H5'  *)
      { x = 4.0789; y = 7.2928; z = -0.9837 }
      , (* H5'' *)
      { x = 5.4170; y = 5.9293; z = -1.8186 }
      , (* C4'  *)
      { x = 5.4506; y = 5.3400; z = -0.9023 }
      , (* H4'  *)
      { x = 5.5067; y = 5.0417; z = -2.9703 }
      , (* O4'  *)
      { x = 6.8650; y = 4.9152; z = -3.3612 }
      , (* C1'  *)
      { x = 7.1090; y = 3.8577; z = -3.2603 }
      , (* H1'  *)
      { x = 7.7152; y = 5.7282; z = -2.3894 }
      , (* C2'  *)
      { x = 8.5029; y = 6.2356; z = -2.9463 }
      , (* H2'' *)
      { x = 8.1036; y = 4.8568; z = -1.3419 }
      , (* O2'  *)
      { x = 8.3270; y = 3.9651; z = -1.6184 }
      , (* H2'  *)
      { x = 6.7003; y = 6.7565; z = -1.8911 }
      , (* C3'  *)
      { x = 6.5898; y = 7.5329; z = -2.6482 }
      , (* H3'  *)
      { x = 7.0505; y = 7.2878; z = -0.6105 }
      , (* O3'  *)
      { x = 9.6740; y = 4.7656; z = -7.6614 }
      , (* N1   *)
      { x = 9.0739; y = 4.3013; z = -5.3941 }
      , (* N3   *)
      { x = 9.8416; y = 4.2192; z = -6.4581 }
      , (* C2   *)
      { x = 7.9885; y = 5.0632; z = -5.6446 }
      , (* C4   *)
      { x = 7.6822; y = 5.6856; z = -6.8194 }
      , (* C5   *)
      { x = 8.5831; y = 5.5215; z = -7.8840 }
      , (* C6 *)
      G
        ( { x = 10.9733; y = 3.5117; z = -6.4286 }
          , (* N2   *)
          { x = 6.4857; y = 6.3816; z = -6.7035 }
          , (* N7   *)
          { x = 6.9740; y = 5.3703; z = -4.7760 }
          , (* N9   *)
          { x = 6.1133; y = 6.1613; z = -5.4808 }
          , (* C8   *)
          { x = 8.4084; y = 6.0747; z = -9.0933 }
          , (* O6   *)
          { x = 10.3759; y = 4.5855; z = -8.3504 }
          , (* H1   *)
          { x = 11.6254; y = 3.3761; z = -7.1879 }
          , (* H21  *)
          { x = 11.1917; y = 3.0460; z = -5.5593 }
          , (* H22  *)
          { x = 5.1705; y = 6.6830; z = -5.3167 } ) )

(* H8   *)

let rG04 =
  N
    ( { a = -0.5426
      ; b = -0.8175
      ; c = 0.1929
      ; (* dgf_base_tfo *)
        d = 0.8304
      ; e = -0.5567
      ; f = -0.0237
      ; g = 0.1267
      ; h = 0.1473
      ; i = 0.9809
      ; tx = -0.5075
      ; ty = 8.3929
      ; tz = 0.2229
    }
    , { a = -0.8143
      ; b = -0.5091
      ; c = -0.2788
      ; (* P_O3'_275_tfo *)
        d = -0.0433
      ; e = -0.4257
      ; f = 0.9038
      ; g = -0.5788
      ; h = 0.7480
      ; i = 0.3246
      ; tx = 1.5227
      ; ty = 6.9114
      ; tz = -7.0765
    }
    , { a = 0.3822
      ; b = -0.7477
      ; c = 0.5430
      ; (* P_O3'_180_tfo *)
        d = 0.4552
      ; e = 0.6637
      ; f = 0.5935
      ; g = -0.8042
      ; h = 0.0203
      ; i = 0.5941
      ; tx = -6.9472
      ; ty = -4.1186
      ; tz = -5.9108
    }
    , { a = 0.5640
      ; b = 0.8007
      ; c = -0.2022
      ; (* P_O3'_60_tfo *)
        d = -0.8247
      ; e = 0.5587
      ; f = -0.0878
      ; g = 0.0426
      ; h = 0.2162
      ; i = 0.9754
      ; tx = 6.2694
      ; ty = -7.0540
      ; tz = 3.3316
    }
    , { x = 2.8930; y = 8.5380; z = -3.3280 }
      , (* P    *)
      { x = 1.6980; y = 7.6960; z = -3.5570 }
      , (* O1P  *)
      { x = 3.2260; y = 9.5010; z = -4.4020 }
      , (* O2P  *)
      { x = 4.1590; y = 7.6040; z = -3.0340 }
      , (* O5'  *)
      { x = 5.4352; y = 8.2183; z = -2.7757 }
      , (* C5'  *)
      { x = 5.3830; y = 8.7883; z = -1.8481 }
      , (* H5'  *)
      { x = 5.7729; y = 8.7436; z = -3.6691 }
      , (* H5'' *)
      { x = 6.4830; y = 7.1518; z = -2.5252 }
      , (* C4'  *)
      { x = 7.4749; y = 7.5972; z = -2.4482 }
      , (* H4'  *)
      { x = 6.1626; y = 6.4620; z = -1.2827 }
      , (* O4'  *)
      { x = 6.5431; y = 5.0992; z = -1.3905 }
      , (* C1'  *)
      { x = 7.2871; y = 4.9328; z = -0.6114 }
      , (* H1'  *)
      { x = 7.1852; y = 4.8935; z = -2.7592 }
      , (* C2'  *)
      { x = 6.8573; y = 3.9363; z = -3.1645 }
      , (* H2'' *)
      { x = 8.5780; y = 5.1025; z = -2.6046 }
      , (* O2'  *)
      { x = 8.9516; y = 4.7577; z = -1.7902 }
      , (* H2'  *)
      { x = 6.5522; y = 6.0300; z = -3.5612 }
      , (* C3'  *)
      { x = 5.5420; y = 5.7356; z = -3.8459 }
      , (* H3'  *)
      { x = 7.3487; y = 6.4089; z = -4.6867 }
      , (* O3'  *)
      { x = 3.6343; y = 2.6680; z = 2.0783 }
      , (* N1   *)
      { x = 5.4505; y = 3.9805; z = 1.2446 }
      , (* N3   *)
      { x = 4.7540; y = 3.3816; z = 2.1851 }
      , (* C2   *)
      { x = 4.8805; y = 3.7951; z = 0.0354 }
      , (* C4   *)
      { x = 3.7416; y = 3.0925; z = -0.2305 }
      , (* C5   *)
      { x = 3.0873; y = 2.4980; z = 0.8606 }
      , (* C6 *)
      G
        ( { x = 5.1433; y = 3.4373; z = 3.4609 }
          , (* N2   *)
          { x = 3.4605; y = 3.1184; z = -1.5906 }
          , (* N7   *)
          { x = 5.3247; y = 4.2695; z = -1.1710 }
          , (* N9   *)
          { x = 4.4244; y = 3.8244; z = -2.0953 }
          , (* C8   *)
          { x = 1.9600; y = 1.7805; z = 0.7462 }
          , (* O6   *)
          { x = 3.2489; y = 2.2879; z = 2.9191 }
          , (* H1   *)
          { x = 4.6785; y = 3.0243; z = 4.2568 }
          , (* H21  *)
          { x = 5.9823; y = 3.9654; z = 3.6539 }
          , (* H22  *)
          { x = 4.2675; y = 3.8876; z = -3.1721 } ) )

(* H8   *)

let rG05 =
  N
    ( { a = -0.5891
      ; b = 0.0449
      ; c = 0.8068
      ; (* dgf_base_tfo *)
        d = 0.5375
      ; e = 0.7673
      ; f = 0.3498
      ; g = -0.6034
      ; h = 0.6397
      ; i = -0.4762
      ; tx = -0.3019
      ; ty = -3.7679
      ; tz = -9.5913
    }
    , { a = -0.8143
      ; b = -0.5091
      ; c = -0.2788
      ; (* P_O3'_275_tfo *)
        d = -0.0433
      ; e = -0.4257
      ; f = 0.9038
      ; g = -0.5788
      ; h = 0.7480
      ; i = 0.3246
      ; tx = 1.5227
      ; ty = 6.9114
      ; tz = -7.0765
    }
    , { a = 0.3822
      ; b = -0.7477
      ; c = 0.5430
      ; (* P_O3'_180_tfo *)
        d = 0.4552
      ; e = 0.6637
      ; f = 0.5935
      ; g = -0.8042
      ; h = 0.0203
      ; i = 0.5941
      ; tx = -6.9472
      ; ty = -4.1186
      ; tz = -5.9108
    }
    , { a = 0.5640
      ; b = 0.8007
      ; c = -0.2022
      ; (* P_O3'_60_tfo *)
        d = -0.8247
      ; e = 0.5587
      ; f = -0.0878
      ; g = 0.0426
      ; h = 0.2162
      ; i = 0.9754
      ; tx = 6.2694
      ; ty = -7.0540
      ; tz = 3.3316
    }
    , { x = 2.8930; y = 8.5380; z = -3.3280 }
      , (* P    *)
      { x = 1.6980; y = 7.6960; z = -3.5570 }
      , (* O1P  *)
      { x = 3.2260; y = 9.5010; z = -4.4020 }
      , (* O2P  *)
      { x = 4.1590; y = 7.6040; z = -3.0340 }
      , (* O5'  *)
      { x = 4.5778; y = 6.6594; z = -4.0364 }
      , (* C5'  *)
      { x = 4.9220; y = 7.1963; z = -4.9204 }
      , (* H5'  *)
      { x = 3.7996; y = 5.9091; z = -4.1764 }
      , (* H5'' *)
      { x = 5.7873; y = 5.8869; z = -3.5482 }
      , (* C4'  *)
      { x = 6.0405; y = 5.0875; z = -4.2446 }
      , (* H4'  *)
      { x = 6.9135; y = 6.8036; z = -3.4310 }
      , (* O4'  *)
      { x = 7.7293; y = 6.4084; z = -2.3392 }
      , (* C1'  *)
      { x = 8.7078; y = 6.1815; z = -2.7624 }
      , (* H1'  *)
      { x = 7.1305; y = 5.1418; z = -1.7347 }
      , (* C2'  *)
      { x = 7.2040; y = 5.1982; z = -0.6486 }
      , (* H2'' *)
      { x = 7.7417; y = 4.0392; z = -2.3813 }
      , (* O2'  *)
      { x = 8.6785; y = 4.1443; z = -2.5630 }
      , (* H2'  *)
      { x = 5.6666; y = 5.2728; z = -2.1536 }
      , (* C3'  *)
      { x = 5.1747; y = 5.9805; z = -1.4863 }
      , (* H3'  *)
      { x = 4.9997; y = 4.0086; z = -2.1973 }
      , (* O3'  *)
      { x = 10.2594; y = 10.6774; z = -1.0056 }
      , (* N1   *)
      { x = 9.7528; y = 8.7080; z = -2.2631 }
      , (* N3   *)
      { x = 10.4471; y = 9.7876; z = -1.9791 }
      , (* C2   *)
      { x = 8.7271; y = 8.5575; z = -1.3991 }
      , (* C4   *)
      { x = 8.4100; y = 9.3803; z = -0.3580 }
      , (* C5   *)
      { x = 9.2294; y = 10.5030; z = -0.1574 }
      , (* C6 *)
      G
        ( { x = 11.5110; y = 10.1256; z = -2.7114 }
          , (* N2   *)
          { x = 7.2891; y = 8.9068; z = 0.3121 }
          , (* N7   *)
          { x = 7.7962; y = 7.5519; z = -1.3859 }
          , (* N9   *)
          { x = 6.9702; y = 7.8292; z = -0.3353 }
          , (* C8   *)
          { x = 9.0349; y = 11.3951; z = 0.8250 }
          , (* O6   *)
          { x = 10.9013; y = 11.4422; z = -0.9512 }
          , (* H1   *)
          { x = 12.1031; y = 10.9341; z = -2.5861 }
          , (* H21  *)
          { x = 11.7369; y = 9.5180; z = -3.4859 }
          , (* H22  *)
          { x = 6.0888; y = 7.3990; z = 0.1403 } ) )

(* H8   *)

let rG06 =
  N
    ( { a = -0.9815
      ; b = 0.0731
      ; c = -0.1772
      ; (* dgf_base_tfo *)
        d = 0.1912
      ; e = 0.3054
      ; f = -0.9328
      ; g = -0.0141
      ; h = -0.9494
      ; i = -0.3137
      ; tx = 5.7506
      ; ty = -5.1944
      ; tz = 4.7470
    }
    , { a = -0.8143
      ; b = -0.5091
      ; c = -0.2788
      ; (* P_O3'_275_tfo *)
        d = -0.0433
      ; e = -0.4257
      ; f = 0.9038
      ; g = -0.5788
      ; h = 0.7480
      ; i = 0.3246
      ; tx = 1.5227
      ; ty = 6.9114
      ; tz = -7.0765
    }
    , { a = 0.3822
      ; b = -0.7477
      ; c = 0.5430
      ; (* P_O3'_180_tfo *)
        d = 0.4552
      ; e = 0.6637
      ; f = 0.5935
      ; g = -0.8042
      ; h = 0.0203
      ; i = 0.5941
      ; tx = -6.9472
      ; ty = -4.1186
      ; tz = -5.9108
    }
    , { a = 0.5640
      ; b = 0.8007
      ; c = -0.2022
      ; (* P_O3'_60_tfo *)
        d = -0.8247
      ; e = 0.5587
      ; f = -0.0878
      ; g = 0.0426
      ; h = 0.2162
      ; i = 0.9754
      ; tx = 6.2694
      ; ty = -7.0540
      ; tz = 3.3316
    }
    , { x = 2.8930; y = 8.5380; z = -3.3280 }
      , (* P    *)
      { x = 1.6980; y = 7.6960; z = -3.5570 }
      , (* O1P  *)
      { x = 3.2260; y = 9.5010; z = -4.4020 }
      , (* O2P  *)
      { x = 4.1590; y = 7.6040; z = -3.0340 }
      , (* O5'  *)
      { x = 4.1214; y = 6.7116; z = -1.9049 }
      , (* C5'  *)
      { x = 3.3465; y = 5.9610; z = -2.0607 }
      , (* H5'  *)
      { x = 4.0789; y = 7.2928; z = -0.9837 }
      , (* H5'' *)
      { x = 5.4170; y = 5.9293; z = -1.8186 }
      , (* C4'  *)
      { x = 5.4506; y = 5.3400; z = -0.9023 }
      , (* H4'  *)
      { x = 5.5067; y = 5.0417; z = -2.9703 }
      , (* O4'  *)
      { x = 6.8650; y = 4.9152; z = -3.3612 }
      , (* C1'  *)
      { x = 7.1090; y = 3.8577; z = -3.2603 }
      , (* H1'  *)
      { x = 7.7152; y = 5.7282; z = -2.3894 }
      , (* C2'  *)
      { x = 8.5029; y = 6.2356; z = -2.9463 }
      , (* H2'' *)
      { x = 8.1036; y = 4.8568; z = -1.3419 }
      , (* O2'  *)
      { x = 8.3270; y = 3.9651; z = -1.6184 }
      , (* H2'  *)
      { x = 6.7003; y = 6.7565; z = -1.8911 }
      , (* C3'  *)
      { x = 6.5898; y = 7.5329; z = -2.6482 }
      , (* H3'  *)
      { x = 7.0505; y = 7.2878; z = -0.6105 }
      , (* O3'  *)
      { x = 6.6624; y = 3.5061; z = -8.2986 }
      , (* N1   *)
      { x = 6.5810; y = 3.2570; z = -5.9221 }
      , (* N3   *)
      { x = 6.5151; y = 2.8263; z = -7.1625 }
      , (* C2   *)
      { x = 6.8364; y = 4.5817; z = -5.8882 }
      , (* C4   *)
      { x = 7.0116; y = 5.4064; z = -6.9609 }
      , (* C5   *)
      { x = 6.9173; y = 4.8260; z = -8.2361 }
      , (* C6 *)
      G
        ( { x = 6.2717; y = 1.5402; z = -7.4250 }
          , (* N2   *)
          { x = 7.2573; y = 6.7070; z = -6.5394 }
          , (* N7   *)
          { x = 6.9740; y = 5.3703; z = -4.7760 }
          , (* N9   *)
          { x = 7.2238; y = 6.6275; z = -5.2453 }
          , (* C8   *)
          { x = 7.0668; y = 5.5163; z = -9.3763 }
          , (* O6   *)
          { x = 6.5754; y = 2.9964; z = -9.1545 }
          , (* H1   *)
          { x = 6.1908; y = 1.1105; z = -8.3354 }
          , (* H21  *)
          { x = 6.1346; y = 0.9352; z = -6.6280 }
          , (* H22  *)
          { x = 7.4108; y = 7.6227; z = -4.8418 } ) )

(* H8   *)

let rG07 =
  N
    ( { a = 0.0894
      ; b = -0.6059
      ; c = 0.7905
      ; (* dgf_base_tfo *)
        d = -0.6810
      ; e = 0.5420
      ; f = 0.4924
      ; g = -0.7268
      ; h = -0.5824
      ; i = -0.3642
      ; tx = 34.1424
      ; ty = 45.9610
      ; tz = -11.8600
    }
    , { a = -0.8644
      ; b = -0.4956
      ; c = -0.0851
      ; (* P_O3'_275_tfo *)
        d = -0.0427
      ; e = 0.2409
      ; f = -0.9696
      ; g = 0.5010
      ; h = -0.8345
      ; i = -0.2294
      ; tx = 4.0167
      ; ty = 54.5377
      ; tz = 12.4779
    }
    , { a = 0.3706
      ; b = -0.6167
      ; c = 0.6945
      ; (* P_O3'_180_tfo *)
        d = -0.2867
      ; e = -0.7872
      ; f = -0.5460
      ; g = 0.8834
      ; h = 0.0032
      ; i = -0.4686
      ; tx = -52.9020
      ; ty = 18.6313
      ; tz = -0.6709
    }
    , { a = 0.4155
      ; b = 0.9025
      ; c = -0.1137
      ; (* P_O3'_60_tfo *)
        d = 0.9040
      ; e = -0.4236
      ; f = -0.0582
      ; g = -0.1007
      ; h = -0.0786
      ; i = -0.9918
      ; tx = -7.6624
      ; ty = -25.2080
      ; tz = 49.5181
    }
    , { x = 31.3810; y = 0.1400; z = 47.5810 }
      , (* P    *)
      { x = 29.9860; y = 0.6630; z = 47.6290 }
      , (* O1P  *)
      { x = 31.7210; y = -0.6460; z = 48.8090 }
      , (* O2P  *)
      { x = 32.4940; y = 1.2540; z = 47.2740 }
      , (* O5'  *)
      { x = 33.8709; y = 0.7918; z = 47.2113 }
      , (* C5'  *)
      { x = 34.1386; y = 0.5870; z = 46.1747 }
      , (* H5'  *)
      { x = 34.0186; y = -0.0095; z = 47.9353 }
      , (* H5'' *)
      { x = 34.7297; y = 1.9687; z = 47.6685 }
      , (* C4'  *)
      { x = 35.7723; y = 1.6845; z = 47.8113 }
      , (* H4'  *)
      { x = 34.6455; y = 2.9768; z = 46.6660 }
      , (* O4'  *)
      { x = 34.1690; y = 4.1829; z = 47.2627 }
      , (* C1'  *)
      { x = 35.0437; y = 4.7633; z = 47.5560 }
      , (* H1'  *)
      { x = 33.4145; y = 3.7532; z = 48.4954 }
      , (* C2'  *)
      { x = 32.4340; y = 3.3797; z = 48.2001 }
      , (* H2'' *)
      { x = 33.3209; y = 4.6953; z = 49.5217 }
      , (* O2'  *)
      { x = 33.2374; y = 5.6059; z = 49.2295 }
      , (* H2'  *)
      { x = 34.2724; y = 2.5970; z = 48.9773 }
      , (* C3'  *)
      { x = 33.6373; y = 1.8935; z = 49.5157 }
      , (* H3'  *)
      { x = 35.3453; y = 3.1884; z = 49.7285 }
      , (* O3'  *)
      { x = 34.0511; y = 7.8930; z = 43.7791 }
      , (* N1   *)
      { x = 34.9937; y = 6.3369; z = 45.3199 }
      , (* N3   *)
      { x = 35.0882; y = 7.3126; z = 44.4200 }
      , (* C2   *)
      { x = 33.7190; y = 5.9650; z = 45.5374 }
      , (* C4   *)
      { x = 32.5845; y = 6.4770; z = 44.9458 }
      , (* C5   *)
      { x = 32.7430; y = 7.5179; z = 43.9914 }
      , (* C6 *)
      G
        ( { x = 36.3030; y = 7.7827; z = 44.1036 }
          , (* N2   *)
          { x = 31.4499; y = 5.8335; z = 45.4368 }
          , (* N7   *)
          { x = 33.2760; y = 4.9817; z = 46.4043 }
          , (* N9   *)
          { x = 31.9235; y = 4.9639; z = 46.2934 }
          , (* C8   *)
          { x = 31.8602; y = 8.1000; z = 43.3695 }
          , (* O6   *)
          { x = 34.2623; y = 8.6223; z = 43.1283 }
          , (* H1   *)
          { x = 36.5188; y = 8.5081; z = 43.4347 }
          , (* H21  *)
          { x = 37.0888; y = 7.3524; z = 44.5699 }
          , (* H22  *)
          { x = 31.0815; y = 4.4201; z = 46.7218 } ) )

(* H8   *)

let rG08 =
  N
    ( { a = 0.2224
      ; b = 0.6335
      ; c = 0.7411
      ; (* dgf_base_tfo *)
        d = -0.3644
      ; e = -0.6510
      ; f = 0.6659
      ; g = 0.9043
      ; h = -0.4181
      ; i = 0.0861
      ; tx = -47.6824
      ; ty = -0.5823
      ; tz = -31.7554
    }
    , { a = -0.8644
      ; b = -0.4956
      ; c = -0.0851
      ; (* P_O3'_275_tfo *)
        d = -0.0427
      ; e = 0.2409
      ; f = -0.9696
      ; g = 0.5010
      ; h = -0.8345
      ; i = -0.2294
      ; tx = 4.0167
      ; ty = 54.5377
      ; tz = 12.4779
    }
    , { a = 0.3706
      ; b = -0.6167
      ; c = 0.6945
      ; (* P_O3'_180_tfo *)
        d = -0.2867
      ; e = -0.7872
      ; f = -0.5460
      ; g = 0.8834
      ; h = 0.0032
      ; i = -0.4686
      ; tx = -52.9020
      ; ty = 18.6313
      ; tz = -0.6709
    }
    , { a = 0.4155
      ; b = 0.9025
      ; c = -0.1137
      ; (* P_O3'_60_tfo *)
        d = 0.9040
      ; e = -0.4236
      ; f = -0.0582
      ; g = -0.1007
      ; h = -0.0786
      ; i = -0.9918
      ; tx = -7.6624
      ; ty = -25.2080
      ; tz = 49.5181
    }
    , { x = 31.3810; y = 0.1400; z = 47.5810 }
      , (* P    *)
      { x = 29.9860; y = 0.6630; z = 47.6290 }
      , (* O1P  *)
      { x = 31.7210; y = -0.6460; z = 48.8090 }
      , (* O2P  *)
      { x = 32.4940; y = 1.2540; z = 47.2740 }
      , (* O5'  *)
      { x = 32.5924; y = 2.3488; z = 48.2255 }
      , (* C5'  *)
      { x = 33.3674; y = 2.1246; z = 48.9584 }
      , (* H5'  *)
      { x = 31.5994; y = 2.5917; z = 48.6037 }
      , (* H5'' *)
      { x = 33.0722; y = 3.5577; z = 47.4258 }
      , (* C4'  *)
      { x = 33.0310; y = 4.4778; z = 48.0089 }
      , (* H4'  *)
      { x = 34.4173; y = 3.3055; z = 47.0316 }
      , (* O4'  *)
      { x = 34.5056; y = 3.3910; z = 45.6094 }
      , (* C1'  *)
      { x = 34.7881; y = 4.4152; z = 45.3663 }
      , (* H1'  *)
      { x = 33.1122; y = 3.1198; z = 45.1010 }
      , (* C2'  *)
      { x = 32.9230; y = 2.0469; z = 45.1369 }
      , (* H2'' *)
      { x = 32.7946; y = 3.6590; z = 43.8529 }
      , (* O2'  *)
      { x = 33.5170; y = 3.6707; z = 43.2207 }
      , (* H2'  *)
      { x = 32.2730; y = 3.8173; z = 46.1566 }
      , (* C3'  *)
      { x = 31.3094; y = 3.3123; z = 46.2244 }
      , (* H3'  *)
      { x = 32.2391; y = 5.2039; z = 45.7807 }
      , (* O3'  *)
      { x = 39.3337; y = 2.7157; z = 44.1441 }
      , (* N1   *)
      { x = 37.4430; y = 3.8242; z = 45.0824 }
      , (* N3   *)
      { x = 38.7276; y = 3.7646; z = 44.7403 }
      , (* C2   *)
      { x = 36.7791; y = 2.6963; z = 44.7704 }
      , (* C4   *)
      { x = 37.2860; y = 1.5653; z = 44.1678 }
      , (* C5   *)
      { x = 38.6647; y = 1.5552; z = 43.8235 }
      , (* C6 *)
      G
        ( { x = 39.5123; y = 4.8216; z = 44.9936 }
          , (* N2   *)
          { x = 36.2829; y = 0.6110; z = 44.0078 }
          , (* N7   *)
          { x = 35.4394; y = 2.4314; z = 44.9931 }
          , (* N9   *)
          { x = 35.2180; y = 1.1815; z = 44.5128 }
          , (* C8   *)
          { x = 39.2907; y = 0.6514; z = 43.2796 }
          , (* O6   *)
          { x = 40.3076; y = 2.8048; z = 43.9352 }
          , (* H1   *)
          { x = 40.4994; y = 4.9066; z = 44.7977 }
          , (* H21  *)
          { x = 39.0738; y = 5.6108; z = 45.4464 }
          , (* H22  *)
          { x = 34.3856; y = 0.4842; z = 44.4185 } ) )

(* H8   *)

let rG09 =
  N
    ( { a = -0.9699
      ; b = -0.1688
      ; c = -0.1753
      ; (* dgf_base_tfo *)
        d = -0.1050
      ; e = -0.3598
      ; f = 0.9271
      ; g = -0.2196
      ; h = 0.9176
      ; i = 0.3312
      ; tx = 45.6217
      ; ty = -38.9484
      ; tz = -12.3208
    }
    , { a = -0.8644
      ; b = -0.4956
      ; c = -0.0851
      ; (* P_O3'_275_tfo *)
        d = -0.0427
      ; e = 0.2409
      ; f = -0.9696
      ; g = 0.5010
      ; h = -0.8345
      ; i = -0.2294
      ; tx = 4.0167
      ; ty = 54.5377
      ; tz = 12.4779
    }
    , { a = 0.3706
      ; b = -0.6167
      ; c = 0.6945
      ; (* P_O3'_180_tfo *)
        d = -0.2867
      ; e = -0.7872
      ; f = -0.5460
      ; g = 0.8834
      ; h = 0.0032
      ; i = -0.4686
      ; tx = -52.9020
      ; ty = 18.6313
      ; tz = -0.6709
    }
    , { a = 0.4155
      ; b = 0.9025
      ; c = -0.1137
      ; (* P_O3'_60_tfo *)
        d = 0.9040
      ; e = -0.4236
      ; f = -0.0582
      ; g = -0.1007
      ; h = -0.0786
      ; i = -0.9918
      ; tx = -7.6624
      ; ty = -25.2080
      ; tz = 49.5181
    }
    , { x = 31.3810; y = 0.1400; z = 47.5810 }
      , (* P    *)
      { x = 29.9860; y = 0.6630; z = 47.6290 }
      , (* O1P  *)
      { x = 31.7210; y = -0.6460; z = 48.8090 }
      , (* O2P  *)
      { x = 32.4940; y = 1.2540; z = 47.2740 }
      , (* O5'  *)
      { x = 33.8709; y = 0.7918; z = 47.2113 }
      , (* C5'  *)
      { x = 34.1386; y = 0.5870; z = 46.1747 }
      , (* H5'  *)
      { x = 34.0186; y = -0.0095; z = 47.9353 }
      , (* H5'' *)
      { x = 34.7297; y = 1.9687; z = 47.6685 }
      , (* C4'  *)
      { x = 34.5880; y = 2.8482; z = 47.0404 }
      , (* H4'  *)
      { x = 34.3575; y = 2.2770; z = 49.0081 }
      , (* O4'  *)
      { x = 35.5157; y = 2.1993; z = 49.8389 }
      , (* C1'  *)
      { x = 35.9424; y = 3.2010; z = 49.8893 }
      , (* H1'  *)
      { x = 36.4701; y = 1.2820; z = 49.1169 }
      , (* C2'  *)
      { x = 36.1545; y = 0.2498; z = 49.2683 }
      , (* H2'' *)
      { x = 37.8262; y = 1.4547; z = 49.4008 }
      , (* O2'  *)
      { x = 38.0227; y = 1.6945; z = 50.3094 }
      , (* H2'  *)
      { x = 36.2242; y = 1.6797; z = 47.6725 }
      , (* C3'  *)
      { x = 36.4297; y = 0.8197; z = 47.0351 }
      , (* H3'  *)
      { x = 37.0289; y = 2.8480; z = 47.4426 }
      , (* O3'  *)
      { x = 34.3005; y = 3.5042; z = 54.6070 }
      , (* N1   *)
      { x = 34.7693; y = 3.7936; z = 52.2874 }
      , (* N3   *)
      { x = 34.4484; y = 4.2541; z = 53.4939 }
      , (* C2   *)
      { x = 34.9354; y = 2.4584; z = 52.2785 }
      , (* C4   *)
      { x = 34.8092; y = 1.5915; z = 53.3422 }
      , (* C5   *)
      { x = 34.4646; y = 2.1367; z = 54.6085 }
      , (* C6 *)
      G
        ( { x = 34.2514; y = 5.5708; z = 53.6503 }
          , (* N2   *)
          { x = 35.0641; y = 0.2835; z = 52.9337 }
          , (* N7   *)
          { x = 35.2669; y = 1.6690; z = 51.1915 }
          , (* N9   *)
          { x = 35.3288; y = 0.3954; z = 51.6563 }
          , (* C8   *)
          { x = 34.3151; y = 1.5317; z = 55.6650 }
          , (* O6   *)
          { x = 34.0623; y = 3.9797; z = 55.4539 }
          , (* H1   *)
          { x = 33.9950; y = 6.0502; z = 54.5016 }
          , (* H21  *)
          { x = 34.3512; y = 6.1432; z = 52.8242 }
          , (* H22  *)
          { x = 35.5414; y = -0.6006; z = 51.2679 } ) )

(* H8   *)

let rG10 =
  N
    ( { a = -0.0980
      ; b = -0.9723
      ; c = 0.2122
      ; (* dgf_base_tfo *)
        d = -0.9731
      ; e = 0.1383
      ; f = 0.1841
      ; g = -0.2083
      ; h = -0.1885
      ; i = -0.9597
      ; tx = 17.8469
      ; ty = 38.8265
      ; tz = 37.0475
    }
    , { a = -0.8644
      ; b = -0.4956
      ; c = -0.0851
      ; (* P_O3'_275_tfo *)
        d = -0.0427
      ; e = 0.2409
      ; f = -0.9696
      ; g = 0.5010
      ; h = -0.8345
      ; i = -0.2294
      ; tx = 4.0167
      ; ty = 54.5377
      ; tz = 12.4779
    }
    , { a = 0.3706
      ; b = -0.6167
      ; c = 0.6945
      ; (* P_O3'_180_tfo *)
        d = -0.2867
      ; e = -0.7872
      ; f = -0.5460
      ; g = 0.8834
      ; h = 0.0032
      ; i = -0.4686
      ; tx = -52.9020
      ; ty = 18.6313
      ; tz = -0.6709
    }
    , { a = 0.4155
      ; b = 0.9025
      ; c = -0.1137
      ; (* P_O3'_60_tfo *)
        d = 0.9040
      ; e = -0.4236
      ; f = -0.0582
      ; g = -0.1007
      ; h = -0.0786
      ; i = -0.9918
      ; tx = -7.6624
      ; ty = -25.2080
      ; tz = 49.5181
    }
    , { x = 31.3810; y = 0.1400; z = 47.5810 }
      , (* P    *)
      { x = 29.9860; y = 0.6630; z = 47.6290 }
      , (* O1P  *)
      { x = 31.7210; y = -0.6460; z = 48.8090 }
      , (* O2P  *)
      { x = 32.4940; y = 1.2540; z = 47.2740 }
      , (* O5'  *)
      { x = 32.5924; y = 2.3488; z = 48.2255 }
      , (* C5'  *)
      { x = 33.3674; y = 2.1246; z = 48.9584 }
      , (* H5'  *)
      { x = 31.5994; y = 2.5917; z = 48.6037 }
      , (* H5'' *)
      { x = 33.0722; y = 3.5577; z = 47.4258 }
      , (* C4'  *)
      { x = 34.0333; y = 3.3761; z = 46.9447 }
      , (* H4'  *)
      { x = 32.0890; y = 3.8338; z = 46.4332 }
      , (* O4'  *)
      { x = 31.6377; y = 5.1787; z = 46.5914 }
      , (* C1'  *)
      { x = 32.2499; y = 5.8016; z = 45.9392 }
      , (* H1'  *)
      { x = 31.9167; y = 5.5319; z = 48.0305 }
      , (* C2'  *)
      { x = 31.1507; y = 5.0820; z = 48.6621 }
      , (* H2'' *)
      { x = 32.0865; y = 6.8890; z = 48.3114 }
      , (* O2'  *)
      { x = 31.5363; y = 7.4819; z = 47.7942 }
      , (* H2'  *)
      { x = 33.2398; y = 4.8224; z = 48.2563 }
      , (* C3'  *)
      { x = 33.3166; y = 4.5570; z = 49.3108 }
      , (* H3'  *)
      { x = 34.2528; y = 5.7056; z = 47.7476 }
      , (* O3'  *)
      { x = 28.2782; y = 6.3049; z = 42.9364 }
      , (* N1   *)
      { x = 30.4001; y = 5.8547; z = 43.9258 }
      , (* N3   *)
      { x = 29.6195; y = 6.1568; z = 42.8913 }
      , (* C2   *)
      { x = 29.7005; y = 5.7006; z = 45.0649 }
      , (* C4   *)
      { x = 28.3383; y = 5.8221; z = 45.2343 }
      , (* C5   *)
      { x = 27.5519; y = 6.1461; z = 44.0958 }
      , (* C6 *)
      G
        ( { x = 30.1838; y = 6.3385; z = 41.6890 }
          , (* N2   *)
          { x = 27.9936; y = 5.5926; z = 46.5651 }
          , (* N7   *)
          { x = 30.2046; y = 5.3825; z = 46.3136 }
          , (* N9   *)
          { x = 29.1371; y = 5.3398; z = 47.1506 }
          , (* C8   *)
          { x = 26.3361; y = 6.3024; z = 44.0495 }
          , (* O6   *)
          { x = 27.8122; y = 6.5394; z = 42.0833 }
          , (* H1   *)
          { x = 29.7125; y = 6.5595; z = 40.8235 }
          , (* H21  *)
          { x = 31.1859; y = 6.2231; z = 41.6389 }
          , (* H22  *)
          { x = 28.9406; y = 5.1504; z = 48.2059 } ) )

(* H8   *)

let rGs = [ rG01; rG02; rG03; rG04; rG05; rG06; rG07; rG08; rG09; rG10 ]

let rU =
  N
    ( { a = -0.0359
      ; b = -0.8071
      ; c = 0.5894
      ; (* dgf_base_tfo *)
        d = -0.2669
      ; e = 0.5761
      ; f = 0.7726
      ; g = -0.9631
      ; h = -0.1296
      ; i = -0.2361
      ; tx = 0.1584
      ; ty = 8.3434
      ; tz = 0.5434
    }
    , { a = -0.8313
      ; b = -0.4738
      ; c = -0.2906
      ; (* P_O3'_275_tfo *)
        d = 0.0649
      ; e = 0.4366
      ; f = -0.8973
      ; g = 0.5521
      ; h = -0.7648
      ; i = -0.3322
      ; tx = 1.6833
      ; ty = 6.8060
      ; tz = -7.0011
    }
    , { a = 0.3445
      ; b = -0.7630
      ; c = 0.5470
      ; (* P_O3'_180_tfo *)
        d = -0.4628
      ; e = -0.6450
      ; f = -0.6082
      ; g = 0.8168
      ; h = -0.0436
      ; i = -0.5753
      ; tx = -6.8179
      ; ty = -3.9778
      ; tz = -5.9887
    }
    , { a = 0.5855
      ; b = 0.7931
      ; c = -0.1682
      ; (* P_O3'_60_tfo *)
        d = 0.8103
      ; e = -0.5790
      ; f = 0.0906
      ; g = -0.0255
      ; h = -0.1894
      ; i = -0.9816
      ; tx = 6.1203
      ; ty = -7.1051
      ; tz = 3.1984
    }
    , { x = 2.6760; y = -8.4960; z = 3.2880 }
      , (* P    *)
      { x = 1.4950; y = -7.6230; z = 3.4770 }
      , (* O1P  *)
      { x = 2.9490; y = -9.4640; z = 4.3740 }
      , (* O2P  *)
      { x = 3.9730; y = -7.5950; z = 3.0340 }
      , (* O5'  *)
      { x = 5.2430; y = -8.2420; z = 2.8260 }
      , (* C5'  *)
      { x = 5.1974; y = -8.8497; z = 1.9223 }
      , (* H5'  *)
      { x = 5.5548; y = -8.7348; z = 3.7469 }
      , (* H5'' *)
      { x = 6.3140; y = -7.2060; z = 2.5510 }
      , (* C4'  *)
      { x = 7.2954; y = -7.6762; z = 2.4898 }
      , (* H4'  *)
      { x = 6.0140; y = -6.5420; z = 1.2890 }
      , (* O4'  *)
      { x = 6.4190; y = -5.1840; z = 1.3620 }
      , (* C1'  *)
      { x = 7.1608; y = -5.0495; z = 0.5747 }
      , (* H1'  *)
      { x = 7.0760; y = -4.9560; z = 2.7270 }
      , (* C2'  *)
      { x = 6.7770; y = -3.9803; z = 3.1099 }
      , (* H2'' *)
      { x = 8.4500; y = -5.1930; z = 2.5810 }
      , (* O2'  *)
      { x = 8.8309; y = -4.8755; z = 1.7590 }
      , (* H2'  *)
      { x = 6.4060; y = -6.0590; z = 3.5580 }
      , (* C3'  *)
      { x = 5.4021; y = -5.7313; z = 3.8281 }
      , (* H3'  *)
      { x = 7.1570; y = -6.4240; z = 4.7070 }
      , (* O3'  *)
      { x = 5.2170; y = -4.3260; z = 1.1690 }
      , (* N1   *)
      { x = 4.2960; y = -2.2560; z = 0.6290 }
      , (* N3   *)
      { x = 5.4330; y = -3.0200; z = 0.7990 }
      , (* C2   *)
      { x = 2.9930; y = -2.6780; z = 0.7940 }
      , (* C4   *)
      { x = 2.8670; y = -4.0630; z = 1.1830 }
      , (* C5   *)
      { x = 3.9570; y = -4.8300; z = 1.3550 }
      , (* C6 *)
      U
        ( { x = 6.5470; y = -2.5560; z = 0.6290 }
          , (* O2   *)
          { x = 2.0540; y = -1.9000; z = 0.6130 }
          , (* O4   *)
          { x = 4.4300; y = -1.3020; z = 0.3600 }
          , (* H3   *)
          { x = 1.9590; y = -4.4570; z = 1.3250 }
          , (* H5   *)
          { x = 3.8460; y = -5.7860; z = 1.6240 } ) )

(* H6   *)

let rU01 =
  N
    ( { a = -0.0137
      ; b = -0.8012
      ; c = 0.5983
      ; (* dgf_base_tfo *)
        d = -0.2523
      ; e = 0.5817
      ; f = 0.7733
      ; g = -0.9675
      ; h = -0.1404
      ; i = -0.2101
      ; tx = 0.2031
      ; ty = 8.3874
      ; tz = 0.4228
    }
    , { a = -0.8313
      ; b = -0.4738
      ; c = -0.2906
      ; (* P_O3'_275_tfo *)
        d = 0.0649
      ; e = 0.4366
      ; f = -0.8973
      ; g = 0.5521
      ; h = -0.7648
      ; i = -0.3322
      ; tx = 1.6833
      ; ty = 6.8060
      ; tz = -7.0011
    }
    , { a = 0.3445
      ; b = -0.7630
      ; c = 0.5470
      ; (* P_O3'_180_tfo *)
        d = -0.4628
      ; e = -0.6450
      ; f = -0.6082
      ; g = 0.8168
      ; h = -0.0436
      ; i = -0.5753
      ; tx = -6.8179
      ; ty = -3.9778
      ; tz = -5.9887
    }
    , { a = 0.5855
      ; b = 0.7931
      ; c = -0.1682
      ; (* P_O3'_60_tfo *)
        d = 0.8103
      ; e = -0.5790
      ; f = 0.0906
      ; g = -0.0255
      ; h = -0.1894
      ; i = -0.9816
      ; tx = 6.1203
      ; ty = -7.1051
      ; tz = 3.1984
    }
    , { x = 2.6760; y = -8.4960; z = 3.2880 }
      , (* P    *)
      { x = 1.4950; y = -7.6230; z = 3.4770 }
      , (* O1P  *)
      { x = 2.9490; y = -9.4640; z = 4.3740 }
      , (* O2P  *)
      { x = 3.9730; y = -7.5950; z = 3.0340 }
      , (* O5'  *)
      { x = 5.2416; y = -8.2422; z = 2.8181 }
      , (* C5'  *)
      { x = 5.2050; y = -8.8128; z = 1.8901 }
      , (* H5'  *)
      { x = 5.5368; y = -8.7738; z = 3.7227 }
      , (* H5'' *)
      { x = 6.3232; y = -7.2037; z = 2.6002 }
      , (* C4'  *)
      { x = 7.3048; y = -7.6757; z = 2.5577 }
      , (* H4'  *)
      { x = 6.0635; y = -6.5092; z = 1.3456 }
      , (* O4'  *)
      { x = 6.4697; y = -5.1547; z = 1.4629 }
      , (* C1'  *)
      { x = 7.2354; y = -5.0043; z = 0.7018 }
      , (* H1'  *)
      { x = 7.0856; y = -4.9610; z = 2.8521 }
      , (* C2'  *)
      { x = 6.7777; y = -3.9935; z = 3.2487 }
      , (* H2'' *)
      { x = 8.4627; y = -5.1992; z = 2.7423 }
      , (* O2'  *)
      { x = 8.8693; y = -4.8638; z = 1.9399 }
      , (* H2'  *)
      { x = 6.3877; y = -6.0809; z = 3.6362 }
      , (* C3'  *)
      { x = 5.3770; y = -5.7562; z = 3.8834 }
      , (* H3'  *)
      { x = 7.1024; y = -6.4754; z = 4.7985 }
      , (* O3'  *)
      { x = 5.2764; y = -4.2883; z = 1.2538 }
      , (* N1   *)
      { x = 4.3777; y = -2.2062; z = 0.7229 }
      , (* N3   *)
      { x = 5.5069; y = -2.9779; z = 0.9088 }
      , (* C2   *)
      { x = 3.0693; y = -2.6246; z = 0.8500 }
      , (* C4   *)
      { x = 2.9279; y = -4.0146; z = 1.2149 }
      , (* C5   *)
      { x = 4.0101; y = -4.7892; z = 1.4017 }
      , (* C6 *)
      U
        ( { x = 6.6267; y = -2.5166; z = 0.7728 }
          , (* O2   *)
          { x = 2.1383; y = -1.8396; z = 0.6581 }
          , (* O4   *)
          { x = 4.5223; y = -1.2489; z = 0.4716 }
          , (* H3   *)
          { x = 2.0151; y = -4.4065; z = 1.3290 }
          , (* H5   *)
          { x = 3.8886; y = -5.7486; z = 1.6535 } ) )

(* H6   *)

let rU02 =
  N
    ( { a = 0.5141
      ; b = 0.0246
      ; c = 0.8574
      ; (* dgf_base_tfo *)
        d = -0.5547
      ; e = -0.7529
      ; f = 0.3542
      ; g = 0.6542
      ; h = -0.6577
      ; i = -0.3734
      ; tx = -9.1111
      ; ty = -3.4598
      ; tz = -3.2939
    }
    , { a = -0.8313
      ; b = -0.4738
      ; c = -0.2906
      ; (* P_O3'_275_tfo *)
        d = 0.0649
      ; e = 0.4366
      ; f = -0.8973
      ; g = 0.5521
      ; h = -0.7648
      ; i = -0.3322
      ; tx = 1.6833
      ; ty = 6.8060
      ; tz = -7.0011
    }
    , { a = 0.3445
      ; b = -0.7630
      ; c = 0.5470
      ; (* P_O3'_180_tfo *)
        d = -0.4628
      ; e = -0.6450
      ; f = -0.6082
      ; g = 0.8168
      ; h = -0.0436
      ; i = -0.5753
      ; tx = -6.8179
      ; ty = -3.9778
      ; tz = -5.9887
    }
    , { a = 0.5855
      ; b = 0.7931
      ; c = -0.1682
      ; (* P_O3'_60_tfo *)
        d = 0.8103
      ; e = -0.5790
      ; f = 0.0906
      ; g = -0.0255
      ; h = -0.1894
      ; i = -0.9816
      ; tx = 6.1203
      ; ty = -7.1051
      ; tz = 3.1984
    }
    , { x = 2.6760; y = -8.4960; z = 3.2880 }
      , (* P    *)
      { x = 1.4950; y = -7.6230; z = 3.4770 }
      , (* O1P  *)
      { x = 2.9490; y = -9.4640; z = 4.3740 }
      , (* O2P  *)
      { x = 3.9730; y = -7.5950; z = 3.0340 }
      , (* O5'  *)
      { x = 4.3825; y = -6.6585; z = 4.0489 }
      , (* C5'  *)
      { x = 4.6841; y = -7.2019; z = 4.9443 }
      , (* H5'  *)
      { x = 3.6189; y = -5.8889; z = 4.1625 }
      , (* H5'' *)
      { x = 5.6255; y = -5.9175; z = 3.5998 }
      , (* C4'  *)
      { x = 5.8732; y = -5.1228; z = 4.3034 }
      , (* H4'  *)
      { x = 6.7337; y = -6.8605; z = 3.5222 }
      , (* O4'  *)
      { x = 7.5932; y = -6.4923; z = 2.4548 }
      , (* C1'  *)
      { x = 8.5661; y = -6.2983; z = 2.9064 }
      , (* H1'  *)
      { x = 7.0527; y = -5.2012; z = 1.8322 }
      , (* C2'  *)
      { x = 7.1627; y = -5.2525; z = 0.7490 }
      , (* H2'' *)
      { x = 7.6666; y = -4.1249; z = 2.4880 }
      , (* O2'  *)
      { x = 8.5944; y = -4.2543; z = 2.6981 }
      , (* H2'  *)
      { x = 5.5661; y = -5.3029; z = 2.2009 }
      , (* C3'  *)
      { x = 5.0841; y = -6.0018; z = 1.5172 }
      , (* H3'  *)
      { x = 4.9062; y = -4.0452; z = 2.2042 }
      , (* O3'  *)
      { x = 7.6298; y = -7.6136; z = 1.4752 }
      , (* N1   *)
      { x = 8.6945; y = -8.7046; z = -0.2857 }
      , (* N3   *)
      { x = 8.6943; y = -7.6514; z = 0.6066 }
      , (* C2   *)
      { x = 7.7426; y = -9.6987; z = -0.3801 }
      , (* C4   *)
      { x = 6.6642; y = -9.5742; z = 0.5722 }
      , (* C5   *)
      { x = 6.6391; y = -8.5592; z = 1.4526 }
      , (* C6 *)
      U
        ( { x = 9.5840; y = -6.8186; z = 0.6136 }
          , (* O2   *)
          { x = 7.8505; y = -10.5925; z = -1.2223 }
          , (* O4   *)
          { x = 9.4601; y = -8.7514; z = -0.9277 }
          , (* H3   *)
          { x = 5.9281; y = -10.2509; z = 0.5782 }
          , (* H5   *)
          { x = 5.8831; y = -8.4931; z = 2.1028 } ) )

(* H6   *)

let rU03 =
  N
    ( { a = -0.4993
      ; b = 0.0476
      ; c = 0.8651
      ; (* dgf_base_tfo *)
        d = 0.8078
      ; e = -0.3353
      ; f = 0.4847
      ; g = 0.3132
      ; h = 0.9409
      ; i = 0.1290
      ; tx = 6.2989
      ; ty = -5.2303
      ; tz = -3.8577
    }
    , { a = -0.8313
      ; b = -0.4738
      ; c = -0.2906
      ; (* P_O3'_275_tfo *)
        d = 0.0649
      ; e = 0.4366
      ; f = -0.8973
      ; g = 0.5521
      ; h = -0.7648
      ; i = -0.3322
      ; tx = 1.6833
      ; ty = 6.8060
      ; tz = -7.0011
    }
    , { a = 0.3445
      ; b = -0.7630
      ; c = 0.5470
      ; (* P_O3'_180_tfo *)
        d = -0.4628
      ; e = -0.6450
      ; f = -0.6082
      ; g = 0.8168
      ; h = -0.0436
      ; i = -0.5753
      ; tx = -6.8179
      ; ty = -3.9778
      ; tz = -5.9887
    }
    , { a = 0.5855
      ; b = 0.7931
      ; c = -0.1682
      ; (* P_O3'_60_tfo *)
        d = 0.8103
      ; e = -0.5790
      ; f = 0.0906
      ; g = -0.0255
      ; h = -0.1894
      ; i = -0.9816
      ; tx = 6.1203
      ; ty = -7.1051
      ; tz = 3.1984
    }
    , { x = 2.6760; y = -8.4960; z = 3.2880 }
      , (* P    *)
      { x = 1.4950; y = -7.6230; z = 3.4770 }
      , (* O1P  *)
      { x = 2.9490; y = -9.4640; z = 4.3740 }
      , (* O2P  *)
      { x = 3.9730; y = -7.5950; z = 3.0340 }
      , (* O5'  *)
      { x = 3.9938; y = -6.7042; z = 1.9023 }
      , (* C5'  *)
      { x = 3.2332; y = -5.9343; z = 2.0319 }
      , (* H5'  *)
      { x = 3.9666; y = -7.2863; z = 0.9812 }
      , (* H5'' *)
      { x = 5.3098; y = -5.9546; z = 1.8564 }
      , (* C4'  *)
      { x = 5.3863; y = -5.3702; z = 0.9395 }
      , (* H4'  *)
      { x = 5.3851; y = -5.0642; z = 3.0076 }
      , (* O4'  *)
      { x = 6.7315; y = -4.9724; z = 3.4462 }
      , (* C1'  *)
      { x = 7.0033; y = -3.9202; z = 3.3619 }
      , (* H1'  *)
      { x = 7.5997; y = -5.8018; z = 2.4948 }
      , (* C2'  *)
      { x = 8.3627; y = -6.3254; z = 3.0707 }
      , (* H2'' *)
      { x = 8.0410; y = -4.9501; z = 1.4724 }
      , (* O2'  *)
      { x = 8.2781; y = -4.0644; z = 1.7570 }
      , (* H2'  *)
      { x = 6.5701; y = -6.8129; z = 1.9714 }
      , (* C3'  *)
      { x = 6.4186; y = -7.5809; z = 2.7299 }
      , (* H3'  *)
      { x = 6.9357; y = -7.3841; z = 0.7235 }
      , (* O3'  *)
      { x = 6.8024; y = -5.4718; z = 4.8475 }
      , (* N1   *)
      { x = 7.9218; y = -5.5700; z = 6.8877 }
      , (* N3   *)
      { x = 7.8908; y = -5.0886; z = 5.5944 }
      , (* C2   *)
      { x = 6.9789; y = -6.3827; z = 7.4823 }
      , (* C4   *)
      { x = 5.8742; y = -6.7319; z = 6.6202 }
      , (* C5   *)
      { x = 5.8182; y = -6.2769; z = 5.3570 }
      , (* C6 *)
      U
        ( { x = 8.7747; y = -4.3728; z = 5.1568 }
          , (* O2   *)
          { x = 7.1154; y = -6.7509; z = 8.6509 }
          , (* O4   *)
          { x = 8.7055; y = -5.3037; z = 7.4491 }
          , (* H3   *)
          { x = 5.1416; y = -7.3178; z = 6.9665 }
          , (* H5   *)
          { x = 5.0441; y = -6.5310; z = 4.7784 } ) )

(* H6   *)

let rU04 =
  N
    ( { a = -0.5669
      ; b = -0.8012
      ; c = 0.1918
      ; (* dgf_base_tfo *)
        d = -0.8129
      ; e = 0.5817
      ; f = 0.0273
      ; g = -0.1334
      ; h = -0.1404
      ; i = -0.9811
      ; tx = -0.3279
      ; ty = 8.3874
      ; tz = 0.3355
    }
    , { a = -0.8313
      ; b = -0.4738
      ; c = -0.2906
      ; (* P_O3'_275_tfo *)
        d = 0.0649
      ; e = 0.4366
      ; f = -0.8973
      ; g = 0.5521
      ; h = -0.7648
      ; i = -0.3322
      ; tx = 1.6833
      ; ty = 6.8060
      ; tz = -7.0011
    }
    , { a = 0.3445
      ; b = -0.7630
      ; c = 0.5470
      ; (* P_O3'_180_tfo *)
        d = -0.4628
      ; e = -0.6450
      ; f = -0.6082
      ; g = 0.8168
      ; h = -0.0436
      ; i = -0.5753
      ; tx = -6.8179
      ; ty = -3.9778
      ; tz = -5.9887
    }
    , { a = 0.5855
      ; b = 0.7931
      ; c = -0.1682
      ; (* P_O3'_60_tfo *)
        d = 0.8103
      ; e = -0.5790
      ; f = 0.0906
      ; g = -0.0255
      ; h = -0.1894
      ; i = -0.9816
      ; tx = 6.1203
      ; ty = -7.1051
      ; tz = 3.1984
    }
    , { x = 2.6760; y = -8.4960; z = 3.2880 }
      , (* P    *)
      { x = 1.4950; y = -7.6230; z = 3.4770 }
      , (* O1P  *)
      { x = 2.9490; y = -9.4640; z = 4.3740 }
      , (* O2P  *)
      { x = 3.9730; y = -7.5950; z = 3.0340 }
      , (* O5'  *)
      { x = 5.2416; y = -8.2422; z = 2.8181 }
      , (* C5'  *)
      { x = 5.2050; y = -8.8128; z = 1.8901 }
      , (* H5'  *)
      { x = 5.5368; y = -8.7738; z = 3.7227 }
      , (* H5'' *)
      { x = 6.3232; y = -7.2037; z = 2.6002 }
      , (* C4'  *)
      { x = 7.3048; y = -7.6757; z = 2.5577 }
      , (* H4'  *)
      { x = 6.0635; y = -6.5092; z = 1.3456 }
      , (* O4'  *)
      { x = 6.4697; y = -5.1547; z = 1.4629 }
      , (* C1'  *)
      { x = 7.2354; y = -5.0043; z = 0.7018 }
      , (* H1'  *)
      { x = 7.0856; y = -4.9610; z = 2.8521 }
      , (* C2'  *)
      { x = 6.7777; y = -3.9935; z = 3.2487 }
      , (* H2'' *)
      { x = 8.4627; y = -5.1992; z = 2.7423 }
      , (* O2'  *)
      { x = 8.8693; y = -4.8638; z = 1.9399 }
      , (* H2'  *)
      { x = 6.3877; y = -6.0809; z = 3.6362 }
      , (* C3'  *)
      { x = 5.3770; y = -5.7562; z = 3.8834 }
      , (* H3'  *)
      { x = 7.1024; y = -6.4754; z = 4.7985 }
      , (* O3'  *)
      { x = 5.2764; y = -4.2883; z = 1.2538 }
      , (* N1   *)
      { x = 3.8961; y = -3.0896; z = -0.1893 }
      , (* N3   *)
      { x = 5.0095; y = -3.8907; z = -0.0346 }
      , (* C2   *)
      { x = 3.0480; y = -2.6632; z = 0.8116 }
      , (* C4   *)
      { x = 3.4093; y = -3.1310; z = 2.1292 }
      , (* C5   *)
      { x = 4.4878; y = -3.9124; z = 2.3088 }
      , (* C6 *)
      U
        ( { x = 5.7005; y = -4.2164; z = -0.9842 }
          , (* O2   *)
          { x = 2.0800; y = -1.9458; z = 0.5503 }
          , (* O4   *)
          { x = 3.6834; y = -2.7882; z = -1.1190 }
          , (* H3   *)
          { x = 2.8508; y = -2.8721; z = 2.9172 }
          , (* H5   *)
          { x = 4.7188; y = -4.2247; z = 3.2295 } ) )

(* H6   *)

let rU05 =
  N
    ( { a = -0.6298
      ; b = 0.0246
      ; c = 0.7763
      ; (* dgf_base_tfo *)
        d = -0.5226
      ; e = -0.7529
      ; f = -0.4001
      ; g = 0.5746
      ; h = -0.6577
      ; i = 0.4870
      ; tx = -0.0208
      ; ty = -3.4598
      ; tz = -9.6882
    }
    , { a = -0.8313
      ; b = -0.4738
      ; c = -0.2906
      ; (* P_O3'_275_tfo *)
        d = 0.0649
      ; e = 0.4366
      ; f = -0.8973
      ; g = 0.5521
      ; h = -0.7648
      ; i = -0.3322
      ; tx = 1.6833
      ; ty = 6.8060
      ; tz = -7.0011
    }
    , { a = 0.3445
      ; b = -0.7630
      ; c = 0.5470
      ; (* P_O3'_180_tfo *)
        d = -0.4628
      ; e = -0.6450
      ; f = -0.6082
      ; g = 0.8168
      ; h = -0.0436
      ; i = -0.5753
      ; tx = -6.8179
      ; ty = -3.9778
      ; tz = -5.9887
    }
    , { a = 0.5855
      ; b = 0.7931
      ; c = -0.1682
      ; (* P_O3'_60_tfo *)
        d = 0.8103
      ; e = -0.5790
      ; f = 0.0906
      ; g = -0.0255
      ; h = -0.1894
      ; i = -0.9816
      ; tx = 6.1203
      ; ty = -7.1051
      ; tz = 3.1984
    }
    , { x = 2.6760; y = -8.4960; z = 3.2880 }
      , (* P    *)
      { x = 1.4950; y = -7.6230; z = 3.4770 }
      , (* O1P  *)
      { x = 2.9490; y = -9.4640; z = 4.3740 }
      , (* O2P  *)
      { x = 3.9730; y = -7.5950; z = 3.0340 }
      , (* O5'  *)
      { x = 4.3825; y = -6.6585; z = 4.0489 }
      , (* C5'  *)
      { x = 4.6841; y = -7.2019; z = 4.9443 }
      , (* H5'  *)
      { x = 3.6189; y = -5.8889; z = 4.1625 }
      , (* H5'' *)
      { x = 5.6255; y = -5.9175; z = 3.5998 }
      , (* C4'  *)
      { x = 5.8732; y = -5.1228; z = 4.3034 }
      , (* H4'  *)
      { x = 6.7337; y = -6.8605; z = 3.5222 }
      , (* O4'  *)
      { x = 7.5932; y = -6.4923; z = 2.4548 }
      , (* C1'  *)
      { x = 8.5661; y = -6.2983; z = 2.9064 }
      , (* H1'  *)
      { x = 7.0527; y = -5.2012; z = 1.8322 }
      , (* C2'  *)
      { x = 7.1627; y = -5.2525; z = 0.7490 }
      , (* H2'' *)
      { x = 7.6666; y = -4.1249; z = 2.4880 }
      , (* O2'  *)
      { x = 8.5944; y = -4.2543; z = 2.6981 }
      , (* H2'  *)
      { x = 5.5661; y = -5.3029; z = 2.2009 }
      , (* C3'  *)
      { x = 5.0841; y = -6.0018; z = 1.5172 }
      , (* H3'  *)
      { x = 4.9062; y = -4.0452; z = 2.2042 }
      , (* O3'  *)
      { x = 7.6298; y = -7.6136; z = 1.4752 }
      , (* N1   *)
      { x = 8.5977; y = -9.5977; z = 0.7329 }
      , (* N3   *)
      { x = 8.5951; y = -8.5745; z = 1.6594 }
      , (* C2   *)
      { x = 7.7372; y = -9.7371; z = -0.3364 }
      , (* C4   *)
      { x = 6.7596; y = -8.6801; z = -0.4476 }
      , (* C5   *)
      { x = 6.7338; y = -7.6721; z = 0.4408 }
      , (* C6 *)
      U
        ( { x = 9.3993; y = -8.5377; z = 2.5743 }
          , (* O2   *)
          { x = 7.8374; y = -10.6990; z = -1.1008 }
          , (* O4   *)
          { x = 9.2924; y = -10.3081; z = 0.8477 }
          , (* H3   *)
          { x = 6.0932; y = -8.6982; z = -1.1929 }
          , (* H5   *)
          { x = 6.0481; y = -6.9515; z = 0.3446 } ) )

(* H6   *)

let rU06 =
  N
    ( { a = -0.9837
      ; b = 0.0476
      ; c = -0.1733
      ; (* dgf_base_tfo *)
        d = -0.1792
      ; e = -0.3353
      ; f = 0.9249
      ; g = -0.0141
      ; h = 0.9409
      ; i = 0.3384
      ; tx = 5.7793
      ; ty = -5.2303
      ; tz = 4.5997
    }
    , { a = -0.8313
      ; b = -0.4738
      ; c = -0.2906
      ; (* P_O3'_275_tfo *)
        d = 0.0649
      ; e = 0.4366
      ; f = -0.8973
      ; g = 0.5521
      ; h = -0.7648
      ; i = -0.3322
      ; tx = 1.6833
      ; ty = 6.8060
      ; tz = -7.0011
    }
    , { a = 0.3445
      ; b = -0.7630
      ; c = 0.5470
      ; (* P_O3'_180_tfo *)
        d = -0.4628
      ; e = -0.6450
      ; f = -0.6082
      ; g = 0.8168
      ; h = -0.0436
      ; i = -0.5753
      ; tx = -6.8179
      ; ty = -3.9778
      ; tz = -5.9887
    }
    , { a = 0.5855
      ; b = 0.7931
      ; c = -0.1682
      ; (* P_O3'_60_tfo *)
        d = 0.8103
      ; e = -0.5790
      ; f = 0.0906
      ; g = -0.0255
      ; h = -0.1894
      ; i = -0.9816
      ; tx = 6.1203
      ; ty = -7.1051
      ; tz = 3.1984
    }
    , { x = 2.6760; y = -8.4960; z = 3.2880 }
      , (* P    *)
      { x = 1.4950; y = -7.6230; z = 3.4770 }
      , (* O1P  *)
      { x = 2.9490; y = -9.4640; z = 4.3740 }
      , (* O2P  *)
      { x = 3.9730; y = -7.5950; z = 3.0340 }
      , (* O5'  *)
      { x = 3.9938; y = -6.7042; z = 1.9023 }
      , (* C5'  *)
      { x = 3.2332; y = -5.9343; z = 2.0319 }
      , (* H5'  *)
      { x = 3.9666; y = -7.2863; z = 0.9812 }
      , (* H5'' *)
      { x = 5.3098; y = -5.9546; z = 1.8564 }
      , (* C4'  *)
      { x = 5.3863; y = -5.3702; z = 0.9395 }
      , (* H4'  *)
      { x = 5.3851; y = -5.0642; z = 3.0076 }
      , (* O4'  *)
      { x = 6.7315; y = -4.9724; z = 3.4462 }
      , (* C1'  *)
      { x = 7.0033; y = -3.9202; z = 3.3619 }
      , (* H1'  *)
      { x = 7.5997; y = -5.8018; z = 2.4948 }
      , (* C2'  *)
      { x = 8.3627; y = -6.3254; z = 3.0707 }
      , (* H2'' *)
      { x = 8.0410; y = -4.9501; z = 1.4724 }
      , (* O2'  *)
      { x = 8.2781; y = -4.0644; z = 1.7570 }
      , (* H2'  *)
      { x = 6.5701; y = -6.8129; z = 1.9714 }
      , (* C3'  *)
      { x = 6.4186; y = -7.5809; z = 2.7299 }
      , (* H3'  *)
      { x = 6.9357; y = -7.3841; z = 0.7235 }
      , (* O3'  *)
      { x = 6.8024; y = -5.4718; z = 4.8475 }
      , (* N1   *)
      { x = 6.6920; y = -5.0495; z = 7.1354 }
      , (* N3   *)
      { x = 6.6201; y = -4.5500; z = 5.8506 }
      , (* C2   *)
      { x = 6.9254; y = -6.3614; z = 7.4926 }
      , (* C4   *)
      { x = 7.1046; y = -7.2543; z = 6.3718 }
      , (* C5   *)
      { x = 7.0391; y = -6.7951; z = 5.1106 }
      , (* C6 *)
      U
        ( { x = 6.4083; y = -3.3696; z = 5.6340 }
          , (* O2   *)
          { x = 6.9679; y = -6.6901; z = 8.6800 }
          , (* O4   *)
          { x = 6.5626; y = -4.3957; z = 7.8812 }
          , (* H3   *)
          { x = 7.2781; y = -8.2254; z = 6.5350 }
          , (* H5   *)
          { x = 7.1657; y = -7.4312; z = 4.3503 } ) )

(* H6   *)

let rU07 =
  N
    ( { a = -0.9434
      ; b = 0.3172
      ; c = 0.0971
      ; (* dgf_base_tfo *)
        d = 0.2294
      ; e = 0.4125
      ; f = 0.8816
      ; g = 0.2396
      ; h = 0.8539
      ; i = -0.4619
      ; tx = 8.3625
      ; ty = -52.7147
      ; tz = 1.3745
    }
    , { a = 0.2765
      ; b = -0.1121
      ; c = -0.9545
      ; (* P_O3'_275_tfo *)
        d = -0.8297
      ; e = 0.4733
      ; f = -0.2959
      ; g = 0.4850
      ; h = 0.8737
      ; i = 0.0379
      ; tx = -14.7774
      ; ty = -45.2464
      ; tz = 21.9088
    }
    , { a = 0.1063
      ; b = -0.6334
      ; c = -0.7665
      ; (* P_O3'_180_tfo *)
        d = -0.5932
      ; e = -0.6591
      ; f = 0.4624
      ; g = -0.7980
      ; h = 0.4055
      ; i = -0.4458
      ; tx = 43.7634
      ; ty = 4.3296
      ; tz = 28.4890
    }
    , { a = 0.7136
      ; b = -0.5032
      ; c = -0.4873
      ; (* P_O3'_60_tfo *)
        d = 0.6803
      ; e = 0.3317
      ; f = 0.6536
      ; g = -0.1673
      ; h = -0.7979
      ; i = 0.5791
      ; tx = -17.1858
      ; ty = 41.4390
      ; tz = -27.0751
    }
    , { x = 21.3880; y = 15.0780; z = 45.5770 }
      , (* P    *)
      { x = 21.9980; y = 14.5500; z = 46.8210 }
      , (* O1P  *)
      { x = 21.1450; y = 14.0270; z = 44.5420 }
      , (* O2P  *)
      { x = 22.1250; y = 16.3600; z = 44.9460 }
      , (* O5'  *)
      { x = 21.5037; y = 16.8594; z = 43.7323 }
      , (* C5'  *)
      { x = 20.8147; y = 17.6663; z = 43.9823 }
      , (* H5'  *)
      { x = 21.1086; y = 16.0230; z = 43.1557 }
      , (* H5'' *)
      { x = 22.5654; y = 17.4874; z = 42.8616 }
      , (* C4'  *)
      { x = 22.1584; y = 17.7243; z = 41.8785 }
      , (* H4'  *)
      { x = 23.0557; y = 18.6826; z = 43.4751 }
      , (* O4'  *)
      { x = 24.4788; y = 18.6151; z = 43.6455 }
      , (* C1'  *)
      { x = 24.9355; y = 19.0840; z = 42.7739 }
      , (* H1'  *)
      { x = 24.7958; y = 17.1427; z = 43.6474 }
      , (* C2'  *)
      { x = 24.5652; y = 16.7400; z = 44.6336 }
      , (* H2'' *)
      { x = 26.1041; y = 16.8773; z = 43.2455 }
      , (* O2'  *)
      { x = 26.7516; y = 17.5328; z = 43.5149 }
      , (* H2'  *)
      { x = 23.8109; y = 16.5979; z = 42.6377 }
      , (* C3'  *)
      { x = 23.5756; y = 15.5686; z = 42.9084 }
      , (* H3'  *)
      { x = 24.2890; y = 16.7447; z = 41.2729 }
      , (* O3'  *)
      { x = 24.9420; y = 19.2174; z = 44.8923 }
      , (* N1   *)
      { x = 25.2655; y = 20.5636; z = 44.8883 }
      , (* N3   *)
      { x = 25.1663; y = 21.2219; z = 43.8561 }
      , (* C2   *)
      { x = 25.6911; y = 21.1219; z = 46.0494 }
      , (* C4   *)
      { x = 25.8051; y = 20.4068; z = 47.2048 }
      , (* C5   *)
      { x = 26.2093; y = 20.9962; z = 48.2534 }
      , (* C6 *)
      U
        ( { x = 25.4692; y = 19.0221; z = 47.2053 }
          , (* O2   *)
          { x = 25.0502; y = 18.4827; z = 46.0370 }
          , (* O4   *)
          { x = 25.9599; y = 22.1772; z = 46.0966 }
          , (* H3   *)
          { x = 25.5545; y = 18.4409; z = 48.1234 }
          , (* H5   *)
          { x = 24.7854; y = 17.4265; z = 45.9883 } ) )

(* H6   *)

let rU08 =
  N
    ( { a = -0.0080
      ; b = -0.7928
      ; c = 0.6094
      ; (* dgf_base_tfo *)
        d = -0.7512
      ; e = 0.4071
      ; f = 0.5197
      ; g = -0.6601
      ; h = -0.4536
      ; i = -0.5988
      ; tx = 44.1482
      ; ty = 30.7036
      ; tz = 2.1088
    }
    , { a = 0.2765
      ; b = -0.1121
      ; c = -0.9545
      ; (* P_O3'_275_tfo *)
        d = -0.8297
      ; e = 0.4733
      ; f = -0.2959
      ; g = 0.4850
      ; h = 0.8737
      ; i = 0.0379
      ; tx = -14.7774
      ; ty = -45.2464
      ; tz = 21.9088
    }
    , { a = 0.1063
      ; b = -0.6334
      ; c = -0.7665
      ; (* P_O3'_180_tfo *)
        d = -0.5932
      ; e = -0.6591
      ; f = 0.4624
      ; g = -0.7980
      ; h = 0.4055
      ; i = -0.4458
      ; tx = 43.7634
      ; ty = 4.3296
      ; tz = 28.4890
    }
    , { a = 0.7136
      ; b = -0.5032
      ; c = -0.4873
      ; (* P_O3'_60_tfo *)
        d = 0.6803
      ; e = 0.3317
      ; f = 0.6536
      ; g = -0.1673
      ; h = -0.7979
      ; i = 0.5791
      ; tx = -17.1858
      ; ty = 41.4390
      ; tz = -27.0751
    }
    , { x = 21.3880; y = 15.0780; z = 45.5770 }
      , (* P    *)
      { x = 21.9980; y = 14.5500; z = 46.8210 }
      , (* O1P  *)
      { x = 21.1450; y = 14.0270; z = 44.5420 }
      , (* O2P  *)
      { x = 22.1250; y = 16.3600; z = 44.9460 }
      , (* O5'  *)
      { x = 23.5096; y = 16.1227; z = 44.5783 }
      , (* C5'  *)
      { x = 23.5649; y = 15.8588; z = 43.5222 }
      , (* H5'  *)
      { x = 23.9621; y = 15.4341; z = 45.2919 }
      , (* H5'' *)
      { x = 24.2805; y = 17.4138; z = 44.7151 }
      , (* C4'  *)
      { x = 25.3492; y = 17.2309; z = 44.6030 }
      , (* H4'  *)
      { x = 23.8497; y = 18.3471; z = 43.7208 }
      , (* O4'  *)
      { x = 23.4090; y = 19.5681; z = 44.3321 }
      , (* C1'  *)
      { x = 24.2595; y = 20.2496; z = 44.3524 }
      , (* H1'  *)
      { x = 23.0418; y = 19.1813; z = 45.7407 }
      , (* C2'  *)
      { x = 22.0532; y = 18.7224; z = 45.7273 }
      , (* H2'' *)
      { x = 23.1307; y = 20.2521; z = 46.6291 }
      , (* O2'  *)
      { x = 22.8888; y = 21.1051; z = 46.2611 }
      , (* H2'  *)
      { x = 24.0799; y = 18.1326; z = 46.0700 }
      , (* C3'  *)
      { x = 23.6490; y = 17.4370; z = 46.7900 }
      , (* H3'  *)
      { x = 25.3329; y = 18.7227; z = 46.5109 }
      , (* O3'  *)
      { x = 22.2515; y = 20.1624; z = 43.6698 }
      , (* N1   *)
      { x = 22.4760; y = 21.0609; z = 42.6406 }
      , (* N3   *)
      { x = 23.6229; y = 21.3462; z = 42.3061 }
      , (* C2   *)
      { x = 21.3986; y = 21.6081; z = 42.0236 }
      , (* C4   *)
      { x = 20.1189; y = 21.3012; z = 42.3804 }
      , (* C5   *)
      { x = 19.1599; y = 21.8516; z = 41.7578 }
      , (* C6 *)
      U
        ( { x = 19.8919; y = 20.3745; z = 43.4387 }
          , (* O2   *)
          { x = 20.9790; y = 19.8423; z = 44.0440 }
          , (* O4   *)
          { x = 21.5235; y = 22.3222; z = 41.2097 }
          , (* H3   *)
          { x = 18.8732; y = 20.1200; z = 43.7312 }
          , (* H5   *)
          { x = 20.8545; y = 19.1313; z = 44.8608 } ) )

(* H6   *)

let rU09 =
  N
    ( { a = -0.0317
      ; b = 0.1374
      ; c = 0.9900
      ; (* dgf_base_tfo *)
        d = -0.3422
      ; e = -0.9321
      ; f = 0.1184
      ; g = 0.9391
      ; h = -0.3351
      ; i = 0.0765
      ; tx = -32.1929
      ; ty = 25.8198
      ; tz = -28.5088
    }
    , { a = 0.2765
      ; b = -0.1121
      ; c = -0.9545
      ; (* P_O3'_275_tfo *)
        d = -0.8297
      ; e = 0.4733
      ; f = -0.2959
      ; g = 0.4850
      ; h = 0.8737
      ; i = 0.0379
      ; tx = -14.7774
      ; ty = -45.2464
      ; tz = 21.9088
    }
    , { a = 0.1063
      ; b = -0.6334
      ; c = -0.7665
      ; (* P_O3'_180_tfo *)
        d = -0.5932
      ; e = -0.6591
      ; f = 0.4624
      ; g = -0.7980
      ; h = 0.4055
      ; i = -0.4458
      ; tx = 43.7634
      ; ty = 4.3296
      ; tz = 28.4890
    }
    , { a = 0.7136
      ; b = -0.5032
      ; c = -0.4873
      ; (* P_O3'_60_tfo *)
        d = 0.6803
      ; e = 0.3317
      ; f = 0.6536
      ; g = -0.1673
      ; h = -0.7979
      ; i = 0.5791
      ; tx = -17.1858
      ; ty = 41.4390
      ; tz = -27.0751
    }
    , { x = 21.3880; y = 15.0780; z = 45.5770 }
      , (* P    *)
      { x = 21.9980; y = 14.5500; z = 46.8210 }
      , (* O1P  *)
      { x = 21.1450; y = 14.0270; z = 44.5420 }
      , (* O2P  *)
      { x = 22.1250; y = 16.3600; z = 44.9460 }
      , (* O5'  *)
      { x = 21.5037; y = 16.8594; z = 43.7323 }
      , (* C5'  *)
      { x = 20.8147; y = 17.6663; z = 43.9823 }
      , (* H5'  *)
      { x = 21.1086; y = 16.0230; z = 43.1557 }
      , (* H5'' *)
      { x = 22.5654; y = 17.4874; z = 42.8616 }
      , (* C4'  *)
      { x = 23.0565; y = 18.3036; z = 43.3915 }
      , (* H4'  *)
      { x = 23.5375; y = 16.5054; z = 42.4925 }
      , (* O4'  *)
      { x = 23.6574; y = 16.4257; z = 41.0649 }
      , (* C1'  *)
      { x = 24.4701; y = 17.0882; z = 40.7671 }
      , (* H1'  *)
      { x = 22.3525; y = 16.9643; z = 40.5396 }
      , (* C2'  *)
      { x = 21.5993; y = 16.1799; z = 40.6133 }
      , (* H2'' *)
      { x = 22.4693; y = 17.4849; z = 39.2515 }
      , (* O2'  *)
      { x = 23.0899; y = 17.0235; z = 38.6827 }
      , (* H2'  *)
      { x = 22.0341; y = 18.0633; z = 41.5279 }
      , (* C3'  *)
      { x = 20.9509; y = 18.1709; z = 41.5846 }
      , (* H3'  *)
      { x = 22.7249; y = 19.3020; z = 41.2100 }
      , (* O3'  *)
      { x = 23.8580; y = 15.0648; z = 40.5757 }
      , (* N1   *)
      { x = 25.1556; y = 14.5982; z = 40.4523 }
      , (* N3   *)
      { x = 26.1047; y = 15.3210; z = 40.7448 }
      , (* C2   *)
      { x = 25.3391; y = 13.3315; z = 40.0020 }
      , (* C4   *)
      { x = 24.2974; y = 12.5148; z = 39.6749 }
      , (* C5   *)
      { x = 24.5450; y = 11.3410; z = 39.2610 }
      , (* C6 *)
      U
        ( { x = 22.9633; y = 12.9979; z = 39.8053 }
          , (* O2   *)
          { x = 22.8009; y = 14.2648; z = 40.2524 }
          , (* O4   *)
          { x = 26.3414; y = 12.9194; z = 39.8855 }
          , (* H3   *)
          { x = 22.1227; y = 12.3533; z = 39.5486 }
          , (* H5   *)
          { x = 21.7989; y = 14.6788; z = 40.3650 } ) )

(* H6   *)

let rU10 =
  N
    ( { a = -0.9674
      ; b = 0.1021
      ; c = -0.2318
      ; (* dgf_base_tfo *)
        d = -0.2514
      ; e = -0.2766
      ; f = 0.9275
      ; g = 0.0306
      ; h = 0.9555
      ; i = 0.2933
      ; tx = 27.8571
      ; ty = -42.1305
      ; tz = -24.4563
    }
    , { a = 0.2765
      ; b = -0.1121
      ; c = -0.9545
      ; (* P_O3'_275_tfo *)
        d = -0.8297
      ; e = 0.4733
      ; f = -0.2959
      ; g = 0.4850
      ; h = 0.8737
      ; i = 0.0379
      ; tx = -14.7774
      ; ty = -45.2464
      ; tz = 21.9088
    }
    , { a = 0.1063
      ; b = -0.6334
      ; c = -0.7665
      ; (* P_O3'_180_tfo *)
        d = -0.5932
      ; e = -0.6591
      ; f = 0.4624
      ; g = -0.7980
      ; h = 0.4055
      ; i = -0.4458
      ; tx = 43.7634
      ; ty = 4.3296
      ; tz = 28.4890
    }
    , { a = 0.7136
      ; b = -0.5032
      ; c = -0.4873
      ; (* P_O3'_60_tfo *)
        d = 0.6803
      ; e = 0.3317
      ; f = 0.6536
      ; g = -0.1673
      ; h = -0.7979
      ; i = 0.5791
      ; tx = -17.1858
      ; ty = 41.4390
      ; tz = -27.0751
    }
    , { x = 21.3880; y = 15.0780; z = 45.5770 }
      , (* P    *)
      { x = 21.9980; y = 14.5500; z = 46.8210 }
      , (* O1P  *)
      { x = 21.1450; y = 14.0270; z = 44.5420 }
      , (* O2P  *)
      { x = 22.1250; y = 16.3600; z = 44.9460 }
      , (* O5'  *)
      { x = 23.5096; y = 16.1227; z = 44.5783 }
      , (* C5'  *)
      { x = 23.5649; y = 15.8588; z = 43.5222 }
      , (* H5'  *)
      { x = 23.9621; y = 15.4341; z = 45.2919 }
      , (* H5'' *)
      { x = 24.2805; y = 17.4138; z = 44.7151 }
      , (* C4'  *)
      { x = 23.8509; y = 18.1819; z = 44.0720 }
      , (* H4'  *)
      { x = 24.2506; y = 17.8583; z = 46.0741 }
      , (* O4'  *)
      { x = 25.5830; y = 18.0320; z = 46.5775 }
      , (* C1'  *)
      { x = 25.8569; y = 19.0761; z = 46.4256 }
      , (* H1'  *)
      { x = 26.4410; y = 17.1555; z = 45.7033 }
      , (* C2'  *)
      { x = 26.3459; y = 16.1253; z = 46.0462 }
      , (* H2'' *)
      { x = 27.7649; y = 17.5888; z = 45.6478 }
      , (* O2'  *)
      { x = 28.1004; y = 17.9719; z = 46.4616 }
      , (* H2'  *)
      { x = 25.7796; y = 17.2997; z = 44.3513 }
      , (* C3'  *)
      { x = 25.9478; y = 16.3824; z = 43.7871 }
      , (* H3'  *)
      { x = 26.2154; y = 18.4984; z = 43.6541 }
      , (* O3'  *)
      { x = 25.7321; y = 17.6281; z = 47.9726 }
      , (* N1   *)
      { x = 25.5136; y = 18.5779; z = 48.9560 }
      , (* N3   *)
      { x = 25.2079; y = 19.7276; z = 48.6503 }
      , (* C2   *)
      { x = 25.6482; y = 18.1987; z = 50.2518 }
      , (* C4   *)
      { x = 25.9847; y = 16.9266; z = 50.6092 }
      , (* C5   *)
      { x = 26.0918; y = 16.6439; z = 51.8416 }
      , (* C6 *)
      U
        ( { x = 26.2067; y = 15.9515; z = 49.5943 }
          , (* O2   *)
          { x = 26.0713; y = 16.3497; z = 48.3080 }
          , (* O4   *)
          { x = 25.4890; y = 18.9105; z = 51.0618 }
          , (* H3   *)
          { x = 26.4742; y = 14.9310; z = 49.8682 }
          , (* H5   *)
          { x = 26.2346; y = 15.6394; z = 47.4975 } ) )

(* H6   *)

let rUs = [ rU01; rU02; rU03; rU04; rU05; rU06; rU07; rU08; rU09; rU10 ]

let rG' =
  N
    ( { a = -0.2067
      ; b = -0.0264
      ; c = 0.9780
      ; (* dgf_base_tfo *)
        d = 0.9770
      ; e = -0.0586
      ; f = 0.2049
      ; g = 0.0519
      ; h = 0.9979
      ; i = 0.0379
      ; tx = 1.0331
      ; ty = -46.8078
      ; tz = -36.4742
    }
    , { a = -0.8644
      ; b = -0.4956
      ; c = -0.0851
      ; (* P_O3'_275_tfo *)
        d = -0.0427
      ; e = 0.2409
      ; f = -0.9696
      ; g = 0.5010
      ; h = -0.8345
      ; i = -0.2294
      ; tx = 4.0167
      ; ty = 54.5377
      ; tz = 12.4779
    }
    , { a = 0.3706
      ; b = -0.6167
      ; c = 0.6945
      ; (* P_O3'_180_tfo *)
        d = -0.2867
      ; e = -0.7872
      ; f = -0.5460
      ; g = 0.8834
      ; h = 0.0032
      ; i = -0.4686
      ; tx = -52.9020
      ; ty = 18.6313
      ; tz = -0.6709
    }
    , { a = 0.4155
      ; b = 0.9025
      ; c = -0.1137
      ; (* P_O3'_60_tfo *)
        d = 0.9040
      ; e = -0.4236
      ; f = -0.0582
      ; g = -0.1007
      ; h = -0.0786
      ; i = -0.9918
      ; tx = -7.6624
      ; ty = -25.2080
      ; tz = 49.5181
    }
    , { x = 31.3810; y = 0.1400; z = 47.5810 }
      , (* P    *)
      { x = 29.9860; y = 0.6630; z = 47.6290 }
      , (* O1P  *)
      { x = 31.7210; y = -0.6460; z = 48.8090 }
      , (* O2P  *)
      { x = 32.4940; y = 1.2540; z = 47.2740 }
      , (* O5'  *)
      { x = 32.1610; y = 2.2370; z = 46.2560 }
      , (* C5'  *)
      { x = 31.2986; y = 2.8190; z = 46.5812 }
      , (* H5'  *)
      { x = 32.0980; y = 1.7468; z = 45.2845 }
      , (* H5'' *)
      { x = 33.3476; y = 3.1959; z = 46.1947 }
      , (* C4'  *)
      { x = 33.2668; y = 3.8958; z = 45.3630 }
      , (* H4'  *)
      { x = 33.3799; y = 3.9183; z = 47.4216 }
      , (* O4'  *)
      { x = 34.6515; y = 3.7222; z = 48.0398 }
      , (* C1'  *)
      { x = 35.2947; y = 4.5412; z = 47.7180 }
      , (* H1'  *)
      { x = 35.1756; y = 2.4228; z = 47.4827 }
      , (* C2'  *)
      { x = 34.6778; y = 1.5937; z = 47.9856 }
      , (* H2'' *)
      { x = 36.5631; y = 2.2672; z = 47.4798 }
      , (* O2'  *)
      { x = 37.0163; y = 2.6579; z = 48.2305 }
      , (* H2'  *)
      { x = 34.6953; y = 2.5043; z = 46.0448 }
      , (* C3'  *)
      { x = 34.5444; y = 1.4917; z = 45.6706 }
      , (* H3'  *)
      { x = 35.6679; y = 3.3009; z = 45.3487 }
      , (* O3'  *)
      { x = 37.4804; y = 4.0914; z = 52.2559 }
      , (* N1   *)
      { x = 36.9670; y = 4.1312; z = 49.9281 }
      , (* N3   *)
      { x = 37.8045; y = 4.2519; z = 50.9550 }
      , (* C2   *)
      { x = 35.7171; y = 3.8264; z = 50.3222 }
      , (* C4   *)
      { x = 35.2668; y = 3.6420; z = 51.6115 }
      , (* C5   *)
      { x = 36.2037; y = 3.7829; z = 52.6706 }
      , (* C6 *)
      G
        ( { x = 39.0869; y = 4.5552; z = 50.7092 }
          , (* N2   *)
          { x = 33.9075; y = 3.3338; z = 51.6102 }
          , (* N7   *)
          { x = 34.6126; y = 3.6358; z = 49.5108 }
          , (* N9   *)
          { x = 33.5805; y = 3.3442; z = 50.3425 }
          , (* C8   *)
          { x = 35.9958; y = 3.6512; z = 53.8724 }
          , (* O6   *)
          { x = 38.2106; y = 4.2053; z = 52.9295 }
          , (* H1   *)
          { x = 39.8218; y = 4.6863; z = 51.3896 }
          , (* H21  *)
          { x = 39.3420; y = 4.6857; z = 49.7407 }
          , (* H22  *)
          { x = 32.5194; y = 3.1070; z = 50.2664 } ) )

(* H8   *)

let rU' =
  N
    ( { a = -0.0109
      ; b = 0.5907
      ; c = 0.8068
      ; (* dgf_base_tfo *)
        d = 0.2217
      ; e = -0.7853
      ; f = 0.5780
      ; g = 0.9751
      ; h = 0.1852
      ; i = -0.1224
      ; tx = -1.4225
      ; ty = -11.0956
      ; tz = -2.5217
    }
    , { a = -0.8313
      ; b = -0.4738
      ; c = -0.2906
      ; (* P_O3'_275_tfo *)
        d = 0.0649
      ; e = 0.4366
      ; f = -0.8973
      ; g = 0.5521
      ; h = -0.7648
      ; i = -0.3322
      ; tx = 1.6833
      ; ty = 6.8060
      ; tz = -7.0011
    }
    , { a = 0.3445
      ; b = -0.7630
      ; c = 0.5470
      ; (* P_O3'_180_tfo *)
        d = -0.4628
      ; e = -0.6450
      ; f = -0.6082
      ; g = 0.8168
      ; h = -0.0436
      ; i = -0.5753
      ; tx = -6.8179
      ; ty = -3.9778
      ; tz = -5.9887
    }
    , { a = 0.5855
      ; b = 0.7931
      ; c = -0.1682
      ; (* P_O3'_60_tfo *)
        d = 0.8103
      ; e = -0.5790
      ; f = 0.0906
      ; g = -0.0255
      ; h = -0.1894
      ; i = -0.9816
      ; tx = 6.1203
      ; ty = -7.1051
      ; tz = 3.1984
    }
    , { x = 2.6760; y = -8.4960; z = 3.2880 }
      , (* P    *)
      { x = 1.4950; y = -7.6230; z = 3.4770 }
      , (* O1P  *)
      { x = 2.9490; y = -9.4640; z = 4.3740 }
      , (* O2P  *)
      { x = 3.9730; y = -7.5950; z = 3.0340 }
      , (* O5'  *)
      { x = 5.2430; y = -8.2420; z = 2.8260 }
      , (* C5'  *)
      { x = 5.1974; y = -8.8497; z = 1.9223 }
      , (* H5'  *)
      { x = 5.5548; y = -8.7348; z = 3.7469 }
      , (* H5'' *)
      { x = 6.3140; y = -7.2060; z = 2.5510 }
      , (* C4'  *)
      { x = 5.8744; y = -6.2116; z = 2.4731 }
      , (* H4'  *)
      { x = 7.2798; y = -7.2260; z = 3.6420 }
      , (* O4'  *)
      { x = 8.5733; y = -6.9410; z = 3.1329 }
      , (* C1'  *)
      { x = 8.9047; y = -6.0374; z = 3.6446 }
      , (* H1'  *)
      { x = 8.4429; y = -6.6596; z = 1.6327 }
      , (* C2'  *)
      { x = 9.2880; y = -7.1071; z = 1.1096 }
      , (* H2'' *)
      { x = 8.2502; y = -5.2799; z = 1.4754 }
      , (* O2'  *)
      { x = 8.7676; y = -4.7284; z = 2.0667 }
      , (* H2'  *)
      { x = 7.1642; y = -7.4416; z = 1.3021 }
      , (* C3'  *)
      { x = 7.4125; y = -8.5002; z = 1.2260 }
      , (* H3'  *)
      { x = 6.5160; y = -6.9772; z = 0.1267 }
      , (* O3'  *)
      { x = 9.4531; y = -8.1107; z = 3.4087 }
      , (* N1   *)
      { x = 11.5931; y = -9.0015; z = 3.6357 }
      , (* N3   *)
      { x = 10.8101; y = -7.8950; z = 3.3748 }
      , (* C2   *)
      { x = 11.1439; y = -10.2744; z = 3.9206 }
      , (* C4   *)
      { x = 9.7056; y = -10.4026; z = 3.9332 }
      , (* C5   *)
      { x = 8.9192; y = -9.3419; z = 3.6833 }
      , (* C6 *)
      U
        ( { x = 11.3013; y = -6.8063; z = 3.1326 }
          , (* O2   *)
          { x = 11.9431; y = -11.1876; z = 4.1375 }
          , (* O4   *)
          { x = 12.5840; y = -8.8673; z = 3.6158 }
          , (* H3   *)
          { x = 9.2891; y = -11.2898; z = 4.1313 }
          , (* H5   *)
          { x = 7.9263; y = -9.4537; z = 3.6977 } ) )

(* H6   *)

(* -- PARTIAL INSTANTIATIONS ------------------------------------------------*)

type variable =
  { id : int
  ; t : tfo
  ; n : nuc
  }

let mk_var i t n = { id = i; t; n }

let absolute_pos v p = tfo_apply v.t p

let atom_pos atom v = absolute_pos v (atom v.n)

let rec get_var id = function
  | v :: lst -> if id = v.id then v else get_var id lst
  | _ -> assert false

(* -- SEARCH ----------------------------------------------------------------*)

(* Sequential backtracking algorithm *)

let rec search (partial_inst : variable list) l constr =
  match l with
  | [] -> [ partial_inst ]
  | h :: t ->
    let rec try_assignments = function
      | [] -> []
      | v :: vs ->
        if constr v partial_inst
        then search (v :: partial_inst) t constr @ try_assignments vs
        else try_assignments vs
    in
    try_assignments (h partial_inst)

(* -- DOMAINS ---------------------------------------------------------------*)

(* Primary structure:   strand A CUGCCACGUCUG, strand B CAGACGUGGCAG

   Secondary structure: strand A CUGCCACGUCUG
                                 ||||||||||||
                                 GACGGUGCAGAC strand B

   Tertiary structure:

      5' end of strand A C1----G12 3' end of strand B
                       U2-------A11
                      G3-------C10
                      C4-----G9
                       C5---G8
                          A6
                        G6-C7
                       C5----G8
                      A4-------U9
                      G3--------C10
                       A2-------U11
     5' end of strand B C1----G12 3' end of strand A

   "helix", "stacked" and "connected" describe the spatial relationship
   between two consecutive nucleotides. E.g. the nucleotides C1 and U2
   from the strand A.

   "wc" (stands for Watson-Crick and is a type of base-pairing),
   and "wc-dumas" describe the spatial relationship between
   nucleotides from two chains that are growing in opposite directions.
   E.g. the nucleotides C1 from strand A and G12 from strand B.
*)

(* Dynamic Domains *)

(* Given,
     "refnuc" a nucleotide which is already positioned,
     "nucl" the nucleotide to be placed,
     and "tfo" a transformation matrix which expresses the desired
     relationship between "refnuc" and "nucl",
   the function "dgf-base" computes the transformation matrix that
   places the nucleotide "nucl" in the given relationship to "refnuc".
*)

let dgf_base tfo v nucl =
  let x =
    if is_A v.n
    then tfo_align (atom_pos nuc_C1' v) (atom_pos rA_N9 v) (atom_pos nuc_C4 v)
    else if is_C v.n
    then tfo_align (atom_pos nuc_C1' v) (atom_pos nuc_N1 v) (atom_pos nuc_C2 v)
    else if is_G v.n
    then tfo_align (atom_pos nuc_C1' v) (atom_pos rG_N9 v) (atom_pos nuc_C4 v)
    else tfo_align (atom_pos nuc_C1' v) (atom_pos nuc_N1 v) (atom_pos nuc_C2 v)
  in
  tfo_combine (nuc_dgf_base_tfo nucl) (tfo_combine tfo (tfo_inv_ortho x))

(* Placement of first nucleotide. *)

let reference n i partial_inst = [ mk_var i tfo_id n ]

(* The transformation matrix for wc is from:

   Chandrasekaran R. et al (1989) A Re-Examination of the Crystal
   Structure of A-DNA Using Fiber Diffraction Data. J. Biomol.
   Struct. & Dynamics 6(6):1189-1202.
*)

let wc_tfo =
  { a = -1.0000
  ; b = 0.0028
  ; c = -0.0019
  ; d = 0.0028
  ; e = 0.3468
  ; f = -0.9379
  ; g = -0.0019
  ; h = -0.9379
  ; i = -0.3468
  ; tx = -0.0080
  ; ty = 6.0730
  ; tz = 8.7208
  }

let wc nucl i j partial_inst =
  [ mk_var i (dgf_base wc_tfo (get_var j partial_inst) nucl) nucl ]

let wc_dumas_tfo =
  { a = -0.9737
  ; b = -0.1834
  ; c = 0.1352
  ; d = -0.1779
  ; e = 0.2417
  ; f = -0.9539
  ; g = 0.1422
  ; h = -0.9529
  ; i = -0.2679
  ; tx = 0.4837
  ; ty = 6.2649
  ; tz = 8.0285
  }

let wc_dumas nucl i j partial_inst =
  [ mk_var i (dgf_base wc_dumas_tfo (get_var j partial_inst) nucl) nucl ]

let helix5'_tfo =
  { a = 0.9886
  ; b = -0.0961
  ; c = 0.1156
  ; d = 0.1424
  ; e = 0.8452
  ; f = -0.5152
  ; g = -0.0482
  ; h = 0.5258
  ; i = 0.8492
  ; tx = -3.8737
  ; ty = 0.5480
  ; tz = 3.8024
  }

let helix5' nucl i j partial_inst =
  [ mk_var i (dgf_base helix5'_tfo (get_var j partial_inst) nucl) nucl ]

let helix3'_tfo =
  { a = 0.9886
  ; b = 0.1424
  ; c = -0.0482
  ; d = -0.0961
  ; e = 0.8452
  ; f = 0.5258
  ; g = 0.1156
  ; h = -0.5152
  ; i = 0.8492
  ; tx = 3.4426
  ; ty = 2.0474
  ; tz = -3.7042
  }

let helix3' nucl i j partial_inst =
  [ mk_var i (dgf_base helix3'_tfo (get_var j partial_inst) nucl) nucl ]

let g37_a38_tfo =
  { a = 0.9991
  ; b = 0.0164
  ; c = -0.0387
  ; d = -0.0375
  ; e = 0.7616
  ; f = -0.6470
  ; g = 0.0189
  ; h = 0.6478
  ; i = 0.7615
  ; tx = -3.3018
  ; ty = 0.9975
  ; tz = 2.5585
  }

let g37_a38 nucl i j partial_inst =
  mk_var i (dgf_base g37_a38_tfo (get_var j partial_inst) nucl) nucl

let stacked5' nucl i j partial_inst =
  g37_a38 nucl i j partial_inst :: helix5' nucl i j partial_inst

let a38_g37_tfo =
  { a = 0.9991
  ; b = -0.0375
  ; c = 0.0189
  ; d = 0.0164
  ; e = 0.7616
  ; f = 0.6478
  ; g = -0.0387
  ; h = -0.6470
  ; i = 0.7615
  ; tx = 3.3819
  ; ty = 0.7718
  ; tz = -2.5321
  }

let a38_g37 nucl i j partial_inst =
  mk_var i (dgf_base a38_g37_tfo (get_var j partial_inst) nucl) nucl

let stacked3' nucl i j partial_inst =
  a38_g37 nucl i j partial_inst :: helix3' nucl i j partial_inst

let p_o3' nucls i j partial_inst =
  let refnuc = get_var j partial_inst in
  let align =
    tfo_inv_ortho
      (tfo_align
          (atom_pos nuc_O3' refnuc)
          (atom_pos nuc_C3' refnuc)
          (atom_pos nuc_C4' refnuc))
  in
  let rec generate domains = function
    | [] -> domains
    | n :: ns ->
      generate
        (mk_var i (tfo_combine (nuc_p_o3'_60_tfo n) align) n
          :: mk_var i (tfo_combine (nuc_p_o3'_180_tfo n) align) n
          :: mk_var i (tfo_combine (nuc_p_o3'_275_tfo n) align) n
          :: domains)
        ns
  in
  generate [] nucls

(* -- PROBLEM STATEMENT -----------------------------------------------------*)

(* Define anticodon problem -- Science 253:1255 Figure 3a, 3b and 3c *)

let anticodon_domains =
  [ reference rC 27
  ; helix5' rC 28 27
  ; helix5' rA 29 28
  ; helix5' rG 30 29
  ; helix5' rA 31 30
  ; wc rU 39 31
  ; helix5' rC 40 39
  ; helix5' rU 41 40
  ; helix5' rG 42 41
  ; helix5' rG 43 42
  ; stacked3' rA 38 39
  ; stacked3' rG 37 38
  ; stacked3' rA 36 37
  ; stacked3' rA 35 36
  ; stacked3' rG 34 35 (* <-. Distance      *)
  ; p_o3' rCs 32 31 (*      | Constraint    *)
  ; p_o3' rUs 33 32 (*    <-' 3.0 Angstroms *)
  ]
[@@ocamlformat "disable"]

(* Anticodon constraint *)

let anticodon_constraint v partial_inst =
  let dist j =
    let p = atom_pos nuc_P (get_var j partial_inst) in
    let o3' = atom_pos nuc_O3' v in
    pt_dist p o3'
  in
  if v.id = 33 then dist 34 <= 3.0 else true

let anticodon () = search [] anticodon_domains anticodon_constraint

(* Define pseudoknot problem -- Science 253:1255 Figure 4a and 4b *)

let pseudoknot_domains =
  [ reference rA 23
  ; wc_dumas rU 8 23
  ; helix3' rG 22 23
  ; wc_dumas rC 9 22
  ; helix3' rG 21 22
  ; wc_dumas rC 10 21
  ; helix3' rC 20 21
  ; wc_dumas rG 11 20
  ; helix3' rU' 19 20 (* <-.               *)
  ; wc_dumas rA 12 19 (*   | Distance      *)
  (*                     | Constraint    *)
  (*  Helix 1            | 4.0 Angstroms *)
  ; helix3' rC 3 19   (*   |               *)
  ; wc_dumas rG 13 3  (*   |               *)
  ; helix3' rC 2 3    (*   |               *)
  ; wc_dumas rG 14 2  (*   |               *)
  ; helix3' rC 1 2    (*   |               *)
  ; wc_dumas rG' 15 1 (*   |               *)
  (*                     |               *)
  (*  L2 LOOP            |               *)
  ; p_o3' rUs 16 15   (*   |               *)
  ; p_o3' rCs 17 16   (*   |               *)
  ; p_o3' rAs 18 17   (* <-'               *)
  (*                                     *)
  (*  L1 LOOP                            *)
  ; helix3' rU 7 8    (* <-.               *)
  ; p_o3' rCs 4 3     (*   | Constraint    *)
  ; stacked5' rU 5 4  (*   | 4.5 Angstroms *)
  ; stacked5' rC 6 5  (* <-'               *)
  ]
[@@ocamlformat "disable"]

(* Pseudoknot constraint *)

let pseudoknot_constraint v partial_inst =
  let dist j =
    let p = atom_pos nuc_P (get_var j partial_inst) in
    let o3' = atom_pos nuc_O3' v in
    pt_dist p o3'
  in
  if v.id = 18 then dist 19 <= 4.0 else if v.id = 6 then dist 7 <= 4.5 else true

let pseudoknot () = search [] pseudoknot_domains pseudoknot_constraint

(* -- TESTING ---------------------------------------------------------------*)

let list_of_atoms = function
  | N
      ( dgf_base_tfo
      , p_o3'_275_tfo
      , p_o3'_180_tfo
      , p_o3'_60_tfo
      , p
      , o1p
      , o2p
      , o5'
      , c5'
      , h5'
      , h5''
      , c4'
      , h4'
      , o4'
      , c1'
      , h1'
      , c2'
      , h2''
      , o2'
      , h2'
      , c3'
      , h3'
      , o3'
      , n1
      , n3
      , c2
      , c4
      , c5
      , c6
      , A (n6, n7, n9, c8, h2, h61, h62, h8) ) ->
    [| p
     ; o1p
     ; o2p
     ; o5'
     ; c5'
     ; h5'
     ; h5''
     ; c4'
     ; h4'
     ; o4'
     ; c1'
     ; h1'
     ; c2'
     ; h2''
     ; o2'
     ; h2'
     ; c3'
     ; h3'
     ; o3'
     ; n1
     ; n3
     ; c2
     ; c4
     ; c5
     ; c6
     ; n6
     ; n7
     ; n9
     ; c8
     ; h2
     ; h61
     ; h62
     ; h8
    |]
  | N
      ( dgf_base_tfo
      , p_o3'_275_tfo
      , p_o3'_180_tfo
      , p_o3'_60_tfo
      , p
      , o1p
      , o2p
      , o5'
      , c5'
      , h5'
      , h5''
      , c4'
      , h4'
      , o4'
      , c1'
      , h1'
      , c2'
      , h2''
      , o2'
      , h2'
      , c3'
      , h3'
      , o3'
      , n1
      , n3
      , c2
      , c4
      , c5
      , c6
      , C (n4, o2, h41, h42, h5, h6) ) ->
    [| p
     ; o1p
     ; o2p
     ; o5'
     ; c5'
     ; h5'
     ; h5''
     ; c4'
     ; h4'
     ; o4'
     ; c1'
     ; h1'
     ; c2'
     ; h2''
     ; o2'
     ; h2'
     ; c3'
     ; h3'
     ; o3'
     ; n1
     ; n3
     ; c2
     ; c4
     ; c5
     ; c6
     ; n4
     ; o2
     ; h41
     ; h42
     ; h5
     ; h6
    |]
  | N
      ( dgf_base_tfo
      , p_o3'_275_tfo
      , p_o3'_180_tfo
      , p_o3'_60_tfo
      , p
      , o1p
      , o2p
      , o5'
      , c5'
      , h5'
      , h5''
      , c4'
      , h4'
      , o4'
      , c1'
      , h1'
      , c2'
      , h2''
      , o2'
      , h2'
      , c3'
      , h3'
      , o3'
      , n1
      , n3
      , c2
      , c4
      , c5
      , c6
      , G (n2, n7, n9, c8, o6, h1, h21, h22, h8) ) ->
    [| p
     ; o1p
     ; o2p
     ; o5'
     ; c5'
     ; h5'
     ; h5''
     ; c4'
     ; h4'
     ; o4'
     ; c1'
     ; h1'
     ; c2'
     ; h2''
     ; o2'
     ; h2'
     ; c3'
     ; h3'
     ; o3'
     ; n1
     ; n3
     ; c2
     ; c4
     ; c5
     ; c6
     ; n2
     ; n7
     ; n9
     ; c8
     ; o6
     ; h1
     ; h21
     ; h22
     ; h8
    |]
  | N
      ( dgf_base_tfo
      , p_o3'_275_tfo
      , p_o3'_180_tfo
      , p_o3'_60_tfo
      , p
      , o1p
      , o2p
      , o5'
      , c5'
      , h5'
      , h5''
      , c4'
      , h4'
      , o4'
      , c1'
      , h1'
      , c2'
      , h2''
      , o2'
      , h2'
      , c3'
      , h3'
      , o3'
      , n1
      , n3
      , c2
      , c4
      , c5
      , c6
      , U (o2, o4, h3, h5, h6) ) ->
    [| p
     ; o1p
     ; o2p
     ; o5'
     ; c5'
     ; h5'
     ; h5''
     ; c4'
     ; h4'
     ; o4'
     ; c1'
     ; h1'
     ; c2'
     ; h2''
     ; o2'
     ; h2'
     ; c3'
     ; h3'
     ; o3'
     ; n1
     ; n3
     ; c2
     ; c4
     ; c5
     ; c6
     ; o2
     ; o4
     ; h3
     ; h5
     ; h6
    |]

let maximum = function
  | x :: xs ->
    let rec iter m = function
      | [] -> m
      | a :: b -> iter (if a > m then a else m) b
    in
    iter x xs
  | _ -> assert false

let var_most_distant_atom v =
  let atoms = list_of_atoms v.n in
  let max_dist = ref 0.0 in
  for i = 0 to pred (Array.length atoms) do
    let p = atoms.(i) in
    let distance =
      let pos = absolute_pos v p in
      sqrt ((pos.x * pos.x) + (pos.y * pos.y) + (pos.z * pos.z))
    in
    if distance > !max_dist then max_dist := distance
  done;
  !max_dist

let sol_most_distant_atom s = maximum (List.map var_most_distant_atom s)

let most_distant_atom sols = maximum (List.map sol_most_distant_atom sols)

let run () = most_distant_atom (pseudoknot ())

let main () =
  for _ = 1 to 350 do
    print_float (run ());
    print_string "\n"
  done;
  assert (abs_float (run () -. 33.7976) < 0.0002)

(*
  Printf.printf "%.4f" (run ()); print_newline()
*)

let () = main ()
