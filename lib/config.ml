open Core

let home = Sys.home_directory ()

let base_xdg_config_path = Filename.concat home ".config"

let base_xdg_share_path = Filename.concat home ".local/share"

let config_path =
  match Sys.getenv "NOTE_CONFIG" with
  | Some path -> path
  | None -> Filename.concat base_xdg_config_path "/note/config.yaml"

module ListStyle = struct
  type t = [ `Fixed | `Wide | `Simple ]

  let all = [ `Fixed; `Wide; `Simple ]

  let to_string = function
    | `Fixed -> "fixed"
    | `Wide -> "wide"
    | `Simple -> "simple"

  let of_string = function
    | "fixed" -> `Fixed
    | "wide" -> `Wide
    | "simple" -> `Simple
    | key -> failwith key
end

module Encoding = struct
  type t = [ `Json | `Yaml | `Raw ]

  let all = [ `Json; `Yaml; `Raw ]

  let to_string = function `Json -> "json" | `Yaml -> "yaml" | `Raw -> "raw"

  let of_string = function
    | "json" -> `Json
    | "yaml" -> `Yaml
    | "raw" -> `Raw
    | key -> failwith (sprintf "unsupported encoding type: %s" key)
end

module Column = struct
  type t = [ `Title | `Description | `Tags | `WordCount | `Slug ]

  let to_string = function
    | `Title -> "title"
    | `Description -> "description"
    | `Tags -> "tags"
    | `WordCount -> "words"
    | `Slug -> "slug"

  let of_string = function
    | "title" -> `Title
    | "description" -> `Description
    | "tags" -> `Tags
    | "words" -> `WordCount
    | "slug" -> `Slug
    | key -> failwith (sprintf "unsupported column type: %s" key)
end

module Key = struct
  type t =
    [ `StateDir
    | `LockFile
    | `Editor
    | `OnModification
    | `OnSync
    | `ListStyle
    | `Encoding
    | `ColumnList ]

  let all =
    [
      `StateDir;
      `LockFile;
      `Editor;
      `OnModification;
      `OnSync;
      `ListStyle;
      `Encoding;
      `ColumnList;
    ]

  let of_string = function
    | "state_dir" -> `StateDir
    | "lock_file" -> `LockFile
    | "editor" -> `Editor
    | "on_modification" -> `OnModification
    | "on_sync" -> `OnSync
    | "list_style" -> `ListStyle
    | "encoding" -> `Encoding
    | "column_list" -> `ColumnList
    | key -> failwith (sprintf "bad configuration key %s" key)

  let to_string = function
    | `StateDir -> "state_dir"
    | `LockFile -> "lock_file"
    | `Editor -> "editor"
    | `OnModification -> "on_modification"
    | `OnSync -> "on_sync"
    | `ListStyle -> "list_style"
    | `Encoding -> "encoding"
    | `ColumnList -> "column_list"
end

type t = {
  state_dir : string;
  lock_file : string;
  editor : string;
  on_modification : string option;
  on_sync : string option;
  list_style : ListStyle.t;
  encoding : Encoding.t;
  column_list : Column.t list;
}

let of_string str =
  let json = Yaml.of_string_exn str in
  let state_dir =
    match Ezjsonm.find_opt json [ Key.to_string `StateDir ] with
    | Some state_dir -> Ezjsonm.get_string state_dir
    | None -> Filename.concat base_xdg_share_path "/note"
  and lock_file =
    match Ezjsonm.find_opt json [ Key.to_string `LockFile ] with
    | Some lock_file -> Ezjsonm.get_string lock_file
    | None -> Filename.concat base_xdg_share_path "/note.lock"
  and editor =
    match Ezjsonm.find_opt json [ Key.to_string `Editor ] with
    | Some editor -> Ezjsonm.get_string editor
    | None -> Sys.getenv_exn "EDITOR"
  and on_modification =
    match Ezjsonm.find_opt json [ Key.to_string `OnModification ] with
    | Some on_modification -> Some (Ezjsonm.get_string on_modification)
    | None -> None
  and on_sync =
    match Ezjsonm.find_opt json [ Key.to_string `OnSync ] with
    | Some on_sync -> Some (Ezjsonm.get_string on_sync)
    | None -> None
  and list_style =
    match Ezjsonm.find_opt json [ Key.to_string `ListStyle ] with
    | Some list_style -> ListStyle.of_string (Ezjsonm.get_string list_style)
    | None -> `Fixed
  and encoding =
    match Ezjsonm.find_opt json [ Key.to_string `Encoding ] with
    | Some encoding -> Encoding.of_string (Ezjsonm.get_string encoding)
    | None -> `Raw
  and column_list =
    match Ezjsonm.find_opt json [ Key.to_string `ColumnList ] with
    | Some column_list ->
        List.map ~f:Column.of_string (Ezjsonm.get_strings column_list)
    | None -> [ `Title; `Tags; `WordCount; `Slug ]
  in
  {
    state_dir;
    lock_file;
    editor;
    on_modification;
    on_sync;
    list_style;
    encoding;
    column_list;
  }

let to_string t =
  let state_dir = Ezjsonm.string t.state_dir
  and lock_file = Ezjsonm.string t.lock_file
  and editor = Ezjsonm.string t.editor
  and on_modification =
    if Option.is_some t.on_modification then
      Ezjsonm.string (Option.value_exn t.on_modification)
    else Ezjsonm.unit ()
  and on_sync =
    if Option.is_some t.on_sync then Ezjsonm.string (Option.value_exn t.on_sync)
    else Ezjsonm.unit ()
  and list_style = Ezjsonm.string (ListStyle.to_string t.list_style)
  and encoding = Ezjsonm.string (Encoding.to_string t.encoding)
  and column_list =
    Ezjsonm.strings (List.map ~f:Column.to_string t.column_list)
  in
  Yaml.to_string_exn
    (Ezjsonm.dict
       [
         (Key.to_string `StateDir, state_dir);
         (Key.to_string `LockFile, lock_file);
         (Key.to_string `Editor, editor);
         (Key.to_string `OnModification, on_modification);
         (Key.to_string `OnSync, on_sync);
         (Key.to_string `ListStyle, list_style);
         (Key.to_string `Encoding, encoding);
         (Key.to_string `ColumnList, column_list);
       ])

let get t key =
  match key with
  | `StateDir -> t.state_dir
  | `LockFile -> t.lock_file
  | `Editor -> t.editor
  | `OnModification -> (
      match t.on_modification with Some value -> value | None -> "null" )
  | `OnSync -> ( match t.on_sync with Some value -> value | None -> "null" )
  | `ListStyle -> ListStyle.to_string t.list_style
  | `Encoding -> Encoding.to_string t.encoding
  | `ColumnList ->
      String.concat ~sep:" " (List.map ~f:Column.to_string t.column_list)

let set t key value =
  match key with
  | `StateDir -> { t with state_dir = value }
  | `LockFile -> { t with lock_file = value }
  | `Editor -> { t with editor = value }
  | `OnModification ->
      if String.length value = 0 then { t with on_modification = None }
      else { t with on_modification = Some value }
  | `OnSync ->
      if String.length value = 0 then { t with on_sync = None }
      else { t with on_sync = Some value }
  | `ListStyle -> { t with list_style = ListStyle.of_string value }
  | `Encoding -> { t with encoding = Encoding.of_string value }
  | `ColumnList ->
      {
        t with
        column_list = List.map ~f:Column.of_string (String.split ~on:' ' value);
      }

let load =
  let cfg =
    match Sys.file_exists config_path with
    | `Yes -> of_string (In_channel.read_all config_path)
    | `No | `Unknown ->
        Unix.mkdir_p (Filename.dirname config_path);
        Out_channel.write_all config_path
          ~data:(Ezjsonm.to_string (Ezjsonm.dict []));
        of_string (In_channel.read_all config_path)
  in

  (* intiailize the state directory if it is missing *)
  match Sys.file_exists cfg.state_dir with
  | `Yes -> cfg
  | `No | `Unknown ->
      Unix.mkdir_p cfg.state_dir;
      cfg

let populate t =
  List.fold ~init:t
    ~f:(fun accm key ->
      let value = get accm key in
      set accm key value)
    Key.all

let save t = Out_channel.write_all ~data:(to_string t) config_path
