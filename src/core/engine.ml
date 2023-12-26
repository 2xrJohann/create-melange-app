open Bindings
module String_map = Map.Make (String)

(*
let fold_compilation_results (ctx : Context.t)
    (acc : (unit, string) Promise_result.t) (_, (module Template : Template.S))
    =
  let open Promise.Syntax.Let in
  let* is_error = Promise_result.is_error acc in
  if is_error then acc
  else
    let template_value = Hmap.find Template.key ctx.template_values in
    match template_value with
    | None ->
        Promise_result.resolve_error
          (Printf.sprintf "A value for Template %s was not found" Template.name)
    | Some value -> Template.compile ~dir:ctx.configuration.directory value
;; *)

(* let compile_template (ctx : Context.t) =
     String_map.to_list ctx.templates
     |> List.fold_left
          (fold_compilation_results ctx)
          (Promise_result.resolve_ok ())
     |> Promise_result.map (fun _ -> ctx)
   ;; *)

(* let make_context (configuration : Configuration.t) =
     let templates =
       String_map.empty
       |> String_map.add Package_json.Template.name
            (module Package_json.Template : Template.S)
       |> String_map.add Dune_project.Template.name
            (module Dune_project.Template : Template.S)
     in
     let template_values =
       Hmap.empty
       |> Hmap.add Package_json.Template.key
            (Package_json.empty |> Package_json.set_name configuration.name)
       |> Hmap.add Dune_project.Template.key
            (Dune_project.empty |> Dune_project.set_name configuration.name)
     in
     let plugins : (module Plugin.S) list =
       match configuration.bundler with
       | Webpack ->
           [
             (module Webpack.Plugin.Copy_webpack_config_js);
             (module Webpack.Plugin.Extend_package_json);
           ]
       | Vite ->
           [
             (module Vite.Plugin.Copy_vite_config_js);
             (module Vite.Plugin.Extend_package_json);
           ]
       | None -> []
     in
     (* let plugins = (module Opam.Plugin.Create_switch : Plugin.S) :: plugins in *)
     let plugins =
       if configuration.initialize_git then
         [
           (module Git_scm.Plugin.Copy_gitignore : Plugin.S);
           (module Git_scm.Plugin.Init_and_stage : Plugin.S);
         ]
         @ plugins
       else plugins
     in
     let plugins =
       if configuration.initialize_npm then
         (module Npm.Plugin.Install : Plugin.S) :: plugins
       else plugins
     in
     Context.{ configuration; templates; template_values; plugins }
   ;; *)

(* let run (config : Configuration.t) =
     make_context config |> copy_base_dir
     |> Js.Promise.then_ (fun ctx_result ->
            match ctx_result with
            | Error err -> Js.Promise.resolve @@ Error err
            | Ok ctx -> run_pre_compile_plugins ctx)
     |> Js.Promise.catch (fun _ ->
            Js.Promise.resolve @@ Error "pre compile failed")
     |> Js.Promise.then_ (fun ctx_result ->
            match ctx_result with
            | Error _ -> Js.Promise.resolve @@ Error "pre compile failed"
            | Ok ctx -> (
                try compile_template ctx
                with exn ->
                  Js.Promise.resolve
                  @@ Error
                       (Format.sprintf "compile failed dawg: %s"
                          (Printexc.to_string exn))))
     |> Js.Promise.catch (fun _ ->
            Js.Promise.resolve @@ Error "template compilation failed")
     |> Js.Promise.then_ (fun ctx_result ->
            match ctx_result with
            | Error err -> Js.Promise.resolve @@ Error err
            | Ok ctx -> run_post_compile_plugins ctx)
   ;; *)

let dependencies : (module Dependency.S) list =
  [
    (module Opam.Dependency);
    (* (module Node_js.Dependency : Dependency.S);
       (module Git_scm.Dependency : Dependency.S); *)
  ]
;;

(* let fold_dependency_to_result
       (acc : (Dependency.check list, string) Promise_result.t)
       (module Dep : Dependency.S) =
     let open Promise_result.Syntax.Let in
     let+ check_result = Dep.check () in
     acc |> Promise_result.map (fun results -> check_result :: results)
   ;; *)

let fold_dependency_to_result acc (module Dep : Dependency.S) =
  let open Promise_result.Syntax.Let in
  let+ check = Dep.check () in
  let result =
    match check with
    | `Pass -> `Pass (module Dep : Dependency.S)
    | `Fail -> `Fail (module Dep : Dependency.S)
  in
  acc |> Promise_result.map (fun results -> result :: results)
;;

let check_dependencies () =
  List.fold_left fold_dependency_to_result
    (Promise_result.resolve_ok [])
    dependencies
;;

module V2 = struct
  let directory_exists = Fs.exists
  let create_project_directory = Fs.create_project_directory
  let copy_base_project = Fs.copy_base_project

  let copy_bundler_files ~(bundler : Bundler.t) project_directory =
    match bundler with
    | None -> Promise_result.resolve_ok ()
    | Webpack -> Webpack.V2.Copy_webpack_config_js.exec project_directory
    | Vite -> Vite.V2.Copy_vite_config_js.exec project_directory
  ;;

  (* let extend_template name (ctx : V2.t) values =
       let x = V2.get_template_by_name ~name ctx in
       Option.map (fun (module T : Template.S) ->
           let template_values = V2.get_template_value ~template:(module T) ctx in
           ())
     in
     () *)
end
