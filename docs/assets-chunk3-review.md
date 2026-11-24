# Chunk 3 assets: review and what was built (24 Nov 2026)

This is the report-back the Chunk 3 pack asked for (`Outpost_One_Chunk_3_CLAUDE_START_HERE.md`). It covers which models drop in, the conflicts found, the printer audit, comms, the loadout, salvage, tests and open questions. What got built is in `docs/opening-slice.md` §10c.

Decided with the user on 24 Nov:
- the ready call goes over **suit comms**, and the base radio is optional dressing and a second way in;
- the Print Shop prints only the sled's **small fittings**;
- the EVA station goes in the **General Module**;
- this round covers the review, the models and scenes 13–18.

## 1. What changed since the pack was written
- **The Print Shop isn't on pallet 6 any more** (a3730fc, 23 Nov playtest). It comes in the fit-out kit box with the intake and a 250 kg sack. Pallet 6 is the **survey sled**: its frame and antenna. So the Print Shop crate isn't needed.
- **The printer only unlocks plans.** Finished jobs go to B's Unpacked tab and nothing comes out physically, apart from the new hand parts below.

## 2. Models: drop in or adapt
All copied to `assets/models/chunk3/` as snake_case GLBs and imported. None of the pack's `.gd.txt` controllers is attached as is. Their visual logic is rewritten in the game's own scripts, and every model goes through `MHPalette.apply()`.

| Model | Verdict | Where it's used |
|---|---|---|
| Print Shop printer | **Adapt.** Drawer, head, lamp and hopper are driven by `fabricator.gd`. | The Print Shop (`fabricator.gd` MODEL), with fallbacks to the old model, then boxes |
| Printer, packed | Copied, not used yet | (carrying it from the kit box is still a B placement) |
| Regolith intake, deployed | **Adapt.** `regolith_intake_visuals.gd` unfolds it once when placed, then turns the wheel and sieve. | `assets/models/chunk3/regolith_intake.tscn`; collision 1.61 × 0.62 × 2.57 m |
| Regolith intake, folded | Copied, not used yet | (no carry form in game yet) |
| Beacon connector | **Drop-in** | Sits on the drawer's mat when printed |
| GAR-Y radar head, work lights, scoop | **Drop-in** on `MastMount` / `FrontMount` at identity | `chunk_three.gd` |
| Radar sled | **Drop-in** (from the chunk 1 pack) | On GAR-Y's hitch, or on the EVA station's `Stow_Sled` |
| EVA station | **Adapt.** Its stowed pieces show and hide to match the game. | New catalogue item `eva_station` |
| Field kits 1–6 | Copied; the station's own `Stow_Kit_*` are used instead | – |
| Salvage tub | **Adapt.** Its three groups show as salvage rises. | New item `salvage_tub` |
| Crew effects case | **Adapt.** Lid hinge, plush at `ItemPoint`, display sample hidden. | One on the plain (`effects_case.gd`) |
| Printed guitar | **Drop-in** | New printable item `printed_guitar` |
| Base radio (Bridge) | **Adapt.** Lid open, the lamp pulses on air, the handset lifts. | New item `base_radio` (wall, 1 m up) |

**Parked:**
- the Print Shop crate (the printer comes in the kit box now);
- the packed radio crate (the radio is a kit item);
- both storm pallets. They're provisional, a different size (1.38 × 0.49 m against the game's 1.6 × 0.95 m), and the current `pallet.glb` stays.

## 3. Node and name conflicts, and their fixes
- **GAR-Y's `Head`:** `companion_rover.gd` found its head with a recursive `find_child("Head")`, which would have caught the radar head's `Head`. Fixed: it now skips anything under a fitting (meta `gar_y_fitting`).
- **Textured materials:** `MHPalette.apply()` keeps any textured material, so the packs' PBR textures survive. Textured orange parts won't follow the colony accent colour. That's accepted for now.
- **No `printed` role in MHPalette.** The printed guitar keeps its own texture. `regolith` is already a KEEP word.
- **The beacon's `set_connected`** exists only in the pack's `.gd.txt`. Fitting the connector at the beacon is Chunk 4.
- **The pit rubble (found on the way):** `pad_site.gd:30` pointed into `asset_packs/`, which is `.gdignore`'d, so the rubble never loaded. It now points at `assets/original_mars/models/`.

## 4. Comms (decided: suit comms)
- Every call already comes through the suit, anywhere. The ready call is a button on the slate's Today page (*Call Castle: I'm ready*), under Ask orbit.
- The base radio is a second way to make the same call, from inside. Its lamp pulses while a call is on air. Scene 18 doesn't need it.
- Called without the sled, Castle says *"We'll need Tamsin's sled first."* With it, the leads come together and the bench across the Dry channel is pinned.

## 5. The EVA loadout (leaves the suit design open)
- **One station, two halves.** *You* is the suit rack's own add-on logic, unchanged. *GAR-Y* has the mast (radar head), the front mount (lamp bar **or** scoop, never both) and the hitch (the sled).
- The station only **shows** state. Each fitting exists once, and it's either on its peg or on GAR-Y. The six kit slots show your spares (suit add-ons on the rack, plus spares kits).
- Changes go on **as you step out through the airlock**, with a servo clunk. GAR-Y waits there already.
- The hand tools stay in the field kit (1–4). The suit bay on the station stays empty: nothing on it commits the suit's design.
- The scoop is **visual only** in this slice. The lamp bar lights when GAR-Y's own lamp does.

## 6. Salvage: uses that come up naturally
- **The sled's electronics.** The fittings cost 70 kg of iron and 70 kg of salvage, against 60 + 60 at the start, so you need both new routes once:
  - **Stripping emptied pallets.** Hold E on an opened, empty storm pallet: 25 kg of salvage, the lid comes off, once per pallet. In a story game, opening a pallet no longer pays salvage by itself.
  - **Iron-rich rock.** Tamsin marks a dark outcrop that reads as hematite. Break it with the hammer, carry it home, and E at the Print Shop feeds it into the hopper at half yield ("haematite to iron at half"). No Lab or smelter room is needed.
- **The printed guitar** (Joseph's) costs 4 kg of iron and 6 kg of salvage: the strings and tuners are salvage.
- The **salvage tub** by the printer shows the store as harness, a control board and mounting hardware. No pickup busywork.

## 7. The printer audit
| Item | When it's needed | Largest printed piece | Route | Pickup |
|---|---|---|---|---|
| Beacon connector | Scene 15 | about 12 cm | hand part | the output drawer, E |
| Sled fittings (electronics box, two skid shoes) | Scene 16 | each under 0.6 × 0.3 m | hand part | the drawer; E bolts them to the frame |
| Spares kits | any time | small | stock | the shelf |
| Furniture, machines | free stretch | large | printed in sections, put together where placed | B's Unpacked tab |
| Printed guitar | free stretch | 0.94 m body (too big for one piece) | body panels plus neck, salvage strings | B's Unpacked tab |

- **Verdict:** the current printer is enough through the rehearsal. Hand parts come out in the drawer, and everything else stays as it is now.
- **The first exception** is the guitar, and it's handled by printing it in sections. No model change is needed.
- **The smallest change, if a big part ever has to come out whole:** a taller output drawer and a wider chamber opening. Nothing needs that yet.

## 8. Test plan
- `tests/opening_slice_test.gd` carries on past the new job with a chunk 3 section. It passes. It covers:
  - Ask orbit still answering in the free stretch;
  - the ready call refused, then accepted;
  - pallet 6 opened at home;
  - the printer and station placed;
  - the connector printed into the drawer and taken;
  - the teaching call and the outcrop;
  - stripping once each, and the hopper at half;
  - the sled built;
  - the front mount's either/or;
  - the fittings going on GAR-Y through the lock without stealing its head;
  - the case giving the bear once;
  - the bench pinned;
  - a reload that re-pays nothing.
- When the core has no power, the printer stalls (the existing rule). The test then pushes the job on itself, and says so.
- **By hand, still to check:**
  - the look under game lighting;
  - hinge directions (drawer, hopper lid, case lid, radio lid);
  - whether the station (3.5 m wide) fits well in the General Module;
  - the sled trailing on uneven ground (it's fixed to GAR-Y, not physics);
  - pacing of the free stretch.

## 9. Open questions
1. **Towing the cargo sled and the survey sled together:** nothing stops both today. Should the hitch hold only one?
2. **Hold-G *Tow sled*:** not added. The sled rides whenever the station sets it. A *Survey here* order belongs with Chunk 4's deep lines.
3. **The plush is a free item** (odds_and_ends), so finding it doesn't unlock anything new. It's a story find. Should keepsakes become stock-only in story games?
4. **The old catalogue guitar stays free** alongside the printed one. Retire it in story games?
5. **The hopper route** also works in non-story games with no smelter. Keep it, or story only?
6. **The bench's pin** uses the Dry channel's middle reach from `region_layout.json`. Chunk 4 places the real bench.
