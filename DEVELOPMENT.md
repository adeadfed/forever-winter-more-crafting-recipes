# Development

## Build and export the item catalog

Copy the repository's `ue4ss` tree into a staging folder. For the developer build,
overlay `development/Scripts` onto `ue4ss/Mods/MoreCraftingRecipes/Scripts` in
that staging folder. This replaces `main.lua` and adds the catalog exporter.

The exporter writes `crafting-items.tsv` beside the installed mod's INI when
Manufacturing and the inventory tables load. The checked-in copy is in
`development/crafting-items.tsv`. Use its item tags and stock input/output
columns when designing recipes.

## Recipes and manuals

- `Scripts/recipes/definitions.lua` and `expansion.lua` define static recipe rows.
  Set `row`, `tag`, `template`, `group`, `manual`, `name`, and the inputs and
  outputs. Use full inventory tags and positive integer quantities.
- `Scripts/recipes/groups.lua` defines custom categories. `Scripts/rig/catalog.lua`
  pairs stock low- and high-quality rig boxes by slot and size, and
  `Scripts/rig/boxes.lua` builds the corresponding recipes.
- `Scripts/books/manuals.lua` defines manual IDs, family order, and default prices.
  The INI can override prices. Keep recipe IDs stable for queued jobs and manual
  IDs stable for saved unlocks.

The installer preloads the tables and hooks
`/Script/Engine.DataTableFunctionLibrary:GetDataTableRowNames` for the
Manufacturing group table. Locked recipes keep their data rows for queued jobs.
Category links control what players can see. A cancellable craft-start hook
remains unverified. Recipes flagged `skip_stock_duplicate` stay hidden when a
stock recipe produces their output.

## Bunco and progress

- Vendor row `ScavSurplusVendor` uses `CategorySelected` to identify
  `CategoryConsumables`. `ApplyCategory`, `RefreshFilter`,
  `ToggleVendorListState`, and `PassiveRefreshVendorRank` keep the manual cards
  in the correct tab.
- Append the cards to `VendorSB` using `AddChild`. `W_VendorItem_C:InitialiseItem`
  supplies the Dossier artwork from `Plans05`. The manual descriptions use
  separate display rows. The card click hook
  `W_VendorItem_C:BndEvt__W_VendorItem_ItemButton_K2Node_ComponentBoundEvent_0_OnButtonClickedEvent__DelegateSignature`
  opens the game's popup. `WBP_PopUp_C:OnConfirm` and `OnCancel` handle the response.
- `GetStashCurrencyCount` reads the local `TestCurrency` balance.
  `RemoveStashCurrency` takes entries with `CurrencyRow` and
  `CurrencyAmount`. The mod checks the exact debit before granting the unlock.
- `manuals.ini` holds the unlock flags and any interrupted purchase receipts.
  Receipts prevent a second charge while payment status is unresolved. Temporary
  files protect the previous state during a write.

See the [raid research notes](docs/raid-manual-research.md) for the archived
loot-spawning and extraction hooks. See the [publishing checklist](docs/publishing.md)
for release packaging.
