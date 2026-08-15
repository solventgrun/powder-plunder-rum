# Blender First Hull Reference Notes

Generated from scratch in Blender. The rough scale source is the current Godot
`galleon_basic` visual profile:

- hull length 4.35
- hull width 1.72
- hull height 0.76
- bow length 1.08
- stern height 0.55
- forward axis -Z, origin at waterline center

The user-supplied galleon concept image was used for visual direction: warm dark
wood grain, burgundy painted bands, brighter gold trim, ornate raised stern,
curved bow, gun ports, and a strong side silhouette.

2026-08-14 refinement pass:

- brighter warm studio lighting on a neutral medium-light background
- procedural wood grain and subtle bump on hull/deck materials
- smoother hull station profile and softer bevels
- more consistent gunport spacing and framing
- denser rail posts, mid-rails, and clearer gold strakes
- extra stern gallery bars, columns, and lantern hints
- bow correction: raked forward station, shortened forecastle block, and curved
  gold prow rails/stem so the side silhouette no longer reads square

2026-08-14 refinement pass 2:

- sterncastle rebuilt as stepped tapered galleries with larger readable window
  groups, gold columns, side buttresses, crown bar, pediment, and finials
- bow/beakhead integration improved with side sweep rails, lower keel transition,
  bowsprit knees, and a stronger figurehead accent
- hull flow improved with extra painted panel dividers and clearer trim rhythm
- materials kept stylized but separated further: grainy wood, satin paint, and
  brighter aged gold
- added elevated orthographic gameplay-camera render

2026-08-14 refinement pass 3:

- reduced toy-like surface response: darker satin paint, rougher aged gold, and
  more restrained trim thickness
- removed awkward bow protrusions: dark lower bow sweep and extra forward gold nub
- simplified beakhead rails so each protrusion reads as support or stem detail
- added modest central hatch structure and deck slats
- toned down oversized stern crown/finials and reduced rail/post thickness
- added clay inspection render for checking form without material distraction

2026-08-14 refinement pass 4:

- replaced the sterncastle's core box/taper stack with faceted raked gallery
  meshes whose aft faces widen, rake, and curve subtly across the transom
- moved stern windows and columns onto the new transom face instead of floating
  on a flat rectangular back
- reduced stern crown/lantern scale again so the shaped gallery mass carries
  the silhouette instead of decorative primitives

2026-08-14 reference architecture pass:

- prioritized architecture over ornament based on `original.png`
- added quarterdeck/forecastle transition steps to clarify deck-level logic
- added restrained upper gun-deck ports as lintel/sill/reveal structures
- replaced the bow orb with a small carved figurehead assembly and bracket
- added broader framed stern transom panels behind the window/framing layer
- kept ornament limited to framing/bands that explain windows, decks, and hull

2026-08-14 structure-first cleanup pass:

- converted railings from gold tube/icing style to dark structural posts and
  rails with small gold post caps
- added deck edge cap rails, quarterdeck/forecastle transition steps, and
  sweeping stern stair treads to improve top-down deck logic
- rebuilt lower gunports as recessed wood/reveal/lintel/sill assemblies
- standardized upper-deck cannon scale and upper gun-deck port spacing
- kept bow figurehead as carved assembly and added a bow close-up render

2026-08-14 structure correction pass:

- simplified shiny bow/beakhead rods into darker structural knees and shorter
  rails so forward protrusions read as support instead of stray ornament
- strengthened stern side buttresses with dark wood cores and narrow gold caps
- added side-facing stern gallery windows to make the sterncastle read as
  layered ship architecture from side and gameplay angles

2026-08-15 deck and gun-deck correction pass:

- lengthened the hull station profile enough to support the requested gun count
- replaced the rectangular deck block with a shaped deck mesh sampled from the
  hull outline, closing the large top-down gaps along both sides
- updated the side rail/deck-edge paths to follow the longer hull
- standardized two gun decks per side: 12 lower ports and 8 upper ports, with
  the upper ports/cannons now using a consistent readable size
- enlarged the sterncastle stairs into broader curved side runs that sweep
  outward and back inward instead of tiny straight blocks

2026-08-15 sterncastle architecture pass:

- preserved the long hull, shaped deck, broadside count, and overall layout
- removed the forward blocky forecastle structure so the bow deck and rails
  close into the stem instead of a square cabin
- moved the figurehead forward and outside the hull silhouette
- shifted the bowsprit and beakhead supports back onto the actual bow stem
- rebuilt the sterncastle emphasis around wider tiered galleries, deeper window
  bays, heavier columns, balcony undercuts, and larger sweeping stairs
- made railings heavier and more wood-like with thicker dark rails/posts and
  smaller gold caps
- recessed visible upper cannons so they no longer appear pasted onto the side
- increased painted-red wood variation through stronger procedural surface grain

2026-08-15 mast and stern shelf structural pass:

- anchored the mast stumps into the shaped deck with dark mast-partner sockets,
  shadow recesses, and small gold bands so they no longer float above the deck
- tightened sterncastle balcony shelves, sills, roof, and shadow undercuts so
  each deck layer stays inside its gallery tier instead of leaking past it

2026-08-15 sterncastle architecture reset pass:

- focused only on sterncastle structure
- reduced visible floor/deck leakage by replacing oversized shelves with
  internal floor bands and smaller contained walk bands
- shifted the sterncastle footprint into a more upright, centered relationship
  with the main deck
- rebuilt the second level as a taller recessed gallery with two rows of
  rectangular windows plus door openings
- reduced the top level to a smaller ornamental tier with a mast stub
- changed stern windows from square gunport-like bays to taller rectangular
  openings
- enlarged the grand side stairs with solid treads and heavier handrails that
  flare outward then return inward

2026-08-15 sterncastle alignment pass:

- removed the stair flare after it read poorly in the gameplay views
- reduced gallery mesh aft rake so stern corners stop looking angled off the
  hull
- moved lower, middle, and top sterncastle tiers back against a shared stern
  line instead of stacking forward like a step pyramid
- made the second level much more deeply recessed by moving its front face aft
- added a bow-side contact wall and foot so the castle visibly meets the main
  deck
- replaced the top-level mast helper with a mast mounted directly on the
  ornamental top tier

2026-08-15 sterncastle corner artifact fix:

- fixed inconsistent face normals in the tapered-box and stern gallery tier
  meshes; inverted faces made the bevel modifier flare the tier rims outward
  into curled corner spikes, most visible on the starboard sterncastle corners
- moderated gallery tier bevel widths (0.070/0.060 -> 0.035/0.030) so tier
  rims read as crisp cornice lines instead of rolled lips

2026-08-15 hull integration pass:

- buried the sterncastle base into the deck and moved the shared transom line
  aft of the hull's stern tip, with a new red counter fairing and shadow tuck,
  so the castle sides meet the hull instead of floating beside/over it
- shifted transom windows, doors, columns, beams, and the top tier stack aft
  to follow the new stern line
- connected the stair handrails: balusters planted in every tread, a bottom
  newel with gold cap, the outer rail runs on into the landing rail, and the
  inner rail terminates on a post at the landing
- footed the second-level rail posts on the landing and lower gallery roof
  with a shared level rail height
- rebuilt gunports as surface-oriented recessed assemblies that hug the local
  hull skin (shadow cut ring, thin architrave, sunken reveal/port faces), and
  aligned the upper-deck cannon barrels to fire through their port centers
  along the hull normal

2026-08-15 balcony and gunport consistency pass:

- gunport frames now sample the exact hull mesh skin (station vertex math with
  per-station sheer softener, lerped like the mesh faces) so every port sits
  at the same shallow recess depth instead of some floating and some burying
- replaced the stair landing and inward-curving second-level rail with a
  distinct railed balcony: overhanging plank deck on knee brackets, perimeter
  posts and rails, front rail guarding the drop, and side openings where the
  stair handrails arrive
- the bulwark rail now hands off to the balcony rail through a tall corner
  stanchion, keeping the fall barrier continuous deck-to-stair-to-balcony
- fixed the main deck mid rail floating above the top rail

2026-08-15 broadside and bow-face detail pass:

- moved the gold strake, rivet rows, and panel dividers so nothing bisects a
  gunport (strake 0.63 -> 0.55, rivet rows 0.34/0.60 -> 0.30/0.55, dividers
  re-seated at the midpoints between upper ports), and re-laid planking,
  strakes, rivets, and dividers on the exact hull skin so they no longer
  float off the wavy surface
- added lower gun deck cannon muzzles through the lower port centers
- rebuilt the sterncastle's bow-facing openings with dedicated forward-proud
  ornate assemblies: a paneled double balcony door with gold architrave,
  entablature, and handles, flanked windows with mullions, deep glass, and
  pediment crowns, plus a matching cabin door and windows at deck level

2026-08-15 assembly organization pass (plan deliverable D1):

- added organize_assemblies(): every generated object is parented (world
  transforms preserved) into the Godot-facing assembly tree from
  docs/design/galleon-sails-rigging-plan.md — Galleon root, Hull with
  HullMesh/Deck/Sterncastle/Railings/Gunports/Cannons join-target groups,
  Fore/Main/Mizzen mast assemblies (empties pivoted at their deck partners),
  BowspritAssembly, plus empty Flags and EffectsAnchors groups for D5
- classification is by name prefix; mast partner deck hardware deliberately
  stays under Deck so hiding a mast assembly leaves a plausible socket
- verified no visual change: post-pass renders match the pre-pass baseline

2026-08-15 masts and yards pass (plan deliverable D2):

- replaced the three mast stubs with full assemblies: tapered lower masts
  (new add_spar cone-frustum helper), round top platforms with gold rims,
  overlapping tapered topmasts with gold doubling bands, and gold masthead
  finials; heights match the galleon_basic profile (fore 2.70, main 3.20,
  mizzen 2.55 above deck) so the export stays drop-in for the gameplay slot
- course and topsail yards with gold slings on fore and main (sling radius
  derived from the local mast taper so it always encircles the mast), raked
  lateen yard on the mizzen overhanging the sterncastle, and a sprit yard
  with gold collar under the outer bowsprit
- the old gold mast band became a proper encircling ring instead of a bar

2026-08-15 healthy sails pass (plan deliverable D3):

- six deformable sail sheets (13x11 quad grids, smooth-shaded, thin solidify),
  each its own named object on the shared neutral canvas material:
  Sail_course_fore, Sail_topsail_fore, Sail_course_main, Sail_topsail_main,
  Sail_lateen_mizzen, Sail_sprit_bowsprit
- moderate wind fill is baked into the mesh: square sails billow bow-ward
  with depth zero at head/clews and deepest at the mid foot, topsails taper
  toward their heads, the lateen is a triangular sheet along the raked yard
  billowing to starboard with its clew held forward of the sterncastle front
- fill tuning after first render: billow peak moved to ~70% down the sail
  (foot keeps 77%), depths increased, course feet raised for clear air, and
  foot edges arc up between the clews so sails stop reading as flat cards

2026-08-15 rigging pass (plan deliverable D4):

- stylized standing rigging as four multi-spline curve objects (one per
  group, no per-rope objects): Rigging_fore, Rigging_main, Rigging_mizzen,
  Rigging_bowsprit — stays, backstays, three shrouds per side on fore/main,
  two on mizzen, course yard lifts, lateen peak lift/downhaul/sheet, bobstay
  and sprit yard guys/lifts; every rope has a light parabolic sag
- routes chosen to clear the filled sails: the main stay lands on the fore
  masthead instead of the bow (a bow run would pierce the fore course), the
  bobstay starts mid-bowsprit aft of the spritsail canvas, and sprit yard
  guys run from the yard tips outside the sail's width

2026-08-15 streamers and anchors pass (plan deliverable D5):

- three bright red masthead streamers (thin tapering ribbon grids with a
  baked aft-flying S-curl, matching the concept sheet's banners) under the
  Flags group: Streamer_fore, Streamer_main, Streamer_mizzen
- four anchor empties for the runtime systems: Anchor_Flag_Stern (ornamental
  stern mast) and Anchor_Flag_Main (main masthead) under Flags,
  Anchor_Fire_Deck and Anchor_Fire_Sail under EffectsAnchors at the
  gameplay-tuned visual_states positions from ship_visual_profiles.yaml

2026-08-15 shared ship kit extraction:

- moved the ship-agnostic machinery into artifacts/ship_kit (materials,
  primitives, HullForm hull math with skin/gunport/shaped-deck builders,
  mast assemblies, sail grids, rope bundles, assembly organization, the
  review lighting/render rig, and the GLB flatten/export helpers) so the
  next ship classes reuse it; this file now holds only galleon content
- verified zero visual change: post-extraction renders match the previous
  set pixel-for-pixel and the rebuilt GLB is structurally identical
