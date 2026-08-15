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
