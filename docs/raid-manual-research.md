# Archived raid manual research

These standalone Tunnel A tests used UE4SS 4.0.0 Experimental (`b2d936b9`).
The current manual flow uses Bunco.

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

The Take trace observed the native loot request and the UI completion callback.
It did not establish a way to intercept Take for a local-only tile before
dispatch. Co-op replication and guest extraction remain unverified.
