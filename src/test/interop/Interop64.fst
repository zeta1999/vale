module Interop64

(** Test of the interop with buffers of UInt64 *)

module List = FStar.List.Tot.Base
module HS = FStar.Monotonic.HyperStack
module HH = FStar.Monotonic.HyperHeap
module B = FStar.Buffer

open Machine_int
open Vale_Sem

let op_String_Access = Map.sel
let op_String_Assignment = Map.upd

let sub l i = l - i

let disjoint_or_eq ptr1 ptr2 = B.disjoint ptr1 ptr2 \/ ptr1 == ptr2

let list_disjoint_or_eq (#a:Type0) (ptrs:list (B.buffer a)) =
  forall p1 p2. List.memP p1 ptrs /\ List.memP p2 ptrs ==> disjoint_or_eq p1 p2

(* Abstract maps linking buffers to addresses in the Vale heap. A buffer is uniquely identified by its address, idx and length. TODO : Add Type? *)
type buffer_triple = nat * nat * nat
let disjoint_addr addr1 length1 addr2 length2 =
  (* The first buffer is completely before the second, or the opposite *)
  addr1 + (8 `op_Multiply` length1) < addr2 || addr2 + (8 `op_Multiply` length2) < addr1

type addr_map = (m:(Map.t buffer_triple nat64){forall (buf1 buf2:B.buffer UInt64.t). B.disjoint buf1 buf2 ==> disjoint_addr (m.[(B.as_addr buf1, B.idx buf1, B.length buf1)]) (B.length buf1)
  (m.[(B.as_addr buf2, B.idx buf2, B.length buf2)]) (B.length buf2)})

(* Additional hypotheses, which should be added to the corresponding libraries at some point *)

(* If two refs have the same address, and are in the heap, they are equal *)
assume val ref_extensionality (#a:Type0) (#rel:Preorder.preorder a) (h:Heap.heap) (r1 r2:Heap.mref a rel) : Lemma 
  (Heap.contains h r1 /\ Heap.contains h r2 /\ Heap.addr_of r1 = Heap.addr_of r2 ==> r1 == r2)

#set-options "--z3rlimit 60"

let rec write_vale_mem64 (contents:Seq.seq UInt64.t) (length:nat{length = FStar.Seq.Base.length contents}) addr (i:nat{i <= length}) 
      (curr_heap:Vale_Sem.heap{forall j. {:pattern (Seq.index contents j)} 
	0 <= j /\ j < i ==> get_heap_val (addr + (j `op_Multiply` 8)) curr_heap == UInt64.v (Seq.index contents j)}) : Tot Vale_Sem.heap (decreases %[sub length i]) =
    if i >= length then curr_heap
    else
      write_vale_mem64 contents length addr (i + 1) (update_heap (addr + (i `op_Multiply` 8)) (UInt64.v (FStar.Seq.index contents i)) curr_heap)

#set-options "--z3refresh --z3rlimit 300 --max_fuel 2 --max_ifuel 1"

let rec frame_write_vale_mem64 (contents:Seq.seq UInt64.t) (length:nat{length = FStar.Seq.Base.length contents}) addr (i:nat{i <= length}) 
      (curr_heap:Vale_Sem.heap{forall j. {:pattern (Seq.index contents j)}
	0 <= j /\ j < i ==> get_heap_val (addr + (j `op_Multiply` 8)) curr_heap == UInt64.v (Seq.index contents j)}) : Lemma
      (requires True)
      (ensures (let new_heap = write_vale_mem64 contents length addr i curr_heap in
      forall j. j < addr \/ j >= addr + (length `op_Multiply` 8) ==> curr_heap.[j] == new_heap.[j]))
      (decreases %[sub length i])=
      if i >= length then ()
      else begin
      let new_heap = update_heap (addr + (i `op_Multiply` 8)) (UInt64.v (FStar.Seq.index contents i)) curr_heap in
      frame_update_heap (addr + (i `op_Multiply` 8)) (UInt64.v (FStar.Seq.index contents i)) curr_heap;
      let helper(j:nat) : Lemma(0 <= j /\ j < i + 1 ==> j < FStar.Seq.Base.length contents /\ get_heap_val (addr + (j `op_Multiply` 8)) new_heap == UInt64.v (Seq.index contents j)) =
        if 0 <= j && j < i then assert (get_heap_val (addr + (j `op_Multiply` 8)) new_heap == UInt64.v (Seq.index contents j))
	else if j = i then begin
	  correct_update_get (addr + (i `op_Multiply` 8)) (UInt64.v (FStar.Seq.index contents i)) curr_heap;
	  assert (get_heap_val (addr + (i `op_Multiply` 8)) new_heap == UInt64.v (Seq.index contents i));
	  ()
	end
	else ()
      in
      Classical.forall_intro helper;
      let (new_heap : Vale_Sem.heap{(forall j. {:pattern (Seq.index contents j)} 0 <= j /\ j < i+1 ==> get_heap_val (addr + (j `op_Multiply` 8)) new_heap == UInt64.v (Seq.index contents j))}) = new_heap in
      assert (sub length (i+1) < sub length i);
      frame_write_vale_mem64 contents length addr (i+1) new_heap
      end


let rec load_store_write_vale_mem64 (contents:Seq.seq UInt64.t) (length:nat{length = FStar.Seq.Base.length contents}) addr (i:nat{i <= length}) 
      (curr_heap:Vale_Sem.heap{forall j. {:pattern (Seq.index contents j)} 0 <= j /\ j < i ==> get_heap_val (addr + (j `op_Multiply` 8)) curr_heap == UInt64.v (Seq.index contents j)}) : Lemma
      (requires True)
      (ensures (let new_heap = write_vale_mem64 contents length addr i curr_heap in
      forall j. {:pattern (Seq.index contents j)} 0 <= j /\ j < length ==> UInt64.v (Seq.index contents j) == get_heap_val (addr + (j `op_Multiply` 8)) new_heap))
      (decreases %[sub length i])=
      if i >= length then ()
      else begin
      let new_heap = update_heap (addr + (i `op_Multiply` 8)) (UInt64.v (FStar.Seq.index contents i)) curr_heap in
      frame_update_heap (addr + (i `op_Multiply` 8)) (UInt64.v (FStar.Seq.index contents i)) curr_heap;
      let helper(j:nat) : Lemma(0 <= j /\ j < i + 1 ==> j < FStar.Seq.Base.length contents /\ get_heap_val (addr + (j `op_Multiply` 8)) new_heap == UInt64.v (Seq.index contents j)) =
        if 0 <= j && j < i then assert (get_heap_val (addr + (j `op_Multiply` 8)) new_heap == UInt64.v (Seq.index contents j))
	else if j = i then begin
	  correct_update_get (addr + (i `op_Multiply` 8)) (UInt64.v (FStar.Seq.index contents i)) curr_heap;
	  assert (get_heap_val (addr + (i `op_Multiply` 8)) new_heap == UInt64.v (Seq.index contents i));
	  ()
	end
	else ()
      in
      Classical.forall_intro helper;
      let (new_heap : Vale_Sem.heap{(forall j. {:pattern (Seq.index contents j)} 0 <= j /\ j < i+1 ==> get_heap_val (addr + (j `op_Multiply` 8)) new_heap == UInt64.v (Seq.index contents j))}) = new_heap in
      assert (sub length (i+1) < sub length i);
      load_store_write_vale_mem64 contents length addr (i+1) new_heap
      end

let correct_down_p64 mem (addrs:addr_map) heap (p:B.buffer UInt64.t) =
  let length = B.length p in
  let contents = B.as_seq mem p in
  let addr = addrs.[(B.as_addr p, B.idx p, length)] in
  (forall i. {:pattern (Seq.index contents i)} 0 <= i /\ i < length ==> get_heap_val (addr + (i `op_Multiply` 8)) heap == UInt64.v (Seq.index contents i))

#set-options "--z3rlimit 100"

let correct_down_p64_cancel mem (addrs:addr_map) heap (p:B.buffer UInt64.t) : Lemma
  (forall p'. p == p' ==>       
      (let length = B.length p in
      let contents = B.as_seq mem p in
      let addr = addrs.[(B.as_addr p, B.idx p, B.length p)] in
      let new_heap = write_vale_mem64 contents length addr 0 heap in
      correct_down_p64 mem addrs new_heap p')) = 
  let rec aux (p':B.buffer UInt64.t) : Lemma 
    (p == p'  ==> (let length = B.length p in
      let contents = B.as_seq mem p in
      let addr = addrs.[(B.as_addr p, B.idx p, B.length p)] in
      let new_heap = write_vale_mem64 contents length addr 0 heap in
      correct_down_p64 mem addrs new_heap p')) =
        let length = B.length p in
        let contents = B.as_seq mem p in
        let addr = addrs.[(B.as_addr p, B.idx p, B.length p)] in
        let new_heap = write_vale_mem64 contents length addr 0 heap in
	load_store_write_vale_mem64 contents length addr 0 heap
  in
  Classical.forall_intro aux

let correct_down_p64_frame mem (addrs:addr_map) heap (p:B.buffer UInt64.t) : Lemma
  (forall (p':B.buffer UInt64.t). B.disjoint p p' /\ correct_down_p64 mem addrs heap p' ==>       
      (let length = B.length p in
      let contents = B.as_seq mem p in
      let addr = addrs.[(B.as_addr p, B.idx p, B.length p)] in
      let new_heap = write_vale_mem64 contents length addr 0 heap in
      correct_down_p64 mem addrs new_heap p')) = 
  let rec aux (p':B.buffer UInt64.t) : Lemma 
    (B.disjoint p p' /\ correct_down_p64 mem addrs heap p' ==> (let length = B.length p in
      let contents = B.as_seq mem p in
      let addr = addrs.[(B.as_addr p, B.idx p, B.length p)] in
      let new_heap = write_vale_mem64 contents length addr 0 heap in
      correct_down_p64 mem addrs new_heap p')) =
        let length = B.length p in
        let contents = B.as_seq mem p in
        let addr = addrs.[(B.as_addr p, B.idx p, B.length p)] in
	let addr' = addrs.[(B.as_addr p', B.idx p', B.length p')] in
        let new_heap = write_vale_mem64 contents length addr 0 heap in
	frame_write_vale_mem64 contents length addr 0 heap;
	assert (B.disjoint p p' ==> (forall i. 0 <= i /\ i < 8 `op_Multiply` B.length p' ==> addr' + i < addr \/ addr + (8 `op_Multiply` length) < addr' + i));
	assert (B.disjoint p p' ==> (forall i. 0 <= i /\ i < 8 `op_Multiply` B.length p' ==> heap.[addr' + i] == new_heap.[addr' + i]));
	()
  in
  Classical.forall_intro aux


let correct_down64 mem (addrs:addr_map) (ptrs: list (B.buffer UInt64.t)) heap =
  forall p. List.memP p ptrs ==> correct_down_p64 mem addrs heap p

val down_mem64: (mem:HS.mem) -> (addrs:addr_map) -> (ptrs:list (B.buffer UInt64.t){list_disjoint_or_eq ptrs}) -> GTot (heap :Vale_Sem.heap {correct_down64 mem addrs ptrs heap})

#set-options "--z3rlimit 40"

let down_mem64 mem addrs ptrs =
  (* Dummy heap *)
  let heap : heap = FStar.Map.const (UInt8.uint_to_t 0) in
  let rec aux ps (accu:list (B.buffer UInt64.t){forall p. List.memP p ptrs <==> List.memP p ps \/ List.memP p accu})
    (h:Vale_Sem.heap{correct_down64 mem addrs accu h}) : GTot (heap:Vale_Sem.heap{correct_down64 mem addrs ptrs heap}) = match ps with
    | [] -> h
    | a::q ->
      let length = B.length a in
      let contents = B.as_seq mem a in
      let addr = addrs.[(B.as_addr a, B.idx a, B.length a)] in
      let new_heap = write_vale_mem64 contents length addr 0 h in
      load_store_write_vale_mem64 contents length addr 0 h;
      correct_down_p64_cancel mem addrs h a;
      correct_down_p64_frame mem addrs h a;
      assert (forall p. List.memP p accu ==> disjoint_or_eq p a);
      aux q (a::accu) new_heap
    in
    aux ptrs [] heap 
