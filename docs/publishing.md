# Publishing checklist

1. ZIP the repository's `ue4ss` folder. It should unpack to
   `ue4ss/Mods/MoreCraftingRecipes/` with the Lua scripts, settings INI, and
   `enabled.txt`. Keep generated progress files and the developer overlay out
   of the main archive.
2. Copy the [summary](nexus-summary.txt) into the mod summary field. Switch
   the description editor to BBCode view and paste the
   [description](nexus-description.bbcode.txt). Check the preview.
3. Upload the [screenshots](../assets/screenshots/) in filename order and
   insert them above their captions in the description editor.
4. List RE-UE4SS 4.0.0 Experimental and tested commit `b2d936b9` in the
   requirements.
5. For a separate catalog build, use the overlay in the
   [developer guide](../DEVELOPMENT.md).
