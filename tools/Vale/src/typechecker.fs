module TypeChecker

open Ast
open Ast_util
open Parse
open Microsoft.FSharp.Math
open System.Collections.Generic
open System.IO

type name_info =
| Info of id_info
| Func_decl of fun_decl
| Proc_decl of proc_decl
| Name of string

type export_ids_map = System.Collections.Generic.Dictionary<string, list<string>>
type scope_mod =
| Open_module of string
| Module_abbrev of (string * string)
| Local of (id * id_info)
| Func of (id * fun_decl)
| Proc of (id * proc_decl)

type env = {
  curmodule: option<string>; (* name of the module being typechecked *)
  modules: list<string>; (* previously defined modules *)
  scope_mods: list<scope_mod>; (* a STACK of scope modifiers *)
  exported_ids: export_ids_map; (* identifiers reachable in a module *)
}

let empty_env:env= {curmodule=None; modules=[]; scope_mods=[];
                   exported_ids = new Dictionary<string, list<string>>(10)}

let load_module (env:env) (m:string):env =
  // TODO: find the file, convert to lowercase?
  // TODO: hardcoded dependence
  let filename = m ^ ".exported" in
  let lines = File.ReadAllLines filename |> Array.toList in
  let rec aux (ids:list<string>) (l:list<string>) = 
    match l with
      | [] -> ids
      | line::tl -> 
        let es = line.Split ([|' '|]) |> Array.toList in
        List.append ids es in
  let exports = aux [] lines in
  let () = env.exported_ids.Add(m, exports) in
  env

let get_exported_ids (m:export_ids_map) k =
  match m.TryGetValue(k) with
  | true, v -> Some v
  | _ -> None

let load_module_exports (env:env) (m:string):env =
  match get_exported_ids env.exported_ids m with
  | Some v -> env
  | _ -> load_module env m

let find_in_module_exports (env:env) (m:string) (x:string) =
  match get_exported_ids env.exported_ids m with
  | Some l -> 
    match List.tryFind (fun elem -> elem = x) l with
    | Some n -> Some (Name n)
    | _ -> None
  | _ -> None
        
let lookup_name (env:env) (x:id) =
  let find = function
    | Open_module m -> find_in_module_exports env m (string_of_id x)
    | Module_abbrev (m, l) -> find_in_module_exports env l (string_of_id x)
    | Local (s, info) when s=x -> Some (Info info)
    | Func (s, decl) when s=x -> Some (Func_decl decl)
    | Proc (s, decl) when s=x -> Some (Proc_decl decl)
    | _ -> None
  let rec aux = function
    | a :: q -> 
      match (find a) with
      | Some r -> Some r
      | None -> aux q
    | [] -> None
  aux env.scope_mods

let lookup_id env (id:id) = 
  match lookup_name env id with
  | Some (Info info) -> Some info
  | _ -> None

let contains_id env id =
  match lookup_id env id with
  | Some _ -> true
  | _ -> false

let lookup_func (env:env) (id:id) = 
  match lookup_name env id with
  | Some (Func_decl decl) -> Some decl
  | _ -> None

let lookup_proc env (id:id) =
  match lookup_name env id with
  | Some (Proc_decl decl) -> Some decl
  | _ -> None

let contains_proc env id =
  match lookup_proc env id with
  | Some _ -> true
  | _ -> false

let push_scope_mod env scope_mod =
 {env with scope_mods = scope_mod :: env.scope_mods}

let push_id env id info =
  push_scope_mod env (Local (id, info))
  
let push_func env id func =
  push_scope_mod env (Func (id, func))
  
let push_proc env id proc =
  push_scope_mod env (Proc (id, proc))

let param_info isRet (x, t, g, io, a) =
  match g with
  | (XAlias (AliasThread, e)) -> ThreadLocal {local_in_param = (io = In && (not isRet)); local_exp = e; local_typ = Some t}
  | (XAlias (AliasLocal, e)) -> ProcLocal {local_in_param = (io = In && (not isRet)); local_exp = e; local_typ = Some t}
  | XInline -> InlineLocal (Some t)
  | XOperand -> OperandLocal (io, t)
  | XPhysical | XState _ -> err ("variable must be declared ghost, operand, {:local ...}, or {:register ...} " + (err_id x))
  | XGhost -> GhostLocal ((if isRet then Mutable else Immutable), Some t)
    
let push_rets (env:env) (rets:pformal list):env =
  {env with scope_mods = List.fold (fun s (x, t, g, io, a) -> Local(x, (param_info true (x, t, g, io, a))):: s) env.scope_mods rets}

// TODO: QUNYAN
let push_params_without_rets (env:env) (args:pformal list) (rets:pformal list):env =
  let arg_in_rets arg l = List.exists (fun elem -> elem = arg) l in
  let rec aux s l = 
    match l with
    | [] -> s
    | a::q ->
    let (x, _, _, _, _) = a in
    let s = if arg_in_rets a rets then s else Local(x, (param_info false a)):: s in
    aux s q in
  {env with scope_mods = aux env.scope_mods args}

let push_lhss (env:env) (lhss:lhs list):env =
  {env with scope_mods = List.fold (fun s (x, dOpt) -> match dOpt with None -> s | Some (t, _) -> Local(x, (GhostLocal (Mutable, t)))::s) env.scope_mods lhss }    
  
let push_formals (env:env) (formals:formal list):env =
  {env with scope_mods = List.fold (fun s (x, t) -> Local(x, (GhostLocal (Immutable, t))):: s) env.scope_mods formals}


