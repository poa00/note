open Core

module Item = struct
  type t = {
    parent : string option;
    slug : string;
    title : string;
    description : string;
    tags : string list;
  }

  let make ~parent ~slug ~title ~description ~tags =
    { parent; slug; title; description; tags }

  let of_json json =
    let slug = Ezjsonm.find json [ "slug" ] |> Ezjsonm.get_string in
    let title = Ezjsonm.find json [ "title" ] |> Ezjsonm.get_string in
    let description =
      Ezjsonm.find json [ "description" ] |> Ezjsonm.get_string
    in
    let tags = Ezjsonm.find json [ "tags" ] |> Ezjsonm.get_strings in
    let parent =
      match Ezjsonm.find_opt json [ "parent" ] with
      | Some parent -> Some (parent |> Ezjsonm.get_string)
      | None -> None
    in
    { slug; parent; title; description; tags }

  let to_json item =
    let parent =
      match item.parent with
      | Some parent -> parent |> Ezjsonm.string
      | None -> Ezjsonm.unit ()
    in
    Ezjsonm.dict
      [
        ("parent", parent);
        ("slug", item.slug |> Ezjsonm.string);
        ("title", item.title |> Ezjsonm.string);
        ("description", item.description |> Ezjsonm.string);
        ("tags", item.tags |> Ezjsonm.strings);
      ]
end

type t = { items : Item.t list }

let empty = { items = [] }

let of_json json =
  let items =
    Ezjsonm.find json [ "items" ]
    |> Ezjsonm.get_list (fun item -> item |> Item.of_json)
  in
  { items }

let to_json manifest =
  let items = Ezjsonm.list Item.to_json manifest.items in
  Ezjsonm.dict [ ("items", items) ]

let of_string manifest = manifest |> Ezjsonm.from_string |> of_json

let to_string manifest = manifest |> to_json |> Ezjsonm.to_string

let lock path =
  match path |> Sys.file_exists with
  | `Yes -> failwith "unable to aquire lock"
  | `No | `Unknown -> Out_channel.write_all ~data:"<locked>" path

let unlock path =
  match path |> Sys.file_exists with
  | `Yes -> Sys.remove path
  | `No | `Unknown -> ()

let lockfile path = Filename.concat (path |> Filename.dirname) "note.lock"

let load_or_init path =
  match Sys.file_exists path with
  | `Yes -> path |> In_channel.read_all |> of_string
  | `No | `Unknown ->
      path |> Out_channel.write_all ~data:(to_string empty);
      empty

let save ~path manifest =
  path |> lockfile |> lock;
  Out_channel.write_all ~data:(to_string manifest) path;
  path |> lockfile |> unlock

let rec to_path ~manifest (item : Item.t) =
  match item.parent with
  | Some parent_slug ->
      let parent =
        manifest.items
        |> List.find_exn ~f:(fun other -> String.equal other.slug parent_slug)
      in
      let base_path = parent |> to_path ~manifest in
      let base_path = Filename.concat base_path item.title in
      base_path
  | None -> Filename.concat "/" item.title

let exists ~path manifest =
  manifest.items
  |> List.exists ~f:(fun item -> item |> to_path ~manifest |> String.equal path)

let find ~path manifest =
  manifest.items
  |> List.find ~f:(fun item ->
         let file_path = item |> to_path ~manifest in
         String.equal file_path path)

let list ~path manifest =
  (* list items below path but not path itself *)
  manifest.items
  |> List.filter ~f:(fun item ->
         let item_path = item |> to_path ~manifest in
         String.equal path (Filename.dirname item_path))

let insert ~path ~slug ~title ~description ~tags manifest =
  match path with
  | "" | "/" ->
      let item = Item.make ~parent:None ~slug ~title ~description ~tags in
      if manifest |> exists ~path:(item |> to_path ~manifest) then
        failwith "duplicate item"
      else
        let items = item :: manifest.items in
        { items }
  | path ->
      let parent =
        match manifest |> find ~path with
        | Some parent -> parent.slug
        | None -> failwith "no parent"
      in
      let item =
        Item.make ~parent:(Some parent) ~slug ~title ~description ~tags
      in
      if manifest |> exists ~path:(item |> to_path ~manifest) then
        failwith "duplicate item"
      else
        let items = item :: manifest.items in
        { items }
