# Raid manual research

These standalone Tunnel A tests used UE4SS 4.0.0 Experimental (`b2d936b9`).
Bunco purchases and optional local raid pickups share the same manual flags.

## Spawning and pickup

- Tunnel A loaded `/Game/FW/Maps/ProceduralTunnels/Dungeons/Tunnel1/L_Dungeon_Tunnel1_<number>`.
  The prototype watched the local pawn's `LootUI.LootContainerReference` and
  tracked rolls per world and container.
- The test cloned Paper Scrap (`Octogirl_Tools_FrequencyCard`) from
  `ItemDetailsData` into a separate row with manual text. Reloads can keep the
  row in memory, so the prototype checked the existing row before reuse.
- The controlled test used a guaranteed roll. `SInventoryContainer:AddItem`
  inserted a row handle with quantity 1, `IsInUse = true`, and
  `Hidden = false`. `PopulateLootItems` refreshed the open list. The manual
  appeared in a provision crate (`BP_LootContainer_Provision_T1_C`), and the
  stock Take action picked it up. The later prototype required standalone
  mode, container authority, and one player in the game state.

## Hooks and observations

| Hook or function | What it provided |
|---|---|
| `/Script/ForeverWinter.SInventoryContainer:RequestLootFromContainer` | Native loot request for the selected container slot. The post hook could inspect the local rig after a normal Take. |
| `/Game/Widgets/Inventory/W_LootUI.W_LootUI_C:ItemLooted` | Blueprint pickup completion with success and slot parameters. The observer scoped it to the local pawn's loot panel. |
| `/Script/ForeverWinter.SBackpackRig:GetExtractedRigData` | The pre-hook removed the transient row from the local rig before snapshotting. A post-hook in the handoff test verified that both extraction item arrays excluded it. |
| `/Script/FWSession.FWGameInstance:SetExtracted` | Native success signal observed in the same raid world. Pair it with the local player's save component and extraction flags. |
| `/Game/FW/Components/BPC_PlayerSaveGames.BPC_PlayerSaveGames_C:ExtractLoot` | The first two arguments distinguished checkpoint saves and tunnel transfers. The tested final extraction had both flags clear and a matching success signal. |
| `/Script/FWGameCore.FWCharacter:OnSyncKilledDeath` and `/Game/FW/Player/BP_PlayerBase.BP_PlayerBase_C:Tunnel Death Extract` | Local-pawn death signals used to clear pending progress. |
| `RegisterLoadMapPostHook` | Observed travel through the checkpoint menu and into the Innards. The Innards worlds used the `/Game/LevelDesign/HUB_World/` prefix. |
| `/Script/FWGameCore.FWPlayerController:ClientDisplayPlayerMessage` | Reflected native player-message function that accepts `FText`. |

## Extraction and co-op

A custom item that remained in the rig could reach the stash. The handoff test
removed it before the loot snapshot and tracked the unlock separately. A
checkpoint resume followed by final extraction unlocked the recipes with clean
item arrays. A separate restart experiment keyed recovery to the map name,
which can repeat across raids.

## Native Take and the local pickup test

The solo Tunnel A trace showed an ordinary click on `W_LootItem_C.LootButton`.
The tile's `LootItem` multicast delegate was bound to `W_LootUI_C:LootItem`.
That path called `SInventoryContainer:RequestLootFromContainer` with the slot
index. The stock **Loot All** button has its own callback on the panel.
`W_LootUI_C.LootItems` is the visual WrapBox. `LootWidgets` is the separate
array of stock tile references.

The solo pilot appended a private stock loot tile to the WrapBox.
The integrated mod routes its native button locally. A
vendor card draws the Dossier artwork and manual title. The card ignores
pointer input. The original loot button sits above the artwork and forwards
its click to a private widget. The integrated mod uses this input path and
saves each claimed manual as pending when Take succeeds.

In the solo mouse test the press and claim counters both read zero stock
requests. The player saw the native pickup notice and the count stayed at
0/15. In the same session the next three ordinary pickups logged stock
requests for slot 0 on two cyborg corpses. The game can reject an empty
crate before the grid opens. Reopening after taking all ordinary loot
still needs a live test.

For a repeatable test, enable raid drops and set the sector chance to 100
on a disposable installation. Use two eligible crates with different manual
pools. Check their normal loot and Loot All. Take both manuals, transfer or
checkpoint, and then extract to the Innards. Repeat with a restart, death, and abandonment.
Check the pending section after each Take and the learned flags after final extraction. Test
keyboard and controller separately.

The co-op acceptance check uses a modded guest with an unmodded host. Compare
both players' crate contents before and after the guest's manual Take. Guest
extraction requires `ClientOnPlayerExtracted(Controller)` for the local player,
the local save component's final `ExtractLoot(false, false, …)` in that world,
and arrival in the Innards. The solo path also accepts `SetExtracted` from
the local standalone game instance. The guest signal sequence still needs a live test.

The integrated solo run recorded Munitions A, IFF, Workshop A, and Provisions
in one raid. The game crashed while the player was walking toward extraction.
All four flags were still false. Matching UE4SS symbols place both this crash
and an earlier one inside an object-list search from a native pre-hook. The
report does not identify the Lua mod. The Manufacturing hook now filters its
table argument directly, and the raid callbacks reuse objects resolved at setup.

On the next solo run, final extraction wrote Workshop A, Electronics A,
Munitions A, Rig Storage A, and Provisions together. IFF, acquired only in
the interrupted run, stayed locked. This second run used the build already
loaded before the callback changes were installed.
