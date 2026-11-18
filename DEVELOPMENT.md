# Developer build

Copy the repository's `ue4ss` tree into a staging folder. Overlay the contents
of `development/Scripts` onto the staged mod's `Scripts` folder, replacing
`main.lua`. Use the staged mod in place of the release when testing.
The catalog snapshot is in `development/crafting-items.tsv`; an in-game
export is written to the installed mod folder.

- `Scripts/recipes.lua` defines the recipe rules. Explicit inputs and outputs
  use full inventory tags. Ammo salvage reads quantities from live stock
  recipes, and stock templates supply the unlock requirements and craft times.
- `Scripts/mcr_installer.lua` reconciles runtime recipe, tag, and group rows.
- `Scripts/mcr_runtime.lua` reapplies the recipe set on load events.
- `Scripts/mcr_catalog.lua` is developer-only. The developer build exports
  `crafting-items.tsv` automatically when the manufacturing tables are available
  and retries on load events until both inventory tables are available. The
  catalog refreshes on the next launch. Neither build reads the TSV.
- The release entry point starts the shared runtime with the recipe definitions.
  The developer entry point also starts the catalog export.

Add a stable custom recipe ID, a stock anchor, and input/output tags with
positive integer quantities. Keep IDs stable for any queued crafts. Use the
catalog's stock input/output columns to distinguish confirmed stock usage from
item candidates. Restart the game when testing changes to IDs or groups.


## Packaging

For a player ZIP, archive the repository's `ue4ss` folder directly. The first
path component inside the ZIP should be `ue4ss`. Keep the developer overlay
and publishing files outside that ZIP. See the [publishing checklist](docs/publishing.md).
