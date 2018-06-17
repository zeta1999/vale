module X64.Memory_i_s

module I = Interop
module HS = FStar.HyperStack
module B = LowStar.Buffer
module M = LowStar.Modifies
module BV = LowStar.BufferView
module S = X64.Bytes_Semantics_s
module H = FStar.Heap

#reset-options "--initial_fuel 2 --max_fuel 2 --initial_ifuel 1 --max_ifuel 1"

let heap = H.heap
noeq type mem' = {
  addrs : I.addr_map;
  ptrs : list (B.buffer UInt8.t);
  hs : HS.mem;
  }

type mem = (m:mem'{I.list_disjoint_or_eq #UInt8.t m.ptrs /\
  I.list_live m.hs m.ptrs})

let op_String_Access = Map.sel
let op_String_Assignment = Map.upd

let coerce (#a:Type0) (b:Type0{a == b}) (x:a) : b = x

// TODO: Handle UInt128

let tuint8 = UInt8.t
let tuint16 = UInt16.t
let tuint32 = UInt32.t
let tuint64 = UInt64.t
// let tuint128 = magic()

let m_of_typ (t:typ) : Type0 =
  match t with
  | TBase TUInt8 -> tuint8
  | TBase TUInt16 -> tuint16
  | TBase TUInt32 -> tuint32
  | TBase TUInt64 -> tuint64
  | TBase TUInt128 -> quad32

let v_of_typ (t:typ) (v:type_of_typ t) :  (m_of_typ t) =
  match t with
  | TBase TUInt8 -> coerce ((m_of_typ t)) (UInt8.uint_to_t v)
  | TBase TUInt16 -> coerce ((m_of_typ t)) (UInt16.uint_to_t v)
  | TBase TUInt32 -> coerce ((m_of_typ t)) (UInt32.uint_to_t v)
  | TBase TUInt64 -> coerce ((m_of_typ t)) (UInt64.uint_to_t v)
  | TBase TUInt128 -> magic() //coerce (M.type_of_typ (m_of_typ t)) (UInt128.uint_to_t v)

let v_to_typ (t:typ) (v:(m_of_typ t)) : type_of_typ t =
  match t with
  | TBase TUInt8 -> UInt8.v (coerce UInt8.t v)
  | TBase TUInt16 -> UInt16.v (coerce UInt16.t v)
  | TBase TUInt32 -> UInt32.v (coerce UInt32.t v)
  | TBase TUInt64 -> UInt64.v (coerce UInt64.t v)
  | TBase TUInt128 -> magic()
  
let lemma_v_to_of_typ (t:typ) (v:type_of_typ t) : Lemma
  (ensures v_to_typ t (v_of_typ t v) == v)
  [SMTPat (v_to_typ t (v_of_typ t v))]
  =
  match t with
  | TBase TUInt8 -> assert (UInt8.v (UInt8.uint_to_t v) == v)
  | TBase TUInt16 -> assert (UInt16.v (UInt16.uint_to_t v) == v)
  | TBase TUInt32 -> assert (UInt32.v (UInt32.uint_to_t v) == v)
  | TBase TUInt64 -> assert (UInt64.v (UInt64.uint_to_t v) == v)
  | TBase TUInt128 -> admit()

let view_n = function
  | TBase TUInt8 -> 1
  | TBase TUInt16 -> 2
  | TBase TUInt32 -> 4
  | TBase TUInt64 -> 8
  | TBase TUInt128 -> 16

val uint8_view: (v:BV.view UInt8.t UInt8.t{BV.View?.n v == view_n (TBase TUInt8)})
val uint16_view: (v:BV.view UInt8.t UInt16.t{BV.View?.n v == view_n (TBase TUInt16)})
val uint32_view: (v:BV.view UInt8.t UInt32.t{BV.View?.n v == view_n (TBase TUInt32)})
val uint64_view: (v:BV.view UInt8.t UInt64.t{BV.View?.n v == view_n (TBase TUInt64)})
val uint128_view: (v:BV.view UInt8.t quad32{BV.View?.n v == view_n (TBase TUInt128)})

let uint8_view = Views.view8
let uint16_view = Views.view16
let uint32_view = Views.view32
let uint64_view = Views.view64
let uint128_view = Views.view128

val uint_view (t:typ) : (v:BV.view UInt8.t (m_of_typ t){BV.View?.n v == view_n t})

let uint_view = function
  | TBase TUInt8 -> uint8_view
  | TBase TUInt16 -> uint16_view
  | TBase TUInt32 -> uint32_view
  | TBase TUInt64 -> uint64_view
  | TBase TUInt128 -> uint128_view

let buffer t = (b:B.buffer UInt8.t{B.length b % view_n t == 0})

let buffer_as_seq #t h b =
  let s = BV.as_seq h.hs (BV.mk_buffer_view b (uint_view t)) in
  let len = Seq.length s in
  let contents (i:nat{i < len}) : type_of_typ t = v_to_typ t (Seq.index s i) in
  Seq.init len contents

let buffer_readable #t h b = List.memP b h.ptrs
let buffer_length #t b = BV.length (BV.mk_buffer_view b (uint_view t))
let loc = M.loc
let loc_none = M.loc_none
let loc_union = M.loc_union
let loc_buffer #t b = M.loc_buffer b
let loc_disjoint = M.loc_disjoint
let loc_includes = M.loc_includes
let modifies s h h' = 
  M.modifies s h.hs h'.hs /\ h.ptrs == h'.ptrs /\ h.addrs == h'.addrs

let valid_state s = s.state.S.mem == I.down_mem s.mem.hs s.mem.addrs s.mem.ptrs

let frame_valid s = ()

let get_heap h = I.down_mem h.hs h.addrs h.ptrs

let same_heap s1 s2 = ()

let buffer_addr #t b h =
  let addrs = h.addrs in
  addrs b

val index64_get_heap_val64 (h:mem)
			   (b:buffer64{List.memP b h.ptrs})
			   (heap:S.heap{I.correct_down h.hs h.addrs h.ptrs heap})
			   (i:nat{i < buffer_length b}) : Lemma
(Seq.index (buffer_as_seq h b) i == S.get_heap_val64 (buffer_addr b h + 8 `op_Multiply` i) heap)

#set-options "--z3rlimit 20"

let index64_get_heap_val64 h b heap i =
  let open FStar.Mul in
  let vb = BV.mk_buffer_view b uint64_view in
  let ptr = buffer_addr b h + 8 * i in
  let s = B.as_seq h.hs b in
  BV.length_eq vb;
  BV.view_indexing vb i;
  BV.as_buffer_mk_buffer_view b uint64_view;
  BV.get_view_mk_buffer_view b uint64_view;
  BV.as_seq_sel h.hs vb i;
  BV.get_sel h.hs vb i;
  Opaque_i.reveal_opaque S.get_heap_val64_def;
  ()

let modifies_goal_directed s h1 h2 = modifies s h1 h2
let lemma_modifies_goal_directed s h1 h2 = ()

let buffer_length_buffer_as_seq #t h b = ()

val same_underlying_seq (#t:typ) (h1 h2:mem) (b:buffer t) : Lemma
  (requires Seq.equal (B.as_seq h1.hs b) (B.as_seq h2.hs b))
  (ensures Seq.equal (buffer_as_seq h1 b) (buffer_as_seq h2 b))

let same_underlying_seq #t h1 h2 b =
  let rec aux (i:nat{i <= buffer_length b}) : Lemma
    (requires (forall (j:nat{j < i}). Seq.index (buffer_as_seq h1 b) j == Seq.index (buffer_as_seq h2 b) j) /\
    (Seq.equal (B.as_seq h1.hs b) (B.as_seq h2.hs b)))
    (ensures (forall (j:nat{j < buffer_length b}). Seq.index (buffer_as_seq h1 b) j == Seq.index (buffer_as_seq h2 b) j)) 
    (decreases %[(buffer_length b) - i]) =
    if i = buffer_length b then ()
    else (
      let bv = BV.mk_buffer_view b (uint_view t) in
      BV.as_buffer_mk_buffer_view b (uint_view t);
      BV.get_view_mk_buffer_view b (uint_view t);
      BV.get_sel h1.hs bv i;
      BV.get_sel h2.hs bv i;
      BV.as_seq_sel h1.hs bv i;
      BV.as_seq_sel h2.hs bv i;
      aux (i+1)
    )
  in aux 0

let modifies_buffer_elim #t1 b p h h' =
  M.modifies_buffer_elim b p h.hs h'.hs;
  assert (Seq.equal (B.as_seq h.hs b) (B.as_seq h'.hs b));
  same_underlying_seq h h' b;
  assert (Seq.equal (buffer_as_seq h b) (buffer_as_seq h' b));
  ()

let modifies_buffer_addr #t b p h h' = ()

let loc_disjoint_none_r s = M.loc_disjoint_none_r s
let loc_disjoint_union_r s s1 s2 = M.loc_disjoint_union_r s s1 s2
let loc_includes_refl s = M.loc_includes_refl s
let loc_includes_trans s1 s2 s3 = M.loc_includes_trans s1 s2 s3
let loc_includes_union_r s s1 s2 = M.loc_includes_union_r s s1 s2
let loc_includes_union_l s1 s2 s = M.loc_includes_union_l s1 s2 s
let loc_includes_union_l_buffer #t s1 s2 b = M.loc_includes_union_l s1 s2 (loc_buffer b)
let loc_includes_none s = M.loc_includes_none s
let modifies_refl s h = M.modifies_refl s h.hs
let modifies_goal_directed_refl s h = M.modifies_refl s h.hs
let modifies_loc_includes s1 h h' s2 = M.modifies_loc_includes s1 h.hs h'.hs s2
let modifies_trans s12 h1 h2 s23 h3 = M.modifies_trans s12 h1.hs h2.hs s23 h3.hs

let modifies_goal_directed_trans s12 h1 h2 s13 h3 =
  modifies_trans s12 h1 h2 s13 h3;
  modifies_loc_includes s13 h1 h3 (loc_union s12 s13);
  ()

let modifies_goal_directed_trans2 s12 h1 h2 s13 h3 = modifies_goal_directed_trans s12 h1 h2 s13 h3

let default_of_typ (t:typ) : type_of_typ t =
  match t with
  | TBase TUInt8 -> 0
  | TBase TUInt16 -> 0
  | TBase TUInt32 -> 0
  | TBase TUInt64 -> 0
  | TBase TUInt128 -> Words_s.Mkfour #nat32 0 0 0 0

let buffer_read #t b i h =
  if i < 0 || i >= buffer_length b then default_of_typ t else
  Seq.index (buffer_as_seq h b) i

val seq_upd (#b:_)
            (h:HS.mem)
            (vb:BV.buffer b{BV.live h vb})
            (i:nat{i < BV.length vb})
            (x:b)
  : Lemma (Seq.equal
      (Seq.upd (BV.as_seq h vb) i x)
      (BV.as_seq (BV.upd h vb i x) vb))

let seq_upd #b h vb i x =
  let old_s = BV.as_seq h vb in
  let new_s = BV.as_seq (BV.upd h vb i x) vb in
  let upd_s = Seq.upd old_s i x in
  let rec aux (k:nat) : Lemma 
    (requires (k <= Seq.length upd_s /\ (forall (j:nat). j < k ==> Seq.index upd_s j == Seq.index new_s j)))
    (ensures (forall (j:nat). j < Seq.length upd_s ==> Seq.index upd_s j == Seq.index new_s j))
    (decreases %[(Seq.length upd_s) - k]) =
    if k = Seq.length upd_s then ()
    else begin
      BV.sel_upd vb i k x h;
      BV.as_seq_sel h vb k;
      BV.as_seq_sel (BV.upd h vb i x) vb k;
      aux (k+1)
    end
  in aux 0;
  ()

let buffer_write #t b i v h =
 if i < 0 || i >= buffer_length b then h else
 begin
   let view = uint_view t in
   let bv = BV.mk_buffer_view b view in
   BV.as_buffer_mk_buffer_view b view;
   BV.upd_modifies h.hs bv i (v_of_typ t v);
   let hs' = BV.upd h.hs bv i (v_of_typ t v) in
   let h':mem = {h with hs = hs'} in
   seq_upd h.hs bv i (v_of_typ t v);
   assert (Seq.equal (buffer_as_seq h' b) (Seq.upd (buffer_as_seq h b) i v));
   h'
 end

val addr_in_ptr64: (addr:int) -> (ptr:buffer64) -> (h:mem) ->
  GTot (b:bool{ not b <==> (forall i. 0 <= i /\ i < buffer_length ptr ==> 
    addr <> (buffer_addr ptr h) + 8 `op_Multiply` i)})
  
// Checks if address addr corresponds to one of the elements of buffer ptr
let addr_in_ptr64 (addr:int) (ptr:buffer64) (h:mem) =
  let n = buffer_length ptr in
  let base = buffer_addr ptr h in
  let rec aux (i:nat) : Tot (b:bool{not b <==> (forall j. i <= j /\ j < n ==> 
    addr <> base + 8 `op_Multiply` j)}) 
    (decreases %[n-i]) =
    if i >= n then false
    else if addr = base + 8 `op_Multiply` i then true
    else aux (i+1)
  in aux 0

let rec get_addr_in_ptr64 (n base addr:nat) (i:nat{exists j. i <= j /\ j < n /\ base + 8 `op_Multiply` j == addr}) : 
    GTot (j:nat{base + 8 `op_Multiply` j == addr})
    (decreases %[n-i]) =
    if base + 8 `op_Multiply` i = addr then i
    else if i >= n then i
    else get_addr_in_ptr64 n base addr (i+1)

let valid_buffer64 (addr:int) (b:B.buffer UInt8.t) (h:mem) : GTot bool = B.length b % (view_n (TBase TUInt64)) = 0 && (addr_in_ptr64 addr b h)

let rec valid_mem_aux64 addr (ps:list (B.buffer UInt8.t)) (h:mem) : GTot (b:bool{
  (not b) <==> (forall (x:buffer64). (List.memP x ps ==> not (valid_buffer64 addr x h) ))}) 
  = match ps with
    | [] -> false
    | a::q -> if valid_buffer64 addr a h then true else valid_mem_aux64 addr q h

let valid_mem64 ptr h = valid_mem_aux64 ptr h.ptrs h

let rec load_mem_aux64 addr (ps:list (B.buffer UInt8.t)) (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs }) : 
  GTot nat64 =
  match ps with
  | [] -> 0
  | a::q ->
    if valid_buffer64 addr a h then
    begin
      let a:buffer64 = a in
      let base = buffer_addr a h in
      buffer_read a (get_addr_in_ptr64 (buffer_length a) base addr 0) h
    end
    else load_mem_aux64 addr q h

let load_mem64 ptr h =
  if not (valid_mem64 ptr h) then 0
  else load_mem_aux64 ptr h.ptrs h

let length64_eq (b:buffer64) : Lemma (B.length b == buffer_length b `op_Multiply` 8) =
  BV.as_buffer_mk_buffer_view b uint64_view;
  BV.get_view_mk_buffer_view b uint64_view;
  BV.length_eq (BV.mk_buffer_view b uint64_view)


let rec get_addr_ptr64 (ptr:int) (h:mem) (ps:list (B.buffer UInt8.t){valid_mem_aux64 ptr ps h}) : 
  GTot (b:buffer64{List.memP b ps /\ valid_buffer64 ptr b h}) =
  match ps with
  // The list cannot be empty because of the mem predicate
  | a::q -> if valid_buffer64 ptr a h then a else get_addr_ptr64 ptr h q

let rec load_buffer_read64 (ptr:int) (h:mem) 
  (ps:list (B.buffer UInt8.t){I.list_disjoint_or_eq ps /\ valid_mem_aux64 ptr ps h /\
    (forall x. List.memP x ps ==> List.memP x h.ptrs)}) : Lemma
  (let b = get_addr_ptr64 ptr h ps in
   length64_eq b;
   let i = get_addr_in_ptr64 (buffer_length b) (buffer_addr b h) ptr 0 in
   load_mem_aux64 ptr ps h == buffer_read b i h) =
      match ps with
      | [] -> ()
      | a::q ->
        if valid_buffer64 ptr a h then () else load_buffer_read64 ptr h q    

let rec store_mem_aux64 addr (ps:list (B.buffer UInt8.t)) (v:nat64) (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs }) : 
  GTot (h1:mem{h.addrs == h1.addrs /\ h.ptrs == h1.ptrs }) =
  match ps with
  | [] -> h
  | a::q ->
    if valid_buffer64 addr a h then
    begin
      let a:buffer64 = a in
      let base = buffer_addr a h in
      buffer_write a (get_addr_in_ptr64 (buffer_length a) base addr 0) v h
    end
    else store_mem_aux64 addr q v h

let store_mem64 i v h =
  if not (valid_mem64 i h) then h
  else store_mem_aux64 i h.ptrs v h

let rec store_buffer_write64 (ptr:int) (v:nat64) (h:mem) 
  (ps:list (B.buffer UInt8.t){I.list_disjoint_or_eq ps /\ valid_mem_aux64 ptr ps h /\
    (forall x. List.memP x ps ==> List.memP x h.ptrs)}) : Lemma
  (let b = get_addr_ptr64 ptr h ps in
   length64_eq b;
   let i = get_addr_in_ptr64 (buffer_length b) (buffer_addr b h) ptr 0 in
   store_mem_aux64 ptr ps v h == buffer_write b i v h) =
      match ps with
      | [] -> ()
      | a::q ->
        if valid_buffer64 ptr a h then () else store_buffer_write64 ptr v h q   

let valid_mem128 ptr h = admit()
let load_mem128 ptr h = admit()
let store_mem128 ptr v h = admit()

let lemma_valid_mem64 b i h = ()

#set-options "--z3rlimit 20"

let lemma_load_mem64 b i h =
  let addr = buffer_addr b h + 8 `op_Multiply` i in
  lemma_valid_mem64 b i h;
  let rec aux (ps:list (B.buffer UInt8.t){I.list_disjoint_or_eq ps})
    (h0:mem{h == h0 /\ (forall x. List.memP x ps ==> List.memP x h0.ptrs)}) :  
    Lemma (requires (List.memP b ps /\ i < buffer_length b) )
    (ensures (load_mem_aux64 addr ps h0 == buffer_read b i h0)) = 
    match ps with
    | [] -> ()
    | a::q ->
      if valid_buffer64 addr a h0 then begin
        let a:buffer64 = a in
	BV.length_eq (BV.mk_buffer_view a uint64_view);
	BV.get_view_mk_buffer_view a uint64_view;
	BV.as_buffer_mk_buffer_view a uint64_view;	
	BV.length_eq (BV.mk_buffer_view b uint64_view);
	BV.get_view_mk_buffer_view b uint64_view;
	BV.as_buffer_mk_buffer_view b uint64_view;

	assert (I.disjoint_or_eq a b);
	assert (a == b);
  	()
      end
      else begin
        assert (b =!= a);
  	aux q h0
      end
  in aux h.ptrs h  

let lemma_store_mem64 b i v h =
  let addr = buffer_addr b h + 8 `op_Multiply` i in
  lemma_valid_mem64 b i h;
  let rec aux (ps:list (B.buffer UInt8.t){I.list_disjoint_or_eq ps})
    (h0:mem{h == h0 /\ (forall x. List.memP x ps ==> List.memP x h0.ptrs)}) :  
    Lemma (requires (List.memP b ps /\ i < buffer_length b) )
    (ensures (store_mem_aux64 addr ps v h0 == buffer_write b i v h0)) = 
    match ps with
    | [] -> ()
    | a::q ->
      if valid_buffer64 addr a h0 then begin
	let a:buffer64 = a in
	BV.length_eq (BV.mk_buffer_view a uint64_view);
	BV.get_view_mk_buffer_view a uint64_view;
	BV.as_buffer_mk_buffer_view a uint64_view;	
	BV.length_eq (BV.mk_buffer_view b uint64_view);
	BV.get_view_mk_buffer_view b uint64_view;
	BV.as_buffer_mk_buffer_view b uint64_view;

	assert (I.disjoint_or_eq a b);
	assert (a == b);
  	()
      end
      else begin
        assert (b =!= a);
  	aux q h0
      end
  in aux h.ptrs h

let lemma_valid_mem128 b i h = admit()
let lemma_load_mem128 b i h = admit()
let lemma_store_mem128 b i v h = admit()

let rec same_get_addr_ptr64 (ptr:int)
			(h:mem) 
			(ps:list (B.buffer UInt8.t){valid_mem_aux64 ptr ps h})
			(b:buffer64{List.memP b h.ptrs}) 
			(i:nat{i < buffer_length b}) 
			(v:nat64) : Lemma
  (let h1 = buffer_write b i v h in
  get_addr_ptr64 ptr h ps == get_addr_ptr64 ptr h1 ps) =
  match ps with
  | a::q -> if valid_buffer64 ptr a h then () else same_get_addr_ptr64 ptr h q b i v

let lemma_store_load_mem64 ptr v h =
  let h1 = store_mem64 ptr v h in
  store_buffer_write64 ptr v h h.ptrs;  
  load_buffer_read64 ptr h1 h1.ptrs;    
  let b = get_addr_ptr64 ptr h h.ptrs in
  length64_eq b;
  let i = get_addr_in_ptr64 (buffer_length b) (buffer_addr b h) ptr 0 in
  same_get_addr_ptr64 ptr h h.ptrs b i v;
  BV.as_buffer_mk_buffer_view b uint64_view;
  BV.as_seq_sel h1.hs (BV.mk_buffer_view b uint64_view) i;
  ()

val different_addr_ptr64 (i:int) (i':nat{i <> i'}) 
		       (h:mem{valid_mem64 i h /\ valid_mem64 i' h}) : Lemma
  (get_addr_ptr64 i h h.ptrs =!= get_addr_ptr64 i' h h.ptrs \/
    (let b = get_addr_ptr64 i h h.ptrs in
     let b' = get_addr_ptr64 i' h h.ptrs in
     b == b' /\ get_addr_in_ptr64 (buffer_length b) (buffer_addr b h) i 0 <>
      get_addr_in_ptr64 (buffer_length b) (buffer_addr b h) i' 0))

let rec different_addr_in_ptr64 (n base:nat) (addr1 addr2:nat) (i:nat{
  (exists j. i <= j /\ j < n /\ base + 8 `op_Multiply` j == addr1) /\
  (exists k. i <= k /\ k < n /\ base + 8 `op_Multiply` k == addr2)}) : Lemma
  (requires addr1 <> addr2)
  (ensures get_addr_in_ptr64 n base addr1 i <> get_addr_in_ptr64 n base addr2 i)
  (decreases %[n-i]) =
   if (base + 8 `op_Multiply` i = addr1) || (base + 8 `op_Multiply` i = addr2) || i >= n then ()
   else different_addr_in_ptr64 n base addr1 addr2 (i+1)

let different_addr_ptr64 i i' h =
  let rec aux (ps:list (B.buffer UInt8.t){valid_mem_aux64 i ps h /\ valid_mem_aux64 i' ps h}) :
    Lemma (get_addr_ptr64 i h ps =!= get_addr_ptr64 i' h ps \/
    (let b = get_addr_ptr64 i h ps in
     let b' = get_addr_ptr64 i' h ps in
     b == b' /\ get_addr_in_ptr64 (buffer_length b) (buffer_addr b h) i 0 <>
      get_addr_in_ptr64 (buffer_length b) (buffer_addr b h) i' 0)) =
     match ps with
     | a::q -> if valid_buffer64 i a h then begin
       if valid_buffer64 i' a h then begin
         assert (get_addr_ptr64 i h ps == a);
	 assert (get_addr_ptr64 i' h ps == a);
	 let a:buffer64 = a in
	 length64_eq a;
	 different_addr_in_ptr64 (buffer_length a) (buffer_addr a h) i i' 0
       end
       else ()
       end else if valid_buffer64 i' a h then ()
       else aux q
  in aux h.ptrs


let lemma_frame_store_mem64 ptr v h =
  let h1 = store_mem64 ptr v h in
  let aux i' : Lemma 
    (requires i' <> ptr /\ valid_mem64 ptr h /\ valid_mem64 i' h)
    (ensures load_mem64 i' h == load_mem64 i' h1) =
    store_buffer_write64 ptr v h h.ptrs;  
    load_buffer_read64 i' h1 h1.ptrs;
    load_buffer_read64 i' h h.ptrs;
    let b1 = get_addr_ptr64 ptr h h.ptrs in
    let i1 = get_addr_in_ptr64 (buffer_length b1) (buffer_addr b1 h) ptr 0 in
    let b2 = get_addr_ptr64 i' h h.ptrs in
    let i2 = get_addr_in_ptr64 (buffer_length b2) (buffer_addr b2 h) i' 0 in
    same_get_addr_ptr64 i' h h.ptrs b1 i1 v;
    BV.as_buffer_mk_buffer_view b1 uint64_view;
    BV.upd_modifies h.hs (BV.mk_buffer_view b1 uint64_view) i1 (v_of_typ (TBase TUInt64) v);
    assert (load_mem64 i' h == buffer_read b2 i2 h);
    assert (load_mem64 i' h1 == buffer_read b2 i2 h1);
    different_addr_ptr64 ptr i' h;
    let aux_diff_buf () : Lemma
      (requires b1 =!= b2)
      (ensures load_mem64 i' h == load_mem64 i' h1) =
      BV.as_seq_sel h.hs (BV.mk_buffer_view b2 uint64_view) i2;    
      BV.as_seq_sel h1.hs (BV.mk_buffer_view b2 uint64_view) i2
    in let aux_same_buf () : Lemma
      (requires i1 <> i2 /\ b1 == b2)
      (ensures load_mem64 i' h == load_mem64 i' h1) =
      BV.sel_upd (BV.mk_buffer_view b2 uint64_view) i1 i2 (v_of_typ (TBase TUInt64) v) h.hs
    in
    Classical.move_requires aux_diff_buf ();
    Classical.move_requires aux_same_buf ();
    ()
  in Classical.forall_intro (Classical.move_requires aux)

let lemma_valid_store_mem64 i v h = ()

let lemma_store_load_mem128 ptr v h = admit()
let lemma_frame_store_mem128 ptr v h = admit()
let lemma_valid_store_mem128 ptr v h = admit()

#set-options "--z3rlimit 100"

val heap_shift (m1 m2:S.heap) (base:int) (n:nat) : Lemma
  (requires (forall i. 0 <= i /\ i < n ==> m1.[base + i] == m2.[base + i]))
  (ensures (forall i. {:pattern (m1.[i])} base <= i /\ i < base + n ==> m1.[i] == m2.[i]))
	      
let heap_shift m1 m2 base n =
  assert (forall i. base <= i /\ i < base + n ==>
    m1.[base + (i - base)] == m2.[base + (i - base)])

val same_mem_get_heap_val (b:buffer64)
			  (i:nat{i < buffer_length b})
			  (v:nat64)
			  (k:nat{k < buffer_length b})
			  (h1:mem{List.memP b h1.ptrs})
			  (h2:mem{h2 == buffer_write b i v h1})
			  (mem1:S.heap{I.correct_down_p h1.hs h1.addrs mem1 b})
			  (mem2:S.heap{I.correct_down_p h2.hs h2.addrs mem2 b}) : Lemma
  (requires (Seq.index (buffer_as_seq h1 b) k == Seq.index (buffer_as_seq h2 b) k))			  
  (ensures (let ptr = buffer_addr b h1 + 8 `op_Multiply` k in 
    forall i. {:pattern (mem1.[ptr+i])} i >= 0 /\ i < 8 ==> mem1.[ptr+i] == mem2.[ptr+i]))

val same_mem_eq_slices (b:buffer64)
		       (i:nat{i < buffer_length b})
		       (v:nat64)
		       (k:nat{k < buffer_length b})
		       (h1:mem{List.memP b h1.ptrs})
		       (h2:mem{h2 == buffer_write b i v h1})
		       (mem1:S.heap{I.correct_down_p h1.hs h1.addrs mem1 b})
		       (mem2:S.heap{I.correct_down_p h2.hs h2.addrs mem2 b}) : Lemma
  (requires (Seq.index (buffer_as_seq h1 b) k == Seq.index (buffer_as_seq h2 b) k))
  (ensures (let open FStar.Mul in
    k * 8 + 8 <= B.length b /\
    Seq.slice (B.as_seq h1.hs b) (k * 8) (k * 8 + 8) ==
    Seq.slice (B.as_seq h2.hs b) (k * 8) (k * 8 + 8)))

let same_mem_eq_slices b i v k h1 h2 mem1 mem2 = 
    BV.as_seq_sel h1.hs (BV.mk_buffer_view b uint64_view) k;
    BV.as_seq_sel h2.hs (BV.mk_buffer_view b uint64_view) k;
    BV.put_sel h1.hs (BV.mk_buffer_view b uint64_view) k;
    BV.put_sel h2.hs (BV.mk_buffer_view b uint64_view) k;
    BV.as_buffer_mk_buffer_view b uint64_view;
    BV.get_view_mk_buffer_view b uint64_view;
    BV.view_indexing (BV.mk_buffer_view b uint64_view) k;
    BV.length_eq (BV.mk_buffer_view b uint64_view)

let same_mem_get_heap_val b j v k h1 h2 mem1 mem2 =
  let ptr = buffer_addr b h1 + 8 `op_Multiply` k in
  let aux (i:nat{i < 8}) : Lemma (mem1.[ptr+i] == mem2.[ptr+i]) =
    BV.as_seq_sel h1.hs (BV.mk_buffer_view b uint64_view) k;
    BV.as_seq_sel h2.hs (BV.mk_buffer_view b uint64_view) k;
    same_mem_eq_slices b j v k h1 h2 mem1 mem2;
    let open FStar.Mul in
    let s1 = (Seq.slice (B.as_seq h1.hs b) (k * 8) (k * 8 + 8)) in
    let s2 = (Seq.slice (B.as_seq h2.hs b) (k * 8) (k * 8 + 8)) in
    assert (Seq.index s1 i == Seq.index (B.as_seq h1.hs b) (k * 8 + i));
    assert (UInt8.v (Seq.index s1 i) == mem1.[ptr+i]);
    assert (Seq.index s2 i == Seq.index (B.as_seq h2.hs b) (k * 8 + i));
    assert (UInt8.v (Seq.index s2 i) == mem2.[ptr+i]);
    ()
  in
  Classical.forall_intro aux;
  ()

let rec written_buffer_down64_aux1 (b:buffer64) (i:nat{i < buffer_length b}) (v:nat64)
      (ps:list (B.buffer UInt8.t){I.list_disjoint_or_eq ps /\ List.memP b ps})
      (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs})
      (base:nat{base == buffer_addr b h})
      (k:nat) (h1:mem{h1 == buffer_write b i v h}) 
      (mem1:S.heap{I.correct_down h.hs h.addrs ps mem1}) 
      (mem2:S.heap{
      (I.correct_down h1.hs h.addrs ps mem2) /\
      (forall j. base <= j /\ j < base + k `op_Multiply` 8 ==> mem1.[j] == mem2.[j])}) : 
      Lemma (requires True)
      (ensures (forall j. j >= base /\ j < base + 8 `op_Multiply` i ==> mem1.[j] == mem2.[j]))
      (decreases %[i-k]) =
    if k >= i then ()
    else begin
      let ptr = base + 8 `op_Multiply` k in
      same_mem_get_heap_val b i v k h h1 mem1 mem2;
      heap_shift mem1 mem2 ptr 8;
      written_buffer_down64_aux1 b i v ps h base (k+1) h1 mem1 mem2
    end

let rec written_buffer_down64_aux2 (b:buffer64) (i:nat{i < buffer_length b}) (v:nat64)
      (ps:list (B.buffer UInt8.t){I.list_disjoint_or_eq ps /\ List.memP b ps})
      (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs})
      (base:nat{base == buffer_addr b h})
      (n:nat{n == buffer_length b})
      (k:nat{k > i}) (h1:mem{h1 == buffer_write b i v h}) 
      (mem1:S.heap{I.correct_down h.hs h.addrs ps mem1}) 
      (mem2:S.heap{
      (I.correct_down h1.hs h.addrs ps mem2) /\
      (forall j. base + 8 `op_Multiply` (i+1) <= j /\ j < base + k `op_Multiply` 8 ==>
      mem1.[j] == mem2.[j])}) :
      Lemma 
      (requires True)
      (ensures (forall j. j >= base + 8 `op_Multiply` (i+1) /\ j < base + 8 `op_Multiply` n ==> 
	mem1.[j] == mem2.[j]))
      (decreases %[n-k]) =
    if k >= n then ()
    else begin
      let ptr = base + 8 `op_Multiply` k in
      same_mem_get_heap_val b i v k h h1 mem1 mem2;
      heap_shift mem1 mem2 ptr 8;
      written_buffer_down64_aux2 b i v ps h base n (k+1) h1 mem1 mem2
    end
    
let written_buffer_down64 (b:buffer64) (i:nat{i < buffer_length b}) (v:nat64)
  (ps: list (B.buffer UInt8.t){I.list_disjoint_or_eq ps /\ List.memP b ps}) (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs}) :
  Lemma (
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    let base = buffer_addr b h in
    let n = buffer_length b in
    forall j. (base <= j /\ j < base + 8 `op_Multiply` i) \/ 
	 (base + 8 `op_Multiply` (i+1) <= j /\ j < base + 8 `op_Multiply` n) ==>
	 mem1.[j] == mem2.[j]) = 
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in	 
    let base = buffer_addr b h in
    let n = buffer_length b in
    written_buffer_down64_aux1 b i v ps h base 0 h1 mem1 mem2;
    written_buffer_down64_aux2 b i v ps h base n (i+1) h1 mem1 mem2

#set-options "--z3rlimit 50"

let unwritten_buffer_down64_aux (b:buffer64) (i:nat{i < buffer_length b}) (v:nat64)
  (ps: list (B.buffer UInt8.t){I.list_disjoint_or_eq ps /\ List.memP b ps})
  (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs})
  (a:B.buffer UInt8.t{a =!= b /\ List.memP a ps})  : 
  Lemma (let base = h.addrs a in
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    forall j. j >= base /\ j < base + B.length a ==> mem1.[j] == mem2.[j]) =
    if B.length a = 0 then ()
    else
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    let base = h.addrs a in    
    let s0 = B.as_seq h.hs a in
    let s1 = B.as_seq h1.hs a in
    assert (B.disjoint a b);
    heap_shift mem1 mem2 base (B.length a)

let unwritten_buffer_down64 (b:buffer64) (i:nat{i < buffer_length b}) (v:nat64)
  (ps: list (B.buffer UInt8.t){I.list_disjoint_or_eq ps /\ List.memP b ps}) 
  (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs}) : Lemma (
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    forall  (a:B.buffer UInt8.t{List.memP a ps /\ a =!= b}) j.
    let base = h.addrs a in 
    j >= base /\ j < base + B.length a ==> mem1.[j] == mem2.[j]) =
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in   
    let fintro (a:B.buffer UInt8.t{List.memP a ps /\ a =!= b}) 
      : Lemma 
      (forall j. let base = h.addrs a in
      j >= base /\ j < base + B.length a ==> 
	mem1.[j] == mem2.[j]) =
      let base = h.addrs a in
      unwritten_buffer_down64_aux b i v ps h a
    in
    Classical.forall_intro fintro

let store_buffer_down64_mem (b:buffer64) (i:nat{i < buffer_length b}) (v:nat64)
  (ps: list (B.buffer UInt8.t){I.list_disjoint_or_eq ps /\ List.memP b ps})
  (h:mem{forall x. List.memP x ps ==> List.memP x h.ptrs}) :
  Lemma (
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    let base = buffer_addr b h in
    forall j. j < base + 8 `op_Multiply` i \/ j >= base + 8 `op_Multiply` (i+1) ==>
      mem1.[j] == mem2.[j]) =
    let mem1 = I.down_mem h.hs h.addrs ps in
    let h1 = buffer_write b i v h in
    let mem2 = I.down_mem h1.hs h.addrs ps in
    let base = buffer_addr b h in
    let n = buffer_length b in
    let aux (j:int) : Lemma
      (j < base + 8 `op_Multiply` i \/ j >= base + 8 `op_Multiply` (i+1) ==>
      mem1.[j] == mem2.[j]) =
        if j >= base && j < base + B.length b then begin
	  written_buffer_down64 b i v ps h;
	  length64_eq b
	end
	else (
	I.same_unspecified_down h.hs h1.hs h.addrs ps;
	unwritten_buffer_down64 b i v ps h;
	()
	)
    in Classical.forall_intro aux
    
let store_buffer_aux_down64_mem (ptr:int) (v:nat64) (h:mem{valid_mem64 ptr h}) : Lemma (
  let mem1 = I.down_mem h.hs h.addrs h.ptrs in
  let h1 = store_mem_aux64 ptr h.ptrs v h in
  let mem2 = I.down_mem h1.hs h.addrs h.ptrs in
  forall j. j < ptr \/ j >= ptr + 8 ==> mem1.[j] == mem2.[j]) =
  let h1 = store_mem_aux64 ptr h.ptrs v h in
  let b = get_addr_ptr64 ptr h h.ptrs in
  length64_eq b;
  let i = get_addr_in_ptr64 (buffer_length b) (buffer_addr b h) ptr 0 in
  store_buffer_write64 ptr v h h.ptrs;
  assert (buffer_addr b h + 8 `op_Multiply` i == ptr);
  assert (buffer_addr b h + 8 `op_Multiply` (i+1) == ptr + 8);
  store_buffer_down64_mem b i v h.ptrs h

let store_buffer_aux_down64_mem2 (ptr:int) (v:nat64) (h:mem{valid_mem64 ptr h}) : Lemma (
  let h1 = store_mem_aux64 ptr h.ptrs v h in
  let mem2 = I.down_mem h1.hs h.addrs h.ptrs in
  S.get_heap_val64 ptr mem2 == v) =
  let b = get_addr_ptr64 ptr h h.ptrs in
  length64_eq b;
  let i = get_addr_in_ptr64 (buffer_length b) (buffer_addr b h) ptr 0 in
  let h1 = store_mem_aux64 ptr h.ptrs v h in
  let mem2 = I.down_mem h1.hs h.addrs h.ptrs in
  store_buffer_write64 ptr v h h.ptrs;  
  assert (Seq.index (buffer_as_seq h1 b) i == v);
  index64_get_heap_val64 h1 b mem2 i;
  ()


let valid_state_store_mem64 i v (s:state) =
  if not (valid_mem64 i s.mem) then ()
  else
    let s' = S.update_mem i v s.state in
    let h1 = store_mem_aux64 i s.mem.ptrs v s.mem in
    let s' = {s with state = s'; mem = h1} in
    store_buffer_aux_down64_mem i v s.mem;
    store_buffer_aux_down64_mem2 i v s.mem;
    let mem1 = s'.state.S.mem in
    let mem2 = I.down_mem s'.mem.hs s.mem.addrs s.mem.ptrs in
    Bytes_Semantics_i.same_mem_get_heap_val i mem1 mem2;
    Bytes_Semantics_i.correct_update_get i v s.state.S.mem;
    Bytes_Semantics_i.frame_update_heap i v s.state.S.mem;
    assert (forall j. mem1.[j] == mem2.[j]);
    assert (Map.equal mem1 mem2);
    ()

let valid_state_store_mem128 ptr v s = admit()