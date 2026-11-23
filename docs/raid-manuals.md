# Raid manuals

Raid drops are off by default. The switch is `RaidDrops` under `[RecipeBooks]`. Each eligible crate rolls once for the local player. **Take** picks up the manual. **Loot All** collects the regular loot.

Found manuals survive map changes, checkpoints, and restarts. Extraction to the Innards unlocks their recipes. Death or abandoning the raid costs you the pending finds. Loading directly into the Innards after a restart leaves them pending until your next successful extraction.

## Where manuals drop

`[RaidDropChances]` sets the chance per crate. The defaults are A 4%, B 3%, C 2%, and D 1%. Tunnel 1 uses A, Tunnel 2 uses B, and so on. On surface maps, the crate’s own tier determines the sector.

A crate can offer one unlearned manual. You can find several different manuals in the same raid. Troops and their loot bags never drop manuals.

| Manual | Sector | Containers |
|---|---|---|
| Workshop A | A | Civil goods canister, materials bin, medical bin |
| Workshop B | B | Materials bin |
| Workshop C | C | Materials bin |
| Workshop D | D | Materials bin |
| Electronics A | A | Civil goods canister, military crate |
| Electronics B | B | Military crate |
| Electronics C | C | Military crate |
| Electronics D | D | Military crate |
| Munitions A | A | Armament crate |
| Munitions B | B | Armament crate |
| Rig Storage A | A | Civil goods canister, materials bin |
| Rig Storage B | B | Materials bin, military crate |
| Rig Storage C | C | Materials bin, military crate |
| IFF | A–D | Armament crate, military crate |
| Provisions | A–D | Civil goods canister, provisions crate, medical bin |

## Container assets

The installed package indexes contain all 24 eligible crate blueprints below. Each row lists the four asset names under `/Game/FW/LootObjects/Containers/EconV2/Parity/T1/` through `T4/`, respectively. The mod matches the crate's exact class before rolling.

| Container | T1 | T2 | T3 | T4 |
|---|---|---|---|---|
| Armament crate | BP_LootContainer_Armament_T1 | BP_LootContainer_Armament_T2 | BP_LootContainer_Armament_T3 | BP_LootContainer_Armament_T4 |
| Civil goods canister | BP_LootContainer_Civilian_T1 | BP_LootContainer_Civilian_T2 | BP_LootContainer_Civilian_T3 | BP_LootContainer_Civilian_T4 |
| Materials bin | BP_LootContainer_Material_T1 | BP_LootContainer_Material_T2 | BP_LootContainer_Material_T3 | BP_LootContainer_Material_T4 |
| Medical bin | BP_LootContainer_Medical_T1 | BP_LootContainer_Medical_T2 | BP_LootContainer_Medical_T3 | BP_LootContainer_Medical_T4 |
| Military crate | BP_LootContainer_Army_T1 | BP_LootContainer_Army_T2 | BP_LootContainer_Army_T3 | BP_LootContainer_Army_T4 |
| Provisions crate | BP_LootContainer_Provision_T1 | BP_LootContainer_Provision_T2 | BP_LootContainer_Provision_T3 | BP_LootContainer_Provision_T4 |

The developer overlay exports registered blueprints under the game's container directory to `container-assets.txt`. [Developer guide](../DEVELOPMENT.md)
