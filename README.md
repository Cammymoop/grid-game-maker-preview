
# Grid Game Maker
**Grid Game Maker** is a free tool for easily turning your grid-based ideas into games quickly and with pretty visuals.

By Cammymoop Games

This reposity contains the code for the Grid Game Maker Preview release. This is a fully featured public release but
this code should not be considered a good base for continuing to develop or building on top of. This code is more or less
an uplifted prototype which has many hasty compromises, inconsistencies, mistakes, old expirements, etc.

Going forward I intend for future versions of Grid Game Maker to be based on a complete rewrite, which will happen in a separate repository.

Grid Game Maker Preview requires Godot Engine 4.6.x

Various text files are spread around this source in varying levels of outdatedness, don't believe their lies

# Info about this source and the License

## Notes on asset files:
Various sound effect audio files are included, some of these were created by me, but I have lost track of exaclty where some of these came from.
I believe these are more or less fine to for me to distribute (idk about the pipes actually), but err on the safe side and don't assume any of
the sound effect or ambience files are included under any particular license.

Some unused CC0 music has been included in the source here though it isn't available to use in GGM Preview yet and should be excluded from exports,
the .txt file next to each track lists creator and the CC0 license I downloaded these tracks under.

All of the image assets in the assets/img directory should be considered available under the MIT license along with the code, but in addition to that,
all of the images which are used as "built-in textures" in GGM should also be considered to be available under CC0 in an as-permissive-as-possible manner.
See the assets\builtin_texture_meta.json file for which files this specifically applies to.

The cammy_birb_tiny.svg is a version of Cammymoop Games' logo, you may use it in conjunction with Grid Game Maker or anything created using it to
indicate that Grid Game Maker was created by Cammymoop Games.

Some Noto Sans fonts are here which should be included under the (SIL Open Font License.)[https://openfontlicense.org/open-font-license-official-text/]

There is also some PNGs of a minimal pixel font which is used on command card headers, this is a generic font created by me and should be available along
with the rest of the source under it's MIT license.

The other font files are just slightly modified exports from Godot's builtin theme fonts. I think these are only here from when this was
a Godot 3.x project, these should not be considered covered by any particular license.

## Notes on included games
In addition to the three example games included in exported versions of Grid Game Maker there are more games in this source version,
These are in the other_games/ directory. All of these games were implemented in GGM by me and you are free to reference them, 
some are partial clones of existing games, these are intended for testing, reference, and for recording footage of, they shouldn't
be considered to be covered by the source's MIT license, unless otherwise stated.
(I'm being overly cautious here, none of these are proper clones or have extensive level content from existing games, they all contain only assets I created myself)

All three example games use only the built-in assets and their GGM implementations are free to play, reference,
make custom content for etc. However, only Basic (working title) should be considered to be fully covered by the source MIT license.

Geode is included by permission from Neonesque, please contact them for any questions about usage beyond playing or making custom content.

Chippy Challenge is not an exact clone of Chip's Challenge, however the included levels which are not subtitled "by Cammymoop" are not included as
part of the source MIT license, they are included for playing by permission from their respective creators.