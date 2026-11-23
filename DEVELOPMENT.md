# Development

## Build and export the item catalog

Copy the repository's `ue4ss` tree into a staging folder. For the developer build,
overlay `development/Scripts` onto `ue4ss/Mods/MoreCraftingRecipes/Scripts` in
that staging folder. This replaces `main.lua` and adds the catalog exporter.

The exporter writes `crafting-items.tsv` beside the installed mod's INI when
Manufacturing and the inventory tables load. The checked-in copy is in
`development/crafting-items.tsv`. Use its item tags and stock input/output
columns when designing recipes. The overlay also writes `container-assets.txt`
with the mounted blueprint packages under `/Game/FW/LootObjects/Containers`.

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
- `manuals.ini` holds learned manuals, pending finds, and purchase receipts. Each new
  receipt records the opening balance and quoted price. Confirmed debits, declined
  debits, and raid losses go into `manuals.recovery` before the INI is replaced.
  The store replays those records on its next read and clears them after saving.
- If a purchase stops before the wallet result is recorded, Bunco checks the original
  balance and price. A matching debit completes the sale. An unchanged balance
  clears the receipt. An ambiguous balance or an older receipt offers an explicit
  recovery at no extra charge.

The [raid drop table](docs/raid-manuals.md) lists each manual's sources.
`Scripts/books/raid/sources.lua` defines the pools and sector rules.
`session.lua` tracks crate rolls and offers and stages each Take through the progress store. `loot.lua` and
`tile.lua` handle the local loot UI. `runtime.lua` checks the local player,
extraction, and arrival. Recovery reads `[PendingRaidManuals]` even if no crate has been opened since startup.
Confirmed extraction unlocks the whole batch. Death and abandonment record the loss before clearing the batch.

From the repository root, run `lua development/tests/raid_manuals.lua` with
Lua 5.4 to check crate assignments, local input, travel, and unlock retries.
Pass an empty temporary directory as the first argument to exercise real progress-file writes and restart recovery.
The purchase recovery tests run with `lua development/tests/manual_recovery.lua <empty-directory>`.

See the [raid research notes](docs/raid-manual-research.md) for the native
hooks and remaining live checks. See the [publishing checklist](docs/publishing.md)
for release packaging.
