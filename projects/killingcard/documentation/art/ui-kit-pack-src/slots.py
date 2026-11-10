# Slot data for the KillingCard UI kit prompt pack. Imported by gen.py.
# Each slot: id, file, cat, sec, gen, ship, alpha, nine, states, used, pri, subj, avoid(optional), notes(optional)

ICON_GEN = "1024x1024"
ICON_SHIP = "256x256 master (export 128/64/48/32)"

S = []


def icon(sec, id_, used, pri, subj, avoid="", states="normal / lit (tint) / idle grey (tint)", notes=""):
    S.append(dict(id=id_, file=f"ico_{id_}.png", cat="icon", sec=sec, gen=ICON_GEN, ship=ICON_SHIP,
                  alpha="luma", nine="", states=states, used=used, pri=pri, subj=subj, avoid=avoid, notes=notes))


def part(cat, sec, id_, file, used, pri, subj, gen="1024x1024", ship="", alpha="alpha", nine="", states="normal",
         avoid="", notes=""):
    S.append(dict(id=id_, file=file, cat=cat, sec=sec, gen=gen, ship=ship, alpha=alpha, nine=nine, states=states,
                  used=used, pri=pri, subj=subj, avoid=avoid, notes=notes))


# ---------------------------------------------------------------- icons: stats and resources
sec = "Stats and resources"
icon(sec, "stat_firepower", "FP badge on every banner, hand card, inspector, Operator flyout, ghosts", "P1",
     "a gun-sight reticle: a thick circle broken by four short gaps at top, bottom, left and right, with a solid dot in the centre")
icon(sec, "stat_armor", "Armor badge on every banner and hand card (amber when damaged, by tint)", "P1",
     "a plain armor plate: a tall rounded-bottom plate shape with a thick rim and a smaller solid inner plate, the face completely empty",
     avoid="crest, emblem, cross, star or any mark on the plate")
icon(sec, "stat_cover", "Cover chip left of the Armor badge; Cover-absorbed hit (-0); Field auras", "P1",
     "a low concrete road barrier block seen from the front (wide trapezoid base, flat top), with one short curved arc bouncing off its top edge")
icon(sec, "stat_supply", "Supply row in the tray (SUPPLY 3/4), Operator '1 SUPPLY' plate, cost tooltips", "P1",
     "a squat supply crate seen straight on, with one strap across the middle and a small solid triangle pointing up above it")
icon(sec, "stat_deck", "DECK badge (strip bottom), deck view button on run map and rewards", "P1",
     "three playing-card rectangles stacked with a small diagonal offset, the top card plain")
icon(sec, "stat_discard", "Used / discard count in the DECK flyout", "P2",
     "two playing-card rectangles fanned apart with a curved arrow running underneath them from right to left")
icon(sec, "stat_hand", "HAND · n PEEK tab, hand cap in the score sheet", "P2",
     "three playing-card rectangles held in a tight fan, spreading upward from one corner")
icon(sec, "stat_intel", "RIVAL badge, red-dot reveal, Recon tooltips, intel lines in flyouts", "P1",
     "a radar sweep: a quarter-circle wedge with two thin concentric arcs inside it and one solid dot near the outer arc",
     notes="Replaces intel_contact in the old sheet (keep the id alias).")
icon(sec, "range_close", "Range word chip on the objective tile, class tooltips", "P3",
     "one thick chevron pointing right next to a short vertical post", states="normal (tint)")
icon(sec, "range_mid", "Range chip on the objective tile", "P3",
     "two thick chevrons pointing right next to a short vertical post", states="normal (tint)")
icon(sec, "range_long", "Range chip on the objective tile", "P3",
     "three thick chevrons pointing right next to a short vertical post", states="normal (tint)")
icon(sec, "streak", "STREAK badge, streak meter in the flyout, after-action BEST STREAK", "P1",
     "a rising zig-zag line of three steps that ends in a solid arrowhead pointing up and to the right")
icon(sec, "eliminated", "Killfeed toast and log, after-action ELIMINATIONS, elimination stamp", "P2",
     "a minimal stylised skull seen from the front: rounded cranium, two hollow eye shapes, a short row of square teeth; no crossbones, no helmet, no wings",
     avoid="crossbones, bones, a helmet, wings, flames, any badge or emblem shape around it")
icon(sec, "tickets", "REINFORCEMENT TICKETS on the run map, run end", "P2",
     "a ticket stub with a perforated edge down one side and a round notch cut out of each end")
icon(sec, "round", "Round counter in the SCORE badge flyout and the pause header", "P3",
     "a stopwatch: a circle with a small button on top and a single hand pointing to one o'clock")
icon(sec, "fired", "Fired pip on each banner that has shot this round (cleared at Score)", "P2",
     "a single spent rifle cartridge case lying on its side, open end to the right, no bullet in it")
icon(sec, "heal", "Heal number (+n) from Patch, Aid Station and Undead (tinted teal or green, never red)", "P2",
     "a plus sign made of two thick bars with rounded ends, centred inside a thin rounded square outline",
     avoid="a red cross, a red crescent, any medical emblem; the icon is pure white and is tinted green in game")
icon(sec, "damage", "Hit marker beside damage numbers, killfeed, now-firing tracer end", "P2",
     "an impact burst: a small solid centre with four sharp triangular shards flying outward diagonally")
icon(sec, "score", "SCORE badge, score sheet, after-action SCORE", "P1",
     "a triangular pennant on a short vertical pole planted in a flat base line, the pennant plain with no pattern",
     avoid="any national flag pattern, stripes, stars, emblem on the pennant")

# ---------------------------------------------------------------- icons: keywords
sec = "Keywords"
kwnote = "Neighbour-link arrows (Guard down, Spotter up) are drawn by the code so they can flip for the rival; the icon is only the base shape."
icon(sec, "kw_first_shot", "Banner effect slot, hand card, inspector, FIRST SHOT tag in the Firefight", "P1",
     "a single bullet flying to the right, pointed tip, with three straight horizontal speed lines trailing behind it")
icon(sec, "kw_pick", "Banner effect slot, Pick tracer tag, inspector", "P1",
     "a sniper scope view: a thick circle with a thin cross inside it, and a small solid square bracket around one point in the lower right quadrant")
icon(sec, "kw_flank", "Banner effect slot, Flank tracer tag, inspector", "P1",
     "a thick curved arrow that leaves from the left, swings around the top of a small solid square, and hooks down into the right side")
icon(sec, "kw_pierce", "Banner effect slot on Marksman and Ace, '-1 PIERCE' second number, inspector", "P1",
     "a straight arrow pointing down that passes through the middle of a thick chevron (the chevron opens downward), the arrow shaft visible above and below it")
icon(sec, "kw_suppress", "Banner effect slot (Gunner), suppressed status, inspector", "P1",
     "three short parallel diagonal tracer lines coming down from the upper left onto a thick horizontal bar, pressing it down")
icon(sec, "kw_patch", "Banner effect slot (Combat Medic), heal tag, inspector", "P1",
     "a field bandage roll seen from the side with a strip unrolling from it in a loose curl",
     avoid="a cross, plus sign or any medical emblem on the bandage")
icon(sec, "kw_holder", "Banner effect slot, control tooltip (counts for holding the column)", "P2",
     "a solid triangular marker pennant on a short post driven into a flat ground line, with a small arc of ground around the base",
     avoid="national flag patterns, emblems on the pennant")
icon(sec, "kw_protector", "Banner effect slot, TAKES THE FRONT preview, Protector slide", "P1",
     "a tall solid riot-shield shape with a small rectangular viewport slot, standing in front of a smaller rounded helmet outline that is half hidden behind it")
icon(sec, "kw_hidden", "Hidden Field traps (Tripwire), hide-from-intel effects, dashed TRAP chip", "P2",
     "an almond eye shape with its lid half closed and one thick diagonal slash across it")
icon(sec, "kw_guard", "Keyword pip on Trained banners and hand cards, link preview, inspector", "P1",
     "a short solid wall made of two rows of thick rectangular blocks, two blocks in the bottom row and one centred block on top, compact and square", notes=kwnote + " Not a shield: the shield shape is Armor.",
     avoid="an arrow (the game adds it), a shield shape, a circle")
icon(sec, "kw_spotter", "Keyword pip, link preview, inspector", "P1",
     "a pair of binoculars seen from the front, drawn as two thick upright rectangular barrels side by side joined by a short solid bridge, compact and square", notes=kwnote + " Not an eye: the eye is the PREVIEW toggle.",
     avoid="an arrow (the game adds it), an eye, round lenses or circles")
icon(sec, "kw_fireteam", "Keyword pip, link preview, inspector", "P1",
     "two thick open chevrons pointing away from each other, one pointing left and one pointing right, with a small gap between them")
icon(sec, "kw_overwatch", "Keyword pip, link preview, inspector", "P1",
     "a short thick horizontal bar like a visor slit with a solid square in its middle, and one solid triangular arrowhead on each side pointing outward left and right, compact",
     avoid="a circle, a ring, a reticle or crosshair")
icon(sec, "trig_on_deploy", "'On deploy' effect line and banner effect slot", "P2",
     "a solid downward arrow landing on a flat bar, with two short impact lines on each side of the bar")
icon(sec, "trig_on_down", "'On down' effect line and banner effect slot", "P2",
     "a playing-card rectangle tipping over to the right with a small motion arc beside it")
icon(sec, "effect_bolt", "Banner effect slot for triggered or aura text (with a dot if more), Field auras", "P1",
     "a bold lightning bolt with three straight segments, thick and angular")
icon(sec, "kw_aura", "Field aura marker on banners in a Field's column, objective tile chip", "P2",
     "a small solid square with four short thick bars radiating from its four sides, like a signal spreading outward",
     avoid="circles, rings, a reticle")

# ---------------------------------------------------------------- icons: traits
sec = "Traits"
icon(sec, "trait_vanguard", "Trait pip on banners and hand cards, trait rail, SETS flyout, Doctrine tiles, deck view", "P1",
     "two thick stacked upward chevrons, one above the other, like a rank stripe pointing up",
     avoid="a rank insignia layout, stars, laurels")
icon(sec, "trait_specops", "Trait pip, rail, flyout, Doctrine, deck view", "P1",
     "a face mask seen from the front: a wide band shape with two narrow rectangular eye slits cut out of it",
     avoid="a skull, a face, any emblem")
icon(sec, "trait_heavy", "Trait pip, rail, flyout, Doctrine, deck view", "P1",
     "a heavy machine gear: a thick ring with eight short square teeth around it and a solid hub in the centre")
icon(sec, "trait_undead", "Trait pip, rail, flyout, Doctrine, deck view, UNDEAD HEAL tag", "P1",
     "a bony hand with four fingers reaching up out of a flat ground line, only the hand and wrist visible",
     avoid="blood, rot, a skull, gore")

# ---------------------------------------------------------------- icons: card types and marks
sec = "Card types and card marks"
icon(sec, "type_unit", "Hand card type glyph, Codex UNITS filter, inspector type line", "P1",
     "the head-and-shoulders silhouette of a soldier in a rounded helmet seen from the front, no face details")
icon(sec, "type_tactic", "Hand card type glyph, Codex TACTICS filter, inspector", "P1",
     "a tactical plan: a curved dashed arrow from a small circle to a small X")
icon(sec, "type_field", "Hand card type glyph, Codex FIELDS filter, objective Field chips", "P1",
     "a small fortified position: a low sandbag wall arc of four rounded bags with a short pole standing behind it",
     notes="Was type_equipment in the old sheet (keep the id alias).")
icon(sec, "type_killstreak", "Codex KILLSTREAKS filter, killstreak inspector, run rewards", "P1",
     "a chevron-shaped aircraft silhouette seen from above with two short contrails behind it",
     avoid="a real aircraft shape, roundels, markings")
icon(sec, "type_operator", "Operator plate, Operator flyout header, OPERATOR badge (with the camo swatch)", "P1",
     "a single military dog tag with rounded corners, a hole near the top and a short ball chain looping from it",
     avoid="engraved letters or numbers on the tag")
icon(sec, "elite_star", "Elite chassis mark on banners, hand cards and Codex tiles (Ace, Commander)", "P2",
     "a bold five-pointed star with slightly rounded points", avoid="a circle or badge around the star, wreaths")
icon(sec, "trap", "Hidden Field (trap) chip on the objective tile, dashed", "P2",
     "a tripwire: a thin taut line between two short stakes with a small solid box charge clipped to the middle")
icon(sec, "plan_mark", "PLAN / INCOMING marker, rival planned-per-column intel", "P2",
     "a small face-down card rectangle with a solid dot in its centre and a short down arrow above it")

# ---------------------------------------------------------------- icons: weapon classes
sec = "Weapon classes"
cls_avoid = "a real gun model or brand, engravings, markings, a scope brand"
icon(sec, "class_ar", "Class pip on banners (outer-left), Codex AR filter, range bonus tooltip", "P1",
     "side-profile silhouette of a generic compact assault rifle pointing right: straight magazine, short rail on top, folding stock", avoid=cls_avoid)
icon(sec, "class_smg", "Class pip, Codex SMG filter", "P1",
     "side-profile silhouette of a short boxy submachine gun pointing right, long straight magazine, stubby barrel, small stock", avoid=cls_avoid)
icon(sec, "class_shotgun", "Class pip, Codex SHOTGUN filter", "P1",
     "side-profile silhouette of a pump shotgun pointing right, long tube under the barrel, a ridged pump grip, solid stock", avoid=cls_avoid)
icon(sec, "class_sniper", "Class pip, Codex SNIPER filter", "P1",
     "side-profile silhouette of a long bolt-action rifle pointing right with a long scope on top and a folded bipod under the barrel", avoid=cls_avoid)
icon(sec, "class_lmg", "Class pip, Codex LMG filter", "P1",
     "side-profile silhouette of a heavy belt-fed machine gun pointing right, a box under the middle, a carry handle on top, bipod folded forward", avoid=cls_avoid)
icon(sec, "class_sidearm", "STREAK flyout P-12 tile, Loadout secondary slot, Operator secondary", "P2",
     "side-profile silhouette of a plain compact pistol pointing right", avoid=cls_avoid,
     notes="Not a card class in data (WeaponClass has 5). The 6th class icon is for the Operator's secondary.")

# ---------------------------------------------------------------- icons: killstreaks and equipment
sec = "Killstreaks and Operator equipment"
ks_avoid = "a real drone, helicopter or aircraft model, roundels, markings, numbers"
icon(sec, "ks_recon_drone", "Killstreak tile in the tray (charge ring), STREAK flyout, Codex, call-in", "P1",
     "a small quadcopter drone seen from the front, four rotor discs, with a downward cone of three short lines under it", avoid=ks_avoid,
     states="charging grey / ready amber / used dim (tint) + ring")
icon(sec, "ks_mortar", "Killstreak tile (Mortar Barrage), flyout, Codex", "P1",
     "three falling mortar shells in a row, nose down, each with a short curved trail above it", avoid=ks_avoid,
     states="charging / ready / used (tint) + ring")
icon(sec, "ks_attack_helo", "Killstreak tile (Attack Helo), flyout, Codex", "P1",
     "side-profile silhouette of a fictional slim attack helicopter flying right, one main rotor line on top, a stub wing, a nose turret", avoid=ks_avoid,
     states="charging / ready / used (tint) + ring")
icon(sec, "ks_sentry", "Killstreak tile (Sentry Turret), flyout, Codex, Sentry token gear mark", "P1",
     "a compact automated gun turret on a tripod, a boxy head with one short barrel pointing right", avoid=ks_avoid,
     states="charging / ready / used (tint) + ring")
icon(sec, "ks_gunship", "Gunship card (Codex, rewards), reserved killstreak tile", "P3",
     "side-profile silhouette of a fictional heavy four-engine propeller plane flying right with a side gun barrel under the wing", avoid=ks_avoid)
icon(sec, "eq_frag", "STREAK flyout FRAG tile (Lethal), Loadout lethal slot, cooldown", "P1",
     "a round fragmentation grenade with a lever on its side and a pull ring on top, no pattern on the body", states="ready / cooldown dim (tint)")
icon(sec, "eq_flash", "STREAK flyout FLASH tile (Tactical), Loadout tactical slot, cooldown", "P1",
     "a short cylindrical stun grenade with a lever and ring, three short burst lines radiating from its top", states="ready / cooldown dim (tint)")
icon(sec, "att_optic", "Loadout attachment (Holo Sight), Weapon Level reward", "P3",
     "a small open holographic gun sight seen from the side: a rectangular window frame on a short base, a dot inside the window")
icon(sec, "att_grip", "Loadout attachment (Foregrip), Weapon Level reward", "P3",
     "a vertical gun foregrip seen from the side: a ridged handle hanging from a short rail section")
icon(sec, "att_mag", "Loadout attachment (Extended Mag), Weapon Level reward", "P3",
     "a long curved rifle magazine seen from the side, slightly longer than normal, with a small base plate")
icon(sec, "att_lining", "Loadout attachment (Ceramic Lining), Weapon Level reward", "P3",
     "a hexagonal ceramic tile pattern of seven small hexagons forming a plate")
icon(sec, "perk_slot", "Loadout perk slot, Perk Offer reward header (the perks keep their painted patches)", "P3",
     "a round stitched patch outline with a small four-pointed spark in the middle")

# ---------------------------------------------------------------- icons: objective and control
sec = "Objective, control and Field"
icon(sec, "ctl_yours", "Objective tile control mark (YOURS), minimap, score sheet; tinted teal", "P1",
     "a thick solid ring with a solid dot in the centre", states="normal (tint teal)")
icon(sec, "ctl_rival", "Objective tile control mark (RIVAL); tinted red. Shape cue for colour-blind players", "P1",
     "a solid diamond with a small notch cut into each of its four corners", states="normal (tint red)")
icon(sec, "ctl_even", "Objective tile control mark (EVEN, was CONTESTED)", "P1",
     "a square drawn as a thick dashed outline, eight dashes, empty inside", states="normal (tint grey)")
icon(sec, "ctl_open", "Objective tile control mark (OPEN: nobody there)", "P2",
     "a thin plain circle outline, empty, with four tiny ticks pointing inward", states="normal (tint grey)")
icon(sec, "overrun", "FIELD OVERRUN callout, overrun risk on the Field chip, OVERRUN tag", "P1",
     "a low sandbag wall broken in the middle with two thick arrows crashing through the gap from above", states="normal / warning pulse (tint red)")
icon(sec, "field_slot", "Empty Field slot on the objective tile (your half), placement hint", "P2",
     "a dashed rounded rectangle with a small plus sign in the centre")

# ---------------------------------------------------------------- icons: phases and modes
sec = "Phases, firefight and run modes"
icon(sec, "ph_deploy", "Phase header (DEPLOY), tutorial coach, score sheet", "P2",
     "a playing-card rectangle sliding down into a slot, a short down arrow above it")
icon(sec, "ph_reveal", "Phase header (REVEAL)", "P2",
     "a playing-card rectangle turning over, half of it shown as a thin edge, with two short spark lines")
icon(sec, "ph_firefight", "Phase header (FIREFIGHT), order strip, tray step header", "P2",
     "two short bullets pointing at each other from left and right with a small burst between them")
icon(sec, "ph_score", "Phase header (SCORE & STREAK)", "P2",
     "a pennant on a pole next to a short rising stepped line")
icon(sec, "mode_zone_control", "Run map mode chip (Zone Control), match intro", "P2",
     "three small circles in a row joined by a line, the middle one solid")
icon(sec, "mode_firefight", "Run map mode chip (Firefight)", "P2",
     "two crossed straight tracer lines with a small dot where they cross",
     avoid="crossed rifles, crossed swords, a badge")
icon(sec, "mode_detonator", "Run map mode chip (Detonator)", "P2",
     "a small explosive charge block with a short antenna and a curled wire",
     avoid="numbers on a timer, text")
icon(sec, "mode_rival", "Run map RIVAL (boss) match, rival squad header", "P2",
     "a helmeted head silhouette in profile facing left with a small notched diamond beside it")

# ---------------------------------------------------------------- icons: menu and system
sec = "Menu and system"
icon(sec, "ui_menu", "MENU badge (strip top), title", "P1", "three thick horizontal bars of equal length stacked with equal gaps", states="normal / pressed (tint)")
icon(sec, "ui_settings", "Settings row in the pause menu, title", "P2", "a simple cog wheel with six rounded teeth and a round hole in the middle")
icon(sec, "ui_undo", "UNDO button in the tray (Deploy)", "P1", "a thick curved arrow that loops back to the left, like a U-turn pointing left", states="normal / disabled (tint)")
icon(sec, "ui_speed", "SPEED x2 button in the tray (Firefight), settings", "P1", "two solid triangles pointing right, touching tip to base, like fast-forward", states="off / on amber (tint)")
icon(sec, "ui_skip", "Skip the round playback, skip reward", "P2", "a solid triangle pointing right followed by a thick vertical bar")
icon(sec, "ui_codex", "CODEX buttons on the title and pause menu, Codex header", "P1", "an open binder with three card rectangles fanned out of it")
icon(sec, "ui_mirror", "MIRROR LAYOUT setting", "P2", "two half-rectangles facing each other across a dashed vertical line, with a small two-way arrow on top")
icon(sec, "ui_sound_on", "Sound setting ON", "P2", "a speaker cone shape with two curved sound waves on its right")
icon(sec, "ui_sound_off", "Sound setting OFF", "P2", "a speaker cone shape with a small X on its right")
icon(sec, "ui_close", "CLOSE on the inspector, flyouts, Codex, modals", "P1", "a thick X with squared ends")
icon(sec, "ui_back", "BACK on Codex, Loadout, Retire picker", "P1", "a thick chevron pointing left with a short horizontal tail")
icon(sec, "ui_info", "Long-press hint, rules buttons, tooltips header", "P1", "a solid circle with a cut-out tall bar and a cut-out dot above it")
icon(sec, "ui_eye", "PREVIEW badge ON", "P1", "an open almond eye with a solid round pupil", states="on (tint)")
icon(sec, "ui_eye_off", "PREVIEW badge OFF", "P1", "an open almond eye outline with one thick diagonal slash across it", states="off (tint)")
icon(sec, "ui_filter", "Codex filter bar, CLEAR FILTERS", "P2", "a funnel shape made of three horizontal bars getting shorter downward")
icon(sec, "ui_check", "Picked / ticked states, order strip finished column, PICKED tiles", "P1", "a thick tick mark with squared ends")
icon(sec, "ui_lock", "Locked Codex art, not-yet-unlocked reward", "P2", "a closed padlock with a round shackle and a keyhole")
icon(sec, "ui_continue", "CONTINUE, BEGIN RUN, DEPLOY on the run map, NEXT", "P2", "a thick chevron pointing right with a short horizontal tail")
icon(sec, "ui_retire", "RETIRE tile on Supply Drop, Retire picker, Honor Roll", "P2", "a playing-card rectangle sliding out to the right with a small curved arrow, a faint outline left behind")
icon(sec, "ui_promote", "PROMOTION reward, level-up band strip", "P2", "a playing-card rectangle with one thick upward chevron above it")
icon(sec, "ui_reward", "SUPPLY DROP header, reward tiles, after-action REWARD", "P2", "a supply crate hanging from a small parachute canopy by three lines")
icon(sec, "ui_rotate", "Rotate-your-phone notice (web shell), Operator Rotate action", "P3", "a phone rectangle with a curved arrow going around one corner")
icon(sec, "ui_survey", "PLAYTEST SURVEY button at run end", "P3", "a clipboard with three short lines and a tick on the top line")
icon(sec, "ui_tutorial", "TUTORIAL row on the title", "P3", "a whistle seen from the side with a short cord loop")

# ================================================================ BUTTONS AND PANELS (9-slice)
sec = "Buttons"
part("button", sec, "btn_primary", "btn_primary.png", "Primary actions: CONTINUE, BEGIN RUN, TAP TO TAKE, DEPLOY (run map), PLAY HERE confirm", "P1",
     "a wide button plate: signal amber #FFB020 face with a slightly darker amber #C98A10 bottom edge 1/8 of its height, a thin darker outline, 45-degree chamfered corners top-left and bottom-right only, a faint brushed-metal grain on the face, a soft one-pixel highlight along the top edge, plain flat face with nothing on it",
     gen="1536x1024", ship="384x128", nine="40,40,40,48", states="normal / hover (code +10% light) / pressed (btn_primary_pressed) / disabled (code grey 55%, alpha 60%)")
part("button", sec, "btn_primary_pressed", "btn_primary_pressed.png", "Pressed state of btn_primary", "P1",
     "the same wide amber button plate as before but pressed in: the face one shade darker #E59A12, the darker bottom edge gone, a thin inner shadow along the top edge, same chamfered corners, same size and outline",
     gen="1536x1024", ship="384x128", nine="40,40,40,48", states="pressed",
     notes="Generate in the same chat right after btn_primary ('same plate, pressed in').")
part("button", sec, "btn_secondary", "btn_secondary.png", "Secondary actions: BACK, SKIP, DETAILS, DECK, CODEX, pause menu rows, Codex filter bar buttons", "P1",
     "a wide button plate: dark gunmetal #2E3740 face, a 2-pixel steel #4A535B outline, a slightly darker #232A31 bottom edge 1/8 of its height, 45-degree chamfered corners top-left and bottom-right only, faint brushed grain, a thin cool highlight along the top edge, plain empty face",
     gen="1536x1024", ship="384x128", nine="40,40,40,48", states="normal / hover (+10%) / pressed (btn_secondary_pressed) / disabled (grey 55%) / selected (fx_outline_teal on top)")
part("button", sec, "btn_secondary_pressed", "btn_secondary_pressed.png", "Pressed state of btn_secondary", "P1",
     "the same gunmetal button plate pressed in: face one shade darker #262E35, no bottom edge, a thin inner shadow along the top, same chamfers and outline",
     gen="1536x1024", ship="384x128", nine="40,40,40,48", states="pressed")
part("button", sec, "btn_danger", "btn_danger.png", "Danger / leave actions: BACK TO TITLE, abandon run, NEW RUN confirm", "P2",
     "a wide button plate: deep signal red #B8282B face with a darker #7A1A1C bottom edge 1/8 of its height, a thin dark outline, 45-degree chamfered corners top-left and bottom-right only, faint brushed grain, plain empty face",
     gen="1536x1024", ship="384x128", nine="40,40,40,48", states="normal / hover (+10%) / pressed (code: darker + 2 px down) / disabled (grey)")
part("button", sec, "btn_ready", "btn_ready.png", "READY in the tray (245x64 phone, 149x72 desktop): the main button of every round", "P1",
     "a big wide command button plate: amber #FFB020 face with a darker amber bottom edge, a thick dark #12161A outline, chamfered top-left and bottom-right corners, and a band of three short dark diagonal hazard stripes at the far right end only; the rest of the face is plain and flat",
     gen="1536x1024", ship="512x136", nine="48,40,128,48", states="normal / hover / pressed (btn_ready_pressed) / disabled (grey: nothing planned yet is still allowed, so rare) / glow (fx_glow_amber pulse when the Deploy timer is low)",
     notes="The stripes sit inside the right 9-slice margin so they never stretch.")
part("button", sec, "btn_ready_pressed", "btn_ready_pressed.png", "Pressed state of READY", "P1",
     "the same READY button plate pressed in: amber face one shade darker, no bottom edge, a thin inner top shadow, stripes unchanged",
     gen="1536x1024", ship="512x136", nine="48,40,128,48", states="pressed")
part("button", sec, "btn_badge", "btn_badge.png", "Icon strip badges 62x64 (MENU, SCORE, OPERATOR, STREAK, RIVAL, PREVIEW, DECK), SPEED, UNDO square", "P1",
     "a square badge plate: dark slate #1C2228 face, a 2-pixel steel #3A444D outline, all four corners chamfered at 45 degrees, a thin darker inner bevel, a faint vertical brushed grain, plain empty face",
     ship="128x128", nine="24,24,24,24", states="normal / pressed (code darker) / glow (fx_glow_amber: killstreak ready, Operator DEPLOY) / selected (fx_outline_teal: flyout open)")
part("button", sec, "btn_chip", "btn_chip.png", "Small pill buttons: Codex filters (ALL / UNITS / AR...), tabs on narrow screens, toggles in the deck view", "P2",
     "a small wide pill-shaped plate with flat left and right ends cut at 45 degrees, dark gunmetal #232A31 face, a thin steel #4A535B outline, plain",
     gen="1536x1024", ship="192x64", nine="24,20,24,20", states="normal / selected (btn_chip_on) / pressed (code) / disabled (grey)")
part("button", sec, "btn_chip_on", "btn_chip_on.png", "Selected filter chip / active tab", "P2",
     "the same small pill plate, now selected: face filled with fog white #D8DEE3 at low brightness #A9B3BB, a thin amber #FFB020 underline along the bottom edge, same shape",
     gen="1536x1024", ship="192x64", nine="24,20,24,20", states="selected")
part("button", sec, "btn_tab", "btn_tab.png", "Tabs: SETS flyout (RIVAL / YOU), score sheet, Codex kind tabs on desktop", "P3",
     "a folder-tab shape: a flat-topped trapezoid with chamfered top corners and an open bottom edge, dark gunmetal #232A31 face, thin steel outline on the top and sides only",
     gen="1536x1024", ship="192x80", nine="28,24,28,8", states="inactive / active (code: lighter + amber top line)")
part("button", sec, "tgl_track", "tgl_track.png", "Settings toggles: MIRROR LAYOUT, SPEED x2, FAST ANIMATIONS, PREVIEW", "P2",
     "a horizontal toggle switch track: a long rounded slot recessed into dark metal, inner colour #12161A, thin steel #3A444D rim",
     gen="1536x1024", ship="128x64", nine="30,30,30,30", states="off (grey) / on (code tints the inner teal #2EC4B6)")
part("button", sec, "tgl_knob", "tgl_knob.png", "Toggle knob, slider knob", "P2",
     "a single round knob: brushed fog-white metal disk with a soft edge highlight and three short grip lines in the centre",
     ship="64x64", states="normal / pressed (code darker)")
part("button", sec, "sld_track", "sld_track.png", "Slider track (volume, Deploy timer setting) and progress bars (run tickets)", "P3",
     "a thin long horizontal recessed groove in dark metal, inner #12161A, steel rim, rounded ends",
     gen="1536x1024", ship="256x32", nine="14,14,14,14", states="normal / fill (code tints a copy amber)")

sec = "Panels, trays and overlays"
part("panel", sec, "pnl_tray", "pnl_tray.png", "Hand tray (362x532 phone, 224x776 desktop): background of the hand grid, killfeed log, step header", "P1",
     "a tall rectangular panel: matte gunmetal #1C2228 face with a very faint diagonal brushed grain, a 2-pixel steel #3A444D outline, 45-degree chamfers on the top-left and bottom-left corners only, a thin darker inner bevel; plain empty face, no screws in the middle of the edges",
     gen="1024x1536", ship="256x512", nine="32,32,32,32", states="normal (open / closed share it)")
part("panel", sec, "pnl_flyout", "pnl_flyout.png", "Strip badge flyouts: SCORE, OPERATOR, STREAK, RIVAL, DECK, SETS", "P1",
     "a rectangular pop-out panel: dark slate #161B20 face at slightly lighter centre, a 2-pixel steel #4A535B outline with a thin amber #FFB020 line along the top edge only, all corners chamfered at 45 degrees",
     gen="1536x1024", ship="384x256", nine="32,32,32,32", states="normal")
part("panel", sec, "pnl_flyout_pointer", "pnl_flyout_pointer.png", "The little pointer that joins a flyout to its badge", "P2",
     "a small solid triangular pointer, dark slate #161B20 with a steel #4A535B outline on its two outer sides only, pointing left",
     ship="32x48", states="normal (code flips it for mirror layout)")
part("panel", sec, "pnl_toast", "pnl_toast.png", "Killfeed toasts (top centre, 2 max, 92% opacity), one-time callouts, 'Not enough Supply' toasts", "P1",
     "a slim wide strip panel: near-black #0F1316 face, a short angled cut at both ends like a ribbon, a thin steel outline, a narrow vertical accent bar inset at the left end in fog white (tinted by side in game)",
     gen="1536x1024", ship="384x64", nine="40,16,24,16", states="normal (the left bar is tinted teal / red / amber in code)")
part("panel", sec, "pnl_inspector", "pnl_inspector.png", "Card inspector (512x128 banner + text panel, scrolls), item inspector, long-press rules", "P1",
     "a large rectangular information panel: dark slate #12161A face with a faint fine scanline texture, a 2-pixel steel #4A535B outline, chamfered top-left and bottom-right corners, a thin amber line along the top edge from the left corner for a third of the width",
     gen="1536x1024", ship="512x384", nine="40,40,40,40", states="normal")
part("panel", sec, "pnl_tooltip", "pnl_tooltip.png", "Tooltips (desktop hover), long-press rule bubbles, Supply Drop twin preview", "P1",
     "a small rectangular tooltip panel: near-black #0F1316 face at 95% opacity, a 1-pixel fog-white #D8DEE3 outline at low brightness, small 45-degree chamfers on all four corners",
     ship="192x96", nine="16,16,16,16", states="normal")
part("panel", sec, "pnl_modal", "pnl_modal.png", "Pause menu, match end (VICTORY / DEFEAT), Retire picker, score sheet, consent and surveys", "P1",
     "a large centred dialog panel: gunmetal #232A31 face with a soft lighter centre, a 3-pixel steel #4A535B outline and a thin inner second outline 6 pixels inside, chamfered corners on all four sides, a small plain rivet in each corner",
     gen="1536x1024", ship="512x384", nine="48,48,48,48", states="normal")
part("panel", sec, "pnl_header", "pnl_header.png", "Screen title bars: SUPPLY DROP, CODEX, RUN SUMMARY, PAUSED, STARTER KIT", "P2",
     "a long horizontal title bar plate: dark gunmetal face, a thin amber #FFB020 line along the bottom edge, both ends cut at 45 degrees, plain",
     gen="1536x1024", ship="512x64", nine="40,16,40,16", states="normal")
part("panel", sec, "pnl_hand_tab", "pnl_hand_tab.png", "HAND · n PEEK tab (362x64) in the closed tray", "P2",
     "a wide tab plate that looks like the top edge of a drawer: gunmetal face, a thin steel outline, chamfered top corners, a short row of three grip lines centred on the top edge",
     gen="1536x1024", ship="384x80", nine="40,24,40,16", states="normal / pressed (code)")
part("panel", sec, "pnl_ks_tile", "pnl_ks_tile.png", "Killstreak tile backer (61 px) at the top of the tray and in the STREAK flyout", "P1",
     "a square tile plate: dark slate #12161A face, a thin steel outline, chamfered corners, a circular recessed socket in the middle taking up 70% of the tile",
     ship="128x128", nine="", states="charging / ready (fx_glow_amber + amber frame by code) / used (code dim)")
part("panel", sec, "ring_track", "ring_track.png", "Killstreak charge ring (empty track); TextureProgressBar under", "P1",
     "a thick flat circular ring track divided into eight equal segments by thin gaps, dark steel #2E3740, perfectly round, centred, nothing inside the ring",
     ship="128x128", states="normal")
part("panel", sec, "ring_fill", "ring_fill.png", "Killstreak charge ring fill; TextureProgressBar radial (tinted amber / cyan)", "P1",
     "the same thick circular ring divided into eight equal segments by thin gaps, solid pure white, perfectly round, centred, same size as before, nothing inside",
     ship="128x128", alpha="luma", states="fill (code tints: charging cyan #5BC0EB, ready amber #FFB020)",
     notes="Generate right after ring_track in the same chat so the segments line up.")
part("panel", sec, "pip_supply", "pip_supply.png", "Supply pips (up to 10) in the tray", "P1",
     "a single small hexagonal pip seen front-on: solid pure white hexagon with a thin cut-in inner bevel line",
     ship="64x64", alpha="luma", states="full (tint amber) / empty (tint dark steel, 40%) / spent this Deploy (tint grey)")
part("panel", sec, "pnl_counter", "pnl_counter.png", "Small number bubble: hand count, deck count on badges, '+n more', unread log", "P2",
     "a small rounded-rectangle counter plate, near-black #0F1316 face, a thin fog-white outline, slightly taller than a circle",
     ship="64x48", nine="16,16,16,16", states="normal / tinted by side")
part("panel", sec, "pnl_order_strip", "pnl_order_strip.png", "Firefight order strip A -> B -> C over the board", "P1",
     "a slim horizontal strip plate with both ends cut at 45 degrees, near-black #0F1316 face at 85% opacity, a thin steel outline",
     gen="1536x1024", ship="384x48", nine="24,12,24,12", states="normal")
part("panel", sec, "order_node", "order_node.png", "One column node on the order strip (letter drawn by code)", "P1",
     "a single hexagonal node plate seen front-on: solid pure white hexagon with a thick rim and a slightly recessed flat centre",
     ship="64x64", alpha="luma", states="pending (grey) / current (amber + fx_glow_amber) / done (teal + ico_ui_check) / skipped (dim 30%)")
part("panel", sec, "order_arrow", "order_arrow.png", "Connector between order nodes", "P1",
     "a short thick right-pointing arrow made of a straight bar and a solid triangular head, solid white",
     ship="64x32", alpha="luma", states="pending / passed (tint)")
part("panel", sec, "pnl_rail_chip", "pnl_rail_chip.png", "Trait rail chips (62x49 phone) and SETS flyout rows", "P2",
     "a small upright chip plate, dark slate face, a thin steel outline, a narrow slot along the left edge for a colour bar, chamfered top-right corner",
     ship="128x96", nine="20,20,20,20", states="idle / lit (code tints the slot by trait) / ring tier 3 (fx_ring_tier3) / crack (fx_crack)")
part("panel", sec, "pnl_callout", "pnl_callout.png", "Set callouts ('VANGUARD 2: ...'), column banner 'COLUMN A', FIRST SHOT tag, DEPLOY / PLAY HERE chips", "P2",
     "a slim angled tag plate like a cut ribbon: a parallelogram with both ends slanted, near-black face, a thin fog-white outline",
     gen="1536x1024", ship="256x48", nine="32,12,32,12", states="normal (code tints outline: green buff, red off, amber ready)")
part("panel", sec, "pnl_pick_tile", "pnl_pick_tile.png", "Reward pick tiles (Supply Drop cards, Retire, Doctrine, Promotion, Perk Offer), Loadout picks", "P1",
     "an upright tile frame: dark gunmetal face, a 2-pixel steel outline, chamfered top-left and bottom-right corners, a slightly lighter band across the bottom fifth for a caption",
     gen="1024x1536", ship="256x384", nine="32,32,32,80", states="normal / hover (+10%) / selected (fx_outline_teal) / disabled (AT THE FLOOR: grey)")
part("panel", sec, "pnl_coach", "pnl_coach.png", "Tutorial coach bubbles over the objective row", "P2",
     "a speech-bubble style info panel with a squared body and a small triangular tail at the bottom left, near-black face, a thin amber outline, chamfered corners",
     gen="1536x1024", ship="384x160", nine="64,32,32,48", states="normal")
part("panel", sec, "pnl_result", "pnl_result.png", "Match end and run end headline plate behind VICTORY / DEFEAT / DRAW", "P2",
     "a wide ceremonial plate: a long horizontal bar with angled ends and two short parallel wing bars above and below it at each end, brushed steel face, plain centre",
     gen="1536x1024", ship="768x160", nine="160,48,160,48", states="victory (code tints amber) / defeat (red) / draw (steel)",
     avoid="wings with feathers, eagles, stars, laurels, a crest")
part("panel", sec, "runmap_node", "runmap_node.png", "Run map match nodes (NEXT / UPCOMING / done)", "P2",
     "a single round map node: a thick ring around a recessed disc, pure white, perfectly round",
     ship="96x96", alpha="luma", states="upcoming (grey) / next (amber + glow) / won (teal + check) / lost (red)")
part("panel", sec, "runmap_path", "runmap_path.png", "Path between run map nodes (tiled)", "P3",
     "a short horizontal dashed line of four thick dashes, pure white, evenly spaced, seamless when repeated",
     ship="128x16", alpha="luma", states="ahead (grey) / travelled (amber)")

# ================================================================ BACKGROUNDS
sec = "Screen backgrounds"


def bg(id_, used, pri, subj, notes="", gen="1536x1024", ship="1536x864 (crop 80 px top and bottom)"):
    S.append(dict(id=id_, file=f"{id_}.png", cat="background", sec=sec, gen=gen, ship=ship, alpha="opaque", nine="",
                  states="normal", used=used, pri=pri, subj=subj, avoid="", notes=notes))


bg("bg_title", "Title screen (KillingCard wordmark drawn by code on the left third)", "P1",
   "a dusk view over a fictional harbour container yard from a high crane: stacked containers in long rows, two gantry cranes as dark silhouettes against an amber horizon glow, one lone operator figure standing on a container in the right third, small and backlit. The left third is calm dark sky and haze for the title and buttons.",
   notes="Replaces assets/ui/backgrounds/title_key_art.webp (Killstreak era).")
bg("bg_menu", "Pause menu backdrop behind pnl_modal, settings, consent and survey screens", "P3",
   "an extreme close-up of a dark matte equipment case lid with a subtle hexagonal foam texture and a faint amber light leak from the top edge; almost abstract, very dark, even, no objects",
   notes="Optional: the pause menu can keep its code scrim.")
bg("bg_run_map", "Run map (5 matches, tickets, DEPLOY)", "P1",
   "a top-down tactical map table: a dark paper map of a fictional harbour district with faint contour lines and water shapes, a few scattered plain playing-card shapes and a compass-free ruler lying on it, cool lamp light from above, very low contrast",
   notes="Replaces bg_run.webp. No letters or grid numbers on the map.")
bg("bg_supply_drop", "Supply Drop / Weapon Level / Perk Offer / Promotion / Doctrine / Regroup reward screens", "P1",
   "a supply crate under a parachute settling into a dark container yard, a floodlight cone on it, dust kicked up; the crate sits in the right fifth, the rest dark and calm for three cards and a fourth tile",
   notes="Replaces the Killstreak-era bg_supply_drop.webp (that one put the crate in the right third; cards now need more room).")
bg("bg_after_action", "After-Action report (VICTORY / DEFEAT, stats, Honor Roll), run end", "P2",
   "a quiet briefing room at night: a long table edge in the foreground with a closed folder and a few cards face down, a dark wall with a faint pin board shape, a single warm lamp on the far right; most of the frame dark and plain")
bg("bg_codex", "Codex (filters + tile grid)", "P2",
   "the inside of a dark armoury locker wall: rows of empty matte card slots and pegboard holes fading into darkness, a thin strip of cool light from the top, extremely calm and even so a grid of tiles can sit on top")
bg("bg_loadout", "Starter deck / Loadout screen (STARTER KIT, picks, BEGIN RUN)", "P2",
   "a gear bench under a hanging work lamp: a dark padded mat with a plain rifle case closed on the left, a neat stack of cards and a helmet on the right edge, the centre of the mat empty and dark")
bg("bg_loading", "Loading screen / web shell splash, boot (wordmark and bar drawn by code)", "P2",
   "a single gantry crane silhouette at night far away across dark water, one amber warning light on its top, heavy fog, almost monochrome, huge empty dark sky",
   notes="Ship also as a 960x540 WebP for the web shell (loads before the engine).")
bg("bg_match", "Match backdrop behind the strip, the 3 columns and the tray", "P1",
   "an abstract top-down view of dark wet concrete with faint painted parking-bay lines worn away, a few oil stains, subtle tyre marks, extremely low contrast, evenly lit, no objects",
   notes="Replaces the tactical_backdrop shader look only if the head prefers it; the shader can stay as the fallback.")

sec = "Column location backdrops (Port Vasel)"
colnote = "Shown behind the slots at 34% opacity, darkened (lane.gd Backing). Replaces the square lane_*.webp from Killstreak, which crop badly into a tall column."
for cid, used, subj in [
    ("col_containers", "Column backing: containers", "a narrow canyon between two walls of stacked shipping containers seen from directly above, long straight shapes running top to bottom, a wet strip of ground down the middle"),
    ("col_cranes", "Column backing: cranes", "the steel lattice of a gantry crane leg and rail tracks seen from above, running top to bottom, a few cable shadows, dark water at one side"),
    ("col_offices", "Column backing: offices", "the flat roof of a low port office block seen from directly above: air-conditioning boxes, roof vents, a stair hatch, a parapet edge running top to bottom"),
]:
    S.append(dict(id=cid, file=f"{cid}.png", cat="background", sec=sec, gen="1024x1536",
                  ship="512x1216 (crop the middle 648x1536, resize)", alpha="opaque", nine="", states="normal (dimmed in code)",
                  used=used, pri="P1", subj=subj + ". Top-down, very low contrast, flat even light, no focal point, nothing bright in the middle, similar detail all the way from top to bottom.",
                  avoid="", notes=colnote))

sec = "Objective and Field tile backers"
part("tile", sec, "tile_objective", "tile_objective.png", "Objective tile between the fronts (228x52 phone, 304x96 desktop): FP pair, control mark, words, Field chips", "P1",
     "a wide low plate set into the ground like a steel floor hatch: dark gunmetal #232A31 face, a 2-pixel steel #3A444D outline, small chamfered corners, two faint recessed grooves running across near the left and right ends, plain flat centre",
     gen="1536x1024", ship="456x112", nine="24,20,24,20", states="normal / your control (code edge teal) / rival control (edge red) / even (dashed edge, code)")
part("tile", sec, "tile_field_chip", "tile_field_chip.png", "Field chip on the objective tile (70x22 phone, 96x28 desktop), one per side", "P1",
     "a small wide chip plate shaped like a dog-ear tag: a rectangle with the top-right corner clipped, near-black face, a thin fog-white outline, a short slot at the left end for a side colour bar",
     gen="1536x1024", ship="192x64", nine="24,16,24,16", states="yours (code tint teal) / rival (red) / overrun risk (fx_glow_red pulse) / trap (dashed: tile_field_chip_trap)")
part("tile", sec, "tile_field_chip_trap", "tile_field_chip_trap.png", "Your hidden trap chip (dashed, only you see it)", "P2",
     "the same small clipped-corner chip shape drawn only as a dashed fog-white outline, the face transparent",
     gen="1536x1024", ship="192x64", nine="24,16,24,16", states="normal")
part("tile", sec, "tile_slot_empty", "tile_slot_empty.png", "Empty row slot in a column (your landing slots, rival back rows)", "P2",
     "a very wide low rectangle drawn as a faint thin steel outline with small corner brackets at each corner, the face nearly transparent dark #12161A at 30%",
     gen="1536x1024", ship="456x114", nine="20,20,20,20", states="normal / valid target (code teal outline) / invalid (code dim)")

# ================================================================ CARD FRAME PARTS
sec = "Board banner frame (4:1)"
part("frame", sec, "frm_banner", "frm_banner.png", "Every board banner (228x57 phone, 304x76 desktop, 512x128 inspector): the steel frame around the art", "P1",
     "a very wide thin picture frame, four times wider than tall: a 3-pixel dark steel #3A444D border with a 1-pixel lighter top-left bevel, small 45-degree chamfers at the top-right, bottom-left and bottom-right corners, a hexagon-shaped notch cut into the top-left corner (for the cost plate), the inside of the frame completely empty",
     gen="1536x1024", ship="512x128", nine="40,32,16,16", states="normal / selected (fx_outline_teal) / now firing (fx_outline_side) / damaged (code) / dimmed (code)",
     notes="Ask for the frame across the whole width of the canvas; the TA crops a 4:1 band. The middle must be transparent: the art shows through.")
part("frame", sec, "frm_spine_you", "frm_spine_you.png", "Side edge strip on your banners (outer long edge, away from the objective)", "P1",
     "a long thin horizontal strip: solid teal #2EC4B6 with a slightly darker #1E8C82 lower half and a fine row of small square notches along its top edge, both ends cut at 45 degrees",
     gen="1536x1024", ship="512x16", nine="16,4,16,4", states="normal / dim (code)")
part("frame", sec, "frm_spine_rival", "frm_spine_rival.png", "Side edge strip on rival banners (shape differs from yours for colour-blind players)", "P1",
     "a long thin horizontal strip: solid signal red #E5383B with a darker #8E1F21 lower half and a row of small diamond-shaped notches along its top edge, both ends cut at 45 degrees",
     gen="1536x1024", ship="512x16", nine="16,4,16,4", states="normal / dim (code)")
part("frame", sec, "frm_front_tab", "frm_front_tab.png", "FRONT tab (48x13 phone, 64x15 desktop) on the front-row card; word drawn by code", "P1",
     "a small flat tab shaped like a trapezoid, wider at the bottom, solid fog white #D8DEE3 face with a thin darker outline, plain",
     ship="128x32", nine="12,6,12,6", states="yours (tint teal) / rival (tint red)")
part("frame", sec, "frm_plan_plate", "frm_plan_plate.png", "PLAN tag on your planned cards (inner-edge centre) and PLAN · B on the Operator card", "P1",
     "a small slanted tag plate: a short parallelogram, dark brass #3A2D0B face with a thin brass #C9A227 outline, plain",
     ship="128x40", nine="16,8,16,8", states="normal")
part("frame", sec, "frm_incoming", "frm_incoming.png", "INCOMING face-down rival banner (back pattern, fills the whole 4:1 banner)", "P1",
     "a seamless dark card-back pattern for a very wide card: diagonal hazard-free fine chevron weave in gunmetal #232A31 on slate #12161A, a slightly brighter abstract arrow pattern pointing down repeated evenly, low contrast",
     gen="1536x1024", ship="512x128 (crop a 4:1 band)", alpha="opaque", states="normal / pulse (code)",
     avoid="emblems, a central logo, letters, a skull")
part("frame", sec, "frm_supply_plate", "frm_supply_plate.png", "Operator card '1 SUPPLY' plate in place of the cost hex; red when you can't pay", "P2",
     "a small horizontal brass plate with rounded corners and two tiny rivets at the ends, brass #C9A227 face with darker #5A4512 edges",
     ship="160x48", nine="16,12,16,12", states="normal / can't pay (code tint red)")
part("frame", sec, "frm_socket", "frm_socket.png", "Socket for keyword pip, trait pip, class pip and effect glyph (22 px phone, 26 desktop)", "P1",
     "a small square socket plate with chamfered corners: near-black #0F1316 recessed face, a thin steel #3A444D rim, plain",
     ship="64x64", nine="", states="idle (grey rim) / lit (code tints the rim: keyword accent, trait colour)")
part("frame", sec, "fx_ring_tier3", "fx_ring_tier3.png", "White ring around a trait pip at set tier 3 (banner, rail)", "P2",
     "a single thin bright ring of light, perfectly round, soft glow on both sides, nothing inside",
     ship="64x64", alpha="add", states="normal")

sec = "Level camo bands and Operator mastery ladder"
bandnote = "Tileable strip. Generate a square swatch; the TA cuts a horizontal strip and makes it seamless (offset + clone, or mirror-tile)."
for bid, used, pri, subj in [
    ("band_base", "Operator base camo tier (OPERATOR badge swatch, Operator frame band); optional Recruit swatch in the deck view", "P1",
     "a seamless flat woodland camouflage pattern: rounded blobs of olive #4B5A3A, dark olive #2F3A25 and pale moss #7A8A5A, no other colours"),
    ("band_gold_leaf", "Trained copies (Gold Leaf band under the art and on the outer edge), Operator gold leaf tier", "P1",
     "a seamless pattern of polished gold leaf: the same rounded camouflage blob shapes rendered in bright gold #C9A227, deep gold #7A5E12 and pale gold highlights #F3D36B, a soft metallic sheen"),
    ("band_machined", "Veteran copies (Machined band), Operator machined tier", "P1",
     "a seamless pattern of polished white steel: the same rounded camouflage blob shapes in bright silver #D9DEE3, mid grey steel #7E878F and white highlights, crisp machined metal sheen"),
    ("band_prism", "Elite copies (Prism band), Operator prism tier", "P1",
     "a seamless pattern of deep blue crystal: the same rounded camouflage blob shapes in sapphire blue #3E8EDE, navy #1B3F78 and icy cyan facets #9FE3FF, faceted gem-like sparkle"),
    ("band_starfield", "Operator top mastery tier only", "P2",
     "a seamless pattern of a violet cosmic nebula: the same rounded camouflage blob shapes filled with deep violet #7B3FC4, near-black indigo #1A0F3A and hot pink star specks #FF7AD9, tiny white stars"),
]:
    S.append(dict(id=bid, file=f"{bid}.png", cat="band", sec=sec, gen="1024x1024", ship="512x512 swatch + 512x32 seamless strip",
                  alpha="opaque", nine="tile horizontally", states="normal / shimmer (banner_shimmer shader on animated finishes)",
                  used=used, pri=pri, subj=subj + ", evenly spread over the whole square with no centre focus, flat front-on.", avoid="", notes=bandnote))
part("frame", sec, "frm_band_edge", "frm_band_edge.png", "Thin metal edge that caps a camo band strip top and bottom", "P2",
     "a long very thin horizontal metal trim strip with a tiny bevel, light steel #B9C2C9, both ends square",
     gen="1536x1024", ship="512x8", nine="4,2,4,2", states="normal")

sec = "Elite and Operator frames"
part("frame", sec, "frm_elite", "frm_elite.png", "Elite chassis banner and hand card frame (gold frame + star)", "P2",
     "a very wide thin picture frame like frm_banner but in brushed gold #C9A227 with darker #7A5E12 edges, small chamfers, a tiny plain gold rivet in each corner, the inside completely empty",
     gen="1536x1024", ship="512x128", nine="16,16,16,16", states="normal / selected (fx_outline_teal)")
part("frame", sec, "frm_operator_banner", "frm_operator_banner.png", "The Operator's banner on the board (brass frame, camo band on the outer edge, dog-tag plate)", "P1",
     "a very wide thin picture frame in polished brass #C9A227 with dark brass #5A4512 edges, rounded dog-tag style corners instead of chamfers, a tiny round hole near the left end of the top edge like a tag, the inside completely empty",
     gen="1536x1024", ship="512x128", nine="24,16,24,16", states="normal / selected / now firing / downed (code dim)")
part("frame", sec, "frm_operator_card", "frm_operator_card.png", "Operator card pinned first in the tray (99x124 phone, 108x136 desktop)", "P1",
     "an upright card frame shaped like a big military dog tag: polished brass #C9A227 border with dark brass #3A2D0B fill, fully rounded corners, a round hole near the top centre with a short ball chain, a recessed window in the upper 60% for the art, a plain lower area",
     gen="1024x1536", ship="256x320", nine="32,72,32,48", states="normal / can deploy (fx_glow_amber) / selected (teal border: fx_outline_teal) / can't pay (code red plate) / down (code dim)",
     avoid="engraved letters or numbers on the tag")
part("frame", sec, "frm_operator_mini", "frm_operator_mini.png", "Mini Operator card (half height, ON BOARD / C · ROW 1) while the Operator is on the board", "P1",
     "a wide short dog-tag plate: polished brass border, dark brass fill, fully rounded corners, a round hole at the left end, plain recessed face",
     gen="1536x1024", ship="256x160", nine="40,24,24,24", states="normal / selected (fx_outline_teal)")
part("frame", sec, "frm_dogtag_plate", "frm_dogtag_plate.png", "Callsign / dog-tag plate on the Operator banner (in place of the effect glyph)", "P2",
     "a tiny horizontal dog tag with rounded ends and a hole at the left end, brushed brass, plain face",
     ship="96x40", nine="", states="normal")

sec = "Hand card, Codex and mulligan"
part("frame", sec, "frm_hand_card", "frm_hand_card.png", "Hand banner card frame in the tray (kc-ui4 board-form: 177x73 phone, 224x64 desktop, 103x78 on 16:9), mulligan cards, Supply Drop picks", "P1",
     "a wide card frame about two and a half times wider than tall, in the same steel language as the board banner frame: a 3-pixel dark steel #3A444D border with a lighter top-left bevel, small 45-degree chamfers at three corners, a hexagon-shaped notch cut into the top-left corner (for the cost hex), the inside completely empty so the art shows through",
     gen="1536x1024", ship="448x184", nine="56,40,20,20", states="normal / selected (14 px shift + fx_outline_teal) / unplayable (code dim) / NEXT DEPLOY peek (code dim) / set-tier dot (code)",
     notes="kc-ui4 (in progress) makes hand cards banner cards (BannerCard.build) between 1.3:1 and 2.4:1; the 9-slice keeps the cost notch in the left margin, so one frame fits every cell.")
part("frame", sec, "frm_hand_name", "frm_hand_name.png", "Name band across the middle of a narrow hand banner card (16:9 phones), stats row", "P2",
     "a long low bar plate, near-black face, a thin steel top edge line, both ends square",
     gen="1536x1024", ship="256x48", nine="12,8,12,8", states="normal")
part("frame", sec, "frm_codex_tile", "frm_codex_tile.png", "Codex tile (120x156 compact): art, cost hex, name, chassis line", "P2",
     "an upright collectible tile frame: dark gunmetal border with a thin steel outline, a hexagon-shaped notch cut into the top-left corner for the cost plate, a chamfered bottom-right corner, an art window in the upper 55%, a slightly lighter lower plate for two lines of caption",
     gen="1024x1536", ship="240x312", nine="32,32,32,72", states="normal / hover (+10%) / pressed / locked (overlay ico_ui_lock + code dim) / equipped (frm_equipped)")
part("frame", sec, "frm_equipped", "frm_equipped.png", "FOUND / EQUIPPED corner mark on Codex tiles (word drawn by code); kc-trait-ui removed EQUIP, so it now marks FOUND arts", "P3",
     "a corner ribbon that wraps the top-right corner of a card diagonally: a solid brass #C9A227 band with darker edges and a tiny dog-tag shape hanging from it, plain, the rest transparent",
     ship="128x128", states="normal")
part("frame", sec, "frm_put_back", "frm_put_back.png", "Mulligan PUT BACK plate on marked cards (word drawn by code)", "P1",
     "a diagonal band laid across a card from lower left to upper right: semi-transparent dark red #5A1A1C at 85% with thin bright red #E5383B edges and short hazard ticks at both ends, nothing else",
     ship="256x320", states="normal")

sec = "Glows, outlines, links and previews (additive overlays)"
part("fx", sec, "fx_outline_teal", "fx_outline_teal.png", "Selected card / badge outline (teal), valid-target slot", "P1",
     "a thin rectangular outline of bright teal #2EC4B6 light with small chamfered corners and a soft glow spreading 12 pixels inside and outside the line, nothing in the middle",
     gen="1536x1024", ship="512x160", alpha="add", nine="32,32,32,32", states="normal / pulse (code alpha)")
part("fx", sec, "fx_outline_side", "fx_outline_side.png", "Now-firing outline in the owner's colour (tinted teal / red), lift on shot", "P1",
     "a thin rectangular outline of pure white light with small chamfered corners and a soft glow spreading 12 pixels inside and outside the line, nothing in the middle",
     gen="1536x1024", ship="512x160", alpha="add", nine="32,32,32,32", states="tinted teal / red")
part("fx", sec, "fx_glow_amber", "fx_glow_amber.png", "Ready glow: killstreak tile READY, Operator DEPLOY, READY button pulse, order node current", "P1",
     "a soft rounded-square halo of warm amber #FFB020 light, brightest at the edge of an empty dark square centre and fading out smoothly, nothing solid",
     ship="256x256", alpha="add", nine="64,64,64,64", states="pulse (code alpha 0.4 -> 1.0)")
part("fx", sec, "fx_glow_red", "fx_glow_red.png", "Overrun risk pulse, can't-pay flash, set OFF", "P2",
     "a soft rounded-square halo of red #E5383B light, brightest at the edge of an empty dark square centre and fading smoothly outward, nothing solid",
     ship="256x256", alpha="add", nine="64,64,64,64", states="pulse")
part("fx", sec, "fx_link_tick", "fx_link_tick.png", "Link ticks: vertical (Guard, Spotter) across the row gap, horizontal (Fireteam, Overwatch) across the gutter; tinted by owner", "P1",
     "a single short vertical bar of pure white light with rounded ends and a soft glow around it, brightest in the core",
     ship="32x64", alpha="add", states="active (tint side colour) / ghost (fx_link_tick_ghost) / break flash (code)",
     notes="Rotate 90 degrees in code for the horizontal ticks.")
part("fx", sec, "fx_link_tick_ghost", "fx_link_tick_ghost.png", "Dashed amber ghost ticks for links a placement would make", "P2",
     "a short vertical dashed bar of three dashes of soft warm amber light, rounded ends, gentle glow",
     ship="32x64", alpha="add", states="normal")
part("fx", sec, "frm_ghost", "frm_ghost.png", "Ghost / placement preview frame in each valid column (PLAY HERE)", "P1",
     "a very wide thin rectangular frame drawn as an even dashed line of fog white #D8DEE3 with small corner brackets, the inside completely empty",
     gen="1536x1024", ship="512x128", nine="20,20,20,20", states="normal (code tint amber) / protector (TAKES THE FRONT) / invalid (dim)")
part("fx", sec, "fx_hit_flash", "fx_hit_flash.png", "Hit flash on a banner when damage lands", "P2",
     "a short horizontal burst of white-hot light: a bright core with streaks to the left and right fading out, soft",
     gen="1536x1024", ship="512x128", alpha="add", states="normal (tinted by damage type)")
part("fx", sec, "fx_tracer", "fx_tracer.png", "Tracer line from shooter to target (stretched along the path), Pick / Flank curve, Pierce through", "P2",
     "a single long thin horizontal streak of warm white light, brightest at the right end and fading to nothing on the left, soft glow",
     gen="1536x1024", ship="256x16", alpha="add", states="tinted by side")
part("fx", sec, "fx_crack", "fx_crack.png", "Red crack for 2 s when a set switches off (trait rail chip), banner break", "P3",
     "a thin jagged crack line running diagonally with two short branches, pure white",
     ship="128x128", alpha="luma", states="tint red")
part("fx", sec, "fx_sheen", "fx_sheen.png", "Frame sheen sweep on animated finishes and hover", "P3",
     "a single soft diagonal band of white light, wide and faint, fading at both sides",
     ship="256x256", alpha="add", states="sweep (code moves it)")

sec = "Card backs"
part("frame", sec, "card_back_banner", "card_back_banner.png", "Face-down KillingCard back (4:1): deck pile, deal animation, rival hand, INCOMING alternative", "P2",
     "a very wide card back design: dark gunmetal laminated texture, a centred abstract mark of three short amber chevrons pointing right inside a thin long hexagon outline, faint topographic contour lines, symmetrical, worn edges",
     gen="1536x1024", ship="512x128 (crop a 4:1 band)", alpha="opaque", states="normal",
     avoid="letters, a logo, a skull, wings, stars, eagles, any badge or unit-crest look")
part("frame", sec, "card_back_hand", "card_back_hand.png", "Face-down hand-size back (deck view, mulligan replacements)", "P3",
     "the same card back design as before on an upright card: dark gunmetal laminated texture, three short amber chevrons pointing up inside a thin tall hexagon outline, faint contour lines, symmetrical",
     gen="1024x1536", ship="256x320", alpha="opaque", states="normal",
     notes="Replaces the Killstreak-era card_back.webp.")

# ---------------------------------------------------------------- priority pass (keep P1 to what a normal match and the first run show)
_DEMOTE = {"type_killstreak", "type_operator", "ui_codex", "ui_info", "eq_frag", "eq_flash", "band_machined", "band_prism",
           "pnl_tooltip", "pnl_order_strip", "order_node", "order_arrow"}
_NEW_HOOK = {"pnl_order_strip": "NEW: the A > B > C order strip (firefight-order.md section 8) is not built yet.",
             "order_node": "NEW: for the order strip (not built yet).", "order_arrow": "NEW: for the order strip (not built yet).",
             "fired": "NEW: the fired pip is a firefight-order.md UI need, not built yet.",
             "frm_equipped": "NEW: the Codex has no EQUIPPED state yet; needs a small hook in codex_view.gd.",
             "card_back_banner": "NEW: no face-down 4:1 back in code yet (INCOMING is drawn).",
             "ui_sound_on": "NEW: there is no sound setting yet.", "ui_sound_off": "NEW: there is no sound setting yet."}
for _s in S:
    if _s["id"] in _DEMOTE:
        _s["pri"] = "P2"
    if _s["id"] in _NEW_HOOK:
        _s["notes"] = (_s.get("notes", "") + " " + _NEW_HOOK[_s["id"]]).strip()


# ---------------------------------------------------------------- number plates (head, kc-ui-art follow-up): icon with the number inside
sec = "Number plates (the game prints the number inside)"
platenote = ("One shape per concept everywhere: the plate is the same silhouette as the concept's icon. "
             "TA: the rim ships as `plate_<x>_<s|l>.png`; a filled copy (`_fill`) is made by flood-filling the inside, so the code can draw a dark tinted fill under the number and a bright tinted rim on top.")
for size, ship, used_at, rim in (("s", "128x128", "22-34 px: board banners, hand banner cards, Codex tiles", "very thick rim, about one sixth of the plate width"),
                                 ("l", "256x256", "48-128 px: inspector, reward and pick tiles, Operator flyout, After-Action", "thick rim, about one tenth of the plate width, with one thin inner line just inside it")):
    tag = "small" if size == "s" else "large"
    S.append(dict(id=f"plate_fp_{size}", file=f"plate_fp_{size}.png", cat="plate", sec=sec, gen="1024x1024", ship=ship, alpha="luma", nine="",
                  states="you (rim teal, fill #14524D) / rival (rim red, fill #5A1A1C) / buffed (number green + up marker) / lowered (red + down marker)",
                  used=f"Firepower number plate, bottom right of every card, left of Armor ({tag}: {used_at})", pri="P1",
                  subj=f"a firepower number plate shaped like a gun-sight ring: a {rim}, broken by four short square gaps at top, bottom, left and right, the centre completely empty and large enough for a two-digit number (at least 55% of the plate width)",
                  avoid="a centre dot, a cross, any number, a second ring", notes=platenote))
    S.append(dict(id=f"plate_armor_{size}", file=f"plate_armor_{size}.png", cat="plate", sec=sec, gen="1024x1024", ship=ship, alpha="luma", nine="",
                  states="normal (rim light steel, fill #2E3439) / damaged (rim amber #F2A33A, fill #4A3412) / healed (flash)",
                  used=f"Armor number plate, bottom right of every card, right of FP ({tag}: {used_at})", pri="P1",
                  subj=f"an armor number plate: a plate shape with a flat top and sides tapering to a rounded point at the bottom, drawn as a {rim}, the inside completely empty and large enough for a two-digit number (at least 55% of the plate width), roughly as wide as it is tall",
                  avoid="a cross, a crest, a star, any mark or number inside", notes=platenote))
    S.append(dict(id=f"plate_cost_{size}", file=f"plate_cost_{size}.png", cat="plate", sec=sec, gen="1024x1024", ship=ship, alpha="luma", nine="",
                  states="affordable (fill amber #FFB020, number slate) / can't pay (fill grey, rim red) / Operator (frm_supply_plate instead)",
                  used=f"Cost plate, top left of every card ({tag}: {used_at}); the hexagon is the Supply shape everywhere (pips, Supply row)", pri="P1",
                  subj=f"a cost number plate: an upright hexagon drawn as a {rim}, the inside completely empty and large enough for a two-digit number",
                  avoid="a number, a crate, a second hexagon",
                  notes=platenote + " Replaces frm_cost_hex (which baked the amber in)."))
    S.append(dict(id=f"plate_cover_{size}", file=f"plate_cover_{size}.png", cat="plate", sec=sec, gen="1024x1024", ship=ship, alpha="luma", nine="",
                  states="normal (rim light steel) / buffed (rim green #7CF29A)",
                  used=f"Cover number plate, bottom right, left of FP, only when Cover > 0 ({tag}: {used_at})", pri="P1" if size == "s" else "P2",
                  subj=f"a cover number plate shaped like a low concrete barrier block seen from the front: a wide trapezoid, wider at the bottom with a flat top, drawn as a {rim}, the inside completely empty and large enough for a one-digit number, compact (no wider than one and a half times its height)",
                  avoid="a number, an arc or arrow, cracks", notes=platenote + " Optional: Cover can stay a small icon chip if the bottom-right corner gets crowded on the 57 px phone banner."))


# ---------------------------------------------------------------- Standard Issue starter (onboarding-progression.md, head-approved): batch 3
sec = "Standard Issue card art (starter, our own art)"
SI_NOTE = ("Standard Issue starter art (onboarding-progression.md section 2.2): deliberately plain, so the first calling card pops. "
           "Banner pipeline: the curator sets banner_y / portrait_x, the TA ships the 1152x768 master and a data/banners/<id>.tres.")
for sid, card, used, subj in [
    ("si_grunt", "Grunt (cost 1, 2/2)", "Grunt x5 in the starter, TrainingBot and the M1 / M2 Standard Issue squads",
     "a basic infantry soldier in a plain round helmet and simple fatigues standing at ease, a generic rifle held diagonally across the chest, three-quarter side view, two plain wooden supply crates stacked behind"),
    ("si_trooper", "Trooper (cost 2, 2/3)", "Trooper x6 in the starter, Standard Issue squads",
     "a soldier in a plain helmet and a simple padded vest walking forward mid-stride, a generic rifle held low in both hands, side view, a plain canvas tent wall behind"),
    ("si_sergeant", "Sergeant (cost 3, 3/3)", "Sergeant x4 in the starter, Standard Issue squads",
     "a soldier in a plain helmet with one arm stretched forward pointing the way, a generic rifle in the other hand, side view, one boot up on a low wooden crate, a plain canvas backdrop"),
    ("si_armored", "Armored Trooper (cost 4, 2/5)", "Armored Trooper x3 in the starter (the first card to send home), Standard Issue squads",
     "a heavy soldier in bulky plain body armour and a full helmet with a dark visor, standing square and slow, a generic rifle held low, front three-quarter view, a low wall of plain sandbags behind"),
    ("si_ammo_resupply", "Ammo Resupply (tactic, Draw 2)", "Ammo Resupply x2 in the starter (Standard Issue art for the existing card)",
     "two plain ammunition boxes and a canvas bag of rifle magazines on a wooden pallet, one gloved hand lifting a box lid, no person in view beyond the hand and forearm, side view"),
]:
    S.append(dict(id=sid, file=f"kc_b_{sid}.png", cat="card_art", sec=sec, gen="1536x1024",
                  ship="1152x768 master (banner band 1152x288, hand column 512x768)", alpha="opaque", nine="",
                  states="normal (no animation, no foil)", used=f"{card}: {used}", pri="P1", subj=subj, batch3=True,
                  avoid="markings or stencils on crates, boxes or gear, glow, light beams, dramatic lighting, a second figure",
                  notes=SI_NOTE + (" Tactic: no character is the subject (kind rule)." if sid == "si_ammo_resupply" else "")))

sec = "Standard Issue frame and plates"
part("frame", sec, "frm_standard_issue", "frm_standard_issue.png", "Standard Issue frame on every Standard Issue card: board banners, hand banner cards, mulligan, Muster out list (no camo band, no foil)", "P1",
     "a very wide thin card frame, four times wider than tall, made of matte grey-green #5E6B5A painted sheet steel with slightly worn flat paint: a 4-pixel border, a hexagon-shaped notch cut into the top-left corner (for the cost plate), square plain corners elsewhere, one small flat-head screw in each of the other three corners, no shine, no foil, the inside completely empty",
     gen="1536x1024", ship="512x128", nine="40,32,16,16", states="normal / selected (fx_outline_teal) / now firing (fx_outline_side) / dimmed (code)",
     notes="Same 9-slice margins as frm_banner, so every anatomy slot lines up; the same image frames the hand banner card. The stencil-style NAME is code text (needs a stencil font: question 5).")
part("frame", sec, "frm_serial_plate", "frm_serial_plate.png", "Serial plate SI-01 to SI-04 (code text) in the empty abilities slot, top right; red-tinted on enemy Standard Issue squads", "P1",
     "a small rectangular stamped metal tag with a slightly raised rim and one round rivet at each end, flat light grey steel #B9C2C9, the face plain and empty",
     ship="128x48", nine="16,12,16,12", states="yours (normal) / enemy squad (code tint red #E5383B)")
S.append(dict(id="frm_socket_empty", file="frm_socket_empty.png", cat="frame", sec=sec, gen="1024x1024", ship="64x64", alpha="luma", nine="",
              states="normal (code tint grey #7E8890 at 60%)", used="Empty trait / weapon slot, bottom left (Standard Issue cards; NO TRAIT arts in the Codex)", pri="P1",
              subj="a small square socket outline with 45-degree chamfered corners drawn as a dashed rim of eight thick dashes, the inside completely empty",
              avoid="a solid rim, anything inside the square", notes="", batch3=True))
S.append(dict(id="frm_socket_locked", file="frm_socket_locked.png", cat="frame", sec=sec, gen="1024x1024", ship="64x64", alpha="luma", nine="",
              states="locked (code: socket grey, keyword icon tinted #7E8890 at 45%, this overlay on top) / unlocks (overlay fades, socket lights, New: Keywords)",
              used="Locked keyword pip on Recruit calling cards (the 'Trains: First Shot - Guard' teaser) and in the inspector", pri="P1",
              subj="a small square socket rim with 45-degree chamfered corners and a compact solid padlock shape sitting over its bottom-right corner, the padlock about one third of the socket's width, the inside of the socket empty",
              avoid="a keyword symbol inside, a keyhole too small to see", notes="The keyword icon itself is drawn inside by the code, greyed.", batch3=True))

sec = "First-time explainer (New: X)"
part("panel", sec, "pnl_new_card", "pnl_new_card.png", "'New: X' one-time explainer card (half screen: icon, one sentence, mini example, GOT IT), queued one per screen", "P1",
     "a large explainer card panel: dark gunmetal #232A31 face with a soft lighter centre, a 2-pixel steel #4A535B outline, 45-degree chamfered corners, a short solid amber #FFB020 flag tab hanging from the top-left corner (plain, for a word the game adds), a thin amber line running along the top edge from the tab",
     gen="1536x1024", ship="512x320", nine="96,48,40,40", states="normal / enter (code: slide + fade)",
     notes="The tab sits inside the left and top 9-slice margins. GOT IT uses btn_primary.")
part("panel", sec, "pnl_new_inset", "pnl_new_inset.png", "Mini example well inside the New: card (a mini board grid, a card, a trait counter)", "P1",
     "a recessed rectangular well: near-black #0F1316 face sunk into the metal, a thin dark inner shadow along the top and left edges and a 1-pixel light steel line along the bottom and right edges, small chamfered corners",
     gen="1536x1024", ship="256x160", nine="20,20,20,20", states="normal")

for _s in S:
    if _s["id"] in ("frm_standard_issue", "frm_serial_plate", "pnl_new_card", "pnl_new_inset", "ui_lock"):
        _s["batch3"] = True
    if _s["id"] == "ui_lock":
        _s["pri"] = "P1"
        _s["used"] = "Locked keyword pip badge (frm_socket_locked), locked Codex art, NOT FOUND YET"
    if _s["id"] == "frm_equipped":
        _s["notes"] = "kc-trait-ui (head B): no EQUIP in runs; the Codex shows FOUND marks instead, so this is optional polish."


# =============================================================================================
# kc-ui-art2 (Sr Game Artist, 2026-11-06): re-based on the card design now in the game
# (kc-cards-impl: C1+ board card, Y2+ card with the T1 orders frame, H1 hand, O2 Operator card;
# documentation/ux/board-layout-v2.md "Implementation notes (kc-cards-impl)" and
# documentation/ux/card-design-options.html). Every slot gets:
#   status   "imported (batch 1)" / "active" / "revised (kc-ui-art2)" / "new (kc-ui-art2)" / "RETIRED: <reason>"
#   code     the id the code asks UiKit / IconSheet for, and whether that lookup exists today
#   fallback whether the code-drawn version is good enough without the image
#   batch    the batch it is generated in (section 5)
# Rows are never deleted: retired slots stay in the manifest with their reason.
# =============================================================================================

IMPORTED = {"stat_firepower", "stat_armor", "stat_cover", "stat_supply", "stat_deck", "stat_intel", "streak", "score",
            "kw_first_shot", "kw_pick"}

RETIRED = {}
for _id in ("plate_fp_s", "plate_fp_l"):
    RETIRED[_id] = ("C1+ / Y2+ draw FP as the reticle ring in team colour (CardLook.draw_reticle); the optional painted "
                    "finish is plate_fp_reticle.")
for _id in ("plate_armor_s", "plate_armor_l"):
    RETIRED[_id] = ("Armor is now the grey ballistic plate with clipped top corners (CardLook.draw_armor), not the pointed "
                    "plate; the optional painted finish is plate_armor_ballistic.")
for _id in ("plate_cost_s", "plate_cost_l"):
    RETIRED[_id] = "The cost hex is drawn in code (CardLook.draw_cost: amber, red when you can't pay); no frame notch to sit in any more."
for _id in ("plate_cover_s", "plate_cover_l"):
    RETIRED[_id] = "Cover stays the small chip with the stat_cover icon left of FP (banner_view._draw_cover_chip); no Cover number plate."
RETIRED.update({
    "frm_serial_plate": "No serial plate on cards any more (kc-cards-impl: the Standard Issue frame says it, the inspector names it).",
    "frm_spine_you": "C1+ has no side spine (the side is told by the board half and the FP reticle colour).",
    "frm_spine_rival": "C1+ has no side spine (the side is told by the board half and the FP reticle colour).",
    "eq_frag": "Frag / flashbang Operator equipment is gone from the game.",
    "eq_flash": "Frag / flashbang Operator equipment is gone from the game.",
    "class_sidearm": "The sidearm / Operator secondary is gone from the game.",
    "kw_pick": ("Imported in batch 1, but Pick is no longer a crosshair (it clashed with the FP reticle). IconSheet now asks "
                "for kw_pick_v2 (a shield with a down arrow) and never loads ico_kw_pick.png; the file can be removed."),
    "frm_banner": ("C1+ shows the full calling-card art with only a thin code keyline, so the steel frame with a cost-hex notch "
                   "has nothing left to frame."),
    "frm_socket": "Trait chips are code-drawn squares (faint 45% / lit with a glow) and abilities sit on one dark code chip; no per-pip socket.",
    "fx_ring_tier3": "Trait chips only have two states now (faint / lit); there is no tier-3 ring.",
    "frm_band_edge": "Cards no longer carry a camo / level band (the level is the level coin), so nothing caps a band strip.",
    "frm_operator_banner": "The Operator's board banner is the C1+ card with a brass code keyline and the dog tag; no brass frame or camo band.",
    "frm_operator_card": "O2 replaced the dog-tag card: the Operator card is the Y2+ brass card (frm_y2_operator) with an OPERATOR tag.",
    "frm_operator_mini": "The half-height mini Operator card is gone (O2 keeps one Operator card bottom-left of the tray).",
    "frm_supply_plate": "The Operator card uses the standard cost hex, red when you are short of Supply.",
    "frm_elite": "Elite is a brass keyline on the board (code) and a gold rim on the Y2+ card; no separate frame image.",
    "frm_hand_card": "The X1 hand card is the C1+ banner (full art) plus a code name plate; no notched hand frame.",
    "frm_hand_name": "The X1 name plate is code (26 px, the one title style).",
    "frm_codex_tile": "The Codex shows Y2+ cards (frm_y2_unit / frm_y2_operator / frm_t1_orders).",
    "frm_equipped": "Codex tiles are Y2+ cards now (NOT FOUND YET veil in code); there is no EQUIPPED / FOUND corner mark.",
})

# Old slots the new design keeps but uses differently.
_DEMOTE3 = {"band_base": "Cards no longer show a level band (the level coin replaced it). Only the run-screen level swatches use bands, and those are drawn in code (SynergyGlyphs.draw_band).",
            "band_gold_leaf": "Cards no longer show a level band (the level coin replaced it). Only the run-screen level swatches use bands (SynergyGlyphs.draw_band).",
            "band_machined": "As band_gold_leaf.", "band_prism": "As band_gold_leaf.", "band_starfield": "As band_gold_leaf.",
            "frm_socket_empty": "Still drawn by StandardIssueLook.draw_empty_socket in the reward screen; the C1+ board shows nothing in an empty trait slot."}
_REUSE = {
    "class_ar": "Cards show the weapon as a text pill now; class icons remain for the killfeed source icon, the art fallback and the Codex filters.",
    "class_smg": "As class_ar.", "class_shotgun": "As class_ar.", "class_sniper": "As class_ar.", "class_lmg": "As class_ar.",
    "stat_firepower": "Imported (batch 1). Its broken ring matches the new reticle; used by the tray mini stats and the killfeed.",
    "stat_armor": "Imported (batch 1). Used by the tray mini stats; its pointed plate differs a little from the new clipped-corner plate (fine at 14 px; redo as stat_armor_v2 only if the head wants it to match).",
}
for _s in S:
    if _s["id"] in _DEMOTE3:
        _s["pri"] = "P3"
        _s["notes"] = (_s.get("notes", "") + " kc-ui-art2: " + _DEMOTE3[_s["id"]]).strip()
    if _s["id"] in ("class_ar", "class_smg", "class_shotgun", "class_sniper", "class_lmg"):
        _s["pri"] = "P2"
    if _s["id"] in _REUSE:
        _s["notes"] = (_s.get("notes", "") + " kc-ui-art2: " + _REUSE[_s["id"]]).strip()
    if _s["id"] == "frm_standard_issue":
        # kc-cards-impl keeps the Standard Issue frame, but the cost is no longer in a frame notch.
        _s["subj"] = ("a very wide thin card frame, four times wider than tall, made of matte grey-green #5E6B5A painted sheet steel "
                      "with slightly worn flat paint: an even 4-pixel border, small square corners, one small flat-head screw in each "
                      "of the four corners, no shine, no foil, the inside completely empty")
        _s["nine"] = "16,16,16,16"
        _s["used"] = "Standard Issue board card (C1+, full art inside it), the X1 hand card and the New: explainers (no camo band, no foil, no serial plate)"
        _s["notes"] = ("kc-ui-art2: revised, the hexagon notch is gone (the cost now sits in the peek chip). Code: ui_kit.gd PIECE_MARGINS "
                       "still says 40,32,16,16 for it; change to 16,16,16,16.")
    if _s["id"] == "pnl_rail_chip":
        _s["states"] = _s["states"].replace(" / ring tier 3 (fx_ring_tier3)", "")
    if _s["id"] == "frm_socket_locked":
        _s["used"] = "Recruit padlock in the top-right abilities chip on C1+ cards (StandardIssueLook.draw_locked_keyword) and the Y2+ text box"
    if _s["cat"] == "card_art":
        _s["notes"] = (_s.get("notes", "") + " kc-ui-art2: still valid; on C1+ the art is never dimmed or cropped, and Y2+ shows the same 4:1 band.").strip()

# ---------------------------------------------------------------- new slots (kc-ui-art2)
NEW_IDS = []


def new(cat, sec, id_, file, used, pri, subj, **kw):
    part(cat, sec, id_, file, used, pri, subj, **kw)
    NEW_IDS.append(id_)


icon("Keywords", "kw_pick_v2", "Pick everywhere: C1+ abilities chip, Y2+ text box, glossary, inspector, Pick tracer tag", "P1",
     "a heater shield seen from the front (a flat top edge, straight sides that curve inward to one point at the bottom), drawn as a thick outline, "
     "with one thick arrow inside it pointing straight down, from the upper third of the shield to just above its bottom point, with a wide open arrowhead",
     avoid="a crosshair, a circle, a ring, a reticle, a cross, a star, a crest or any mark on the shield besides the arrow",
     notes="Replaces kw_pick (crosshair). Pick shoots the lowest Armor: the shield is Armor, the arrow is 'the lowest'. Same shape as the built-in glyph (IconSheet.PICK_SVG), so the switch is invisible except for the finish.")
NEW_IDS.append("kw_pick_v2")

sec = "Y2+ card frames and the T1 orders frame"
Y2_NOTE = ("The Y2+ card is laid out at its own width (172 to 330 px, height (W - 8) / 4 + 155; 250x216 in the inspector and the hand dock). "
           "The code draws the title bar, the 4:1 art window, the type line, the text box and the stats bar on top of this frame, so the face must be plain. "
           "Shipped at 2x (500x432) and drawn at 0.5 scale.")
new("frame", sec, "frm_y2_unit", "frm_y2_unit.png",
    "Every unit, Field and killstreak card off the board (Y2+): mulligan, Supply Drop / Salvage / Muster out picks, Codex grid, deck lists, inspector, hand dock", "P1",
    "an upright playing-card frame a little wider than it is tall (about 7 to 6): a 3-pixel steel #4A5560 rim with small softly rounded corners (rounded, not chamfered), "
    "one soft top-left bevel highlight on the rim, and a dark gunmetal #1B2126 face filling the whole inside, flat and even with a very faint brushed grain, "
    "the face completely plain",
    gen="1024x1024", ship="500x432", nine="24,24,24,24",
    states="normal / marked or selected (code: amber rim glow) / killstreak (code tints the rim cyan #5BC0EB) / Elite (code gold rim, or frm_y2_operator) / not found (code veil over the art)",
    avoid="45-degree chamfered corners, a window, a title bar or any inner panel drawn in, a notch, rivets in the middle of an edge",
    notes=Y2_NOTE)
new("frame", sec, "frm_y2_operator", "frm_y2_operator.png",
    "The Operator's Y2+ card and the O2 Operator card bottom-left of the tray (OPERATOR tag, cost hex, state chip drawn by code)", "P1",
    "an upright playing-card frame a little wider than it is tall (about 7 to 6): a 3-pixel polished brass #C9A227 rim with small softly rounded corners (rounded, not chamfered), "
    "one soft top-left highlight on the rim, and a very dark brass-brown #1E1A10 face filling the whole inside, flat and even with a faint fine brushed grain, "
    "the face completely plain",
    gen="1024x1024", ship="500x432", nine="24,24,24,24",
    states="normal / can deploy (code: amber glow) / planned / on board / down (code dim) / need Supply (code: red cost hex)",
    avoid="45-degree chamfered corners, a dog-tag shape, a chain or hole, ornaments, engraving, a window drawn in",
    notes=Y2_NOTE + " The O2 tray card (hand_area._make_operator_card) can use the same 9-slice.")
new("frame", sec, "frm_y2_standard_issue", "frm_y2_standard_issue.png",
    "Standard Issue cards off the board (Y2+): starter list, mulligan, Muster out, Codex", "P1",
    "an upright playing-card frame a little wider than it is tall (about 7 to 6): a 3-pixel rim of matte grey-green #5E6B5A painted sheet steel with "
    "slightly worn flat paint and small softly rounded corners (rounded, not chamfered), one tiny flat-head screw in each corner, and a dark #1B2126 face filling the whole inside, "
    "flat and plain, no shine, no foil",
    gen="1024x1024", ship="500x432", nine="24,24,24,24",
    states="normal / marked (code amber rim)",
    avoid="45-degree chamfered corners, stencils, serial numbers, a window drawn in, rivets in the middle of an edge",
    notes=Y2_NOTE + " Same paint as frm_standard_issue (the board card), so a Standard Issue card reads the same everywhere.")
new("frame", sec, "frm_t1_orders", "frm_t1_orders.png",
    "Every Tactic card off the board (Y2+ with the T1 orders frame): mulligan, rewards, Codex, inspector, hand dock", "P1",
    "an upright field-orders sheet shaped like a playing card a little wider than it is tall (about 7 to 6): a 3-pixel khaki #B8913A rim, "
    "the top-right corner cut off by one straight 45-degree cut about one fourteenth of the width, the other three corners slightly rounded, "
    "a dark olive-brown #2B2716 face with a faint matte paper fibre grain, and a slightly lighter khaki-tinted strip running along the whole top edge "
    "for the top seventh of the height; matte paper, not metal",
    gen="1024x1024", ship="500x432", nine="24,64,48,24",
    states="normal / marked (code amber rim) / not found (code veil over the art)",
    avoid="writing, stamps, a seal, folds, coffee stains, a second cut corner, a curled page, rivets",
    notes=Y2_NOTE + " The chevron cut (18 px at 1x) sits inside the top-right 9-slice corner; the khaki strip sits inside the top margin, so it stretches cleanly. No stats bar on Tactics: the text box takes its room.")
new("frame", sec, "tex_orders_paper", "tex_orders_paper.png",
    "Paper grain tiled over the T1 face and text box (about 60% opacity), so the orders frame reads as paper at any card width", "P2",
    "a seamless tileable texture of dark olive-brown #2B2716 field-order paper: a faint fibre grain and very soft mottling, low contrast, even all over, "
    "no folds, no stains, no edges, no writing",
    gen="1024x1024", ship="256x256 tile", alpha="opaque", nine="tiles in both directions",
    states="one state (code: draw tiled with texture_repeat, 60% alpha)",
    avoid="text, stamps, creases, a border, a visible seam, bright spots",
    notes="Code fallback (flat colour) is fine; this only adds the paper feel the 9-slice face can't keep when it stretches.")

sec = "C1+ board card overlays"
new("fx", sec, "fx_glow_rail", "fx_glow_rail.png",
    "Rail highlight: tap or hover a SETS chip and every matching card glows in the trait colour (board 4:1 cards and X1 hand cards)", "P1",
    "a soft white glow around an empty, very wide rectangle four times wider than tall: a bright thin white line traces the rectangle with slightly rounded corners, "
    "and a smooth soft white halo fades outward from it, the inside of the rectangle staying black",
    gen="1536x1024", ship="576x192", alpha="add", nine="48,48,48,48",
    states="tinted by the trait colour (code) / optional slow pulse (code alpha)",
    avoid="colour, an object or frame, sparkles, noise, a glow that fills the inside",
    notes="TA: process as luma (brightness to alpha) rather than additive, so banner_view can draw it with a normal blend and tint it per trait. Ask for the glow across the whole canvas width; crop a 4:1 band with 32 px of halo on each side.")
new("fx", sec, "fx_crack_damage", "fx_crack_damage.png",
    "Damaged card: the corner crack, top-left, on C1+ board cards and hand cards (with the code's amber bottom edge)", "P2",
    "a small jagged crack that starts exactly at the top-left corner and runs down and to the right in four sharp zig-zag bends, with one short branch splitting off to the right near the top, every line thick",
    gen="1024x1024", ship="64x64", alpha="luma",
    states="damaged (code: a dark copy 1 px wider underneath, then this tinted amber #F2A33A) / healed (hidden)",
    avoid="glass shards, a shattered pane, more than one branch, hairline cracks, a frame or corner bracket",
    notes="Code fallback (CardLook.draw_crack, five-point polyline) is acceptable; the image gives a hand-drawn, less mechanical crack.")

sec = "C1+ stat badges (optional painted finish)"
STAT_NOTE = ("Optional. The code already draws the decided shape (flat colours, the number on top). This image only adds a metal finish. "
             "It is generated neutral steel and the code modulates it, so one image serves both teams and the damaged state.")
new("frame", sec, "plate_fp_reticle", "plate_fp_reticle.png",
    "FP reticle bottom-right of every C1+ card (26 px phone), the Y2+ stats bar (28 px) and the inspector (up to 52 px); the number is code text", "P2",
    "a round gun-sight ring badge for a number: a thick light steel #C9D1D8 metal ring broken by four short square gaps at the top, bottom, left and right, "
    "around a dark #2A3238 recessed disc, the disc plain and empty and at least 70% of the badge width so a two-digit number fits; one soft top-left highlight on the ring",
    gen="1024x1024", ship="128x128",
    states="yours (modulate teal #2EC4B6) / rival (modulate red #FF5A5D) / buffed (code: green number) / lowered (code: red number)",
    avoid="a number, a centre dot, a cross, tick marks, a second ring",
    notes=STAT_NOTE)
new("frame", sec, "plate_armor_ballistic", "plate_armor_ballistic.png",
    "Armor plate right of FP on every C1+ card, the Y2+ stats bar and the inspector; only the number left is shown (code text)", "P2",
    "a ballistic armour plate badge for a number: a rounded rectangle about as wide as it is tall, with its two top corners clipped off at 45 degrees and softly rounded bottom corners, "
    "a thick light steel #C9D1D8 rim and a dark #2A3238 face, the face plain and empty and big enough for a two-digit number; faint brushed grain, one soft top-left highlight",
    gen="1024x1024", ship="128x128",
    states="normal (as is, both sides) / damaged (modulate amber #F2A33A; number #FFC067 in code)",
    avoid="a number, a crest, a cross, a star, rivets, a pointed bottom, straps",
    notes=STAT_NOTE + " Never red when damaged: red means the rival.")
new("frame", sec, "coin_level", "coin_level.png",
    "Level coin in the C1+ peek group (17 px) and on the Y2+ type line (16 px): R / T / V / E is code text", "P3",
    "a small round coin badge: a thick light steel #C9D1D8 rim and a dark #14181C face, plain and empty for one letter; one soft top-left highlight",
    gen="1024x1024", ship="64x64",
    states="Recruit R (as is) / Trained, Veteran, Elite (modulate brass #F3D36B)",
    avoid="a letter, a star, laurels, engraving, a ribbon",
    notes="Optional, like the stat badges: at 16-17 px the code coin (CardLook.draw_level_coin) reads the same.")

for _s in S:
    if _s["id"] in ("frm_t1_orders", "tex_orders_paper"):
        _s["style"] = "paper"
    if _s["id"] == "fx_glow_rail":
        _s["alpha_note"] = "glow on black: the TA turns brightness into alpha (white glow, tinted per trait in code)"

# ---------------------------------------------------------------- code ids and hooks
# Kit ids that a UiKit / IconSheet lookup already asks for today (the image shows up as soon as it is imported).
WIRED_ICONS = {"range_close", "range_mid", "range_long", "type_unit", "type_tactic", "type_field", "type_killstreak", "type_operator",
               "class_smg", "class_shotgun", "class_ar", "class_sniper", "class_lmg", "kw_first_shot", "kw_flank", "stat_cover",
               "kw_suppress", "kw_patch", "kw_holder", "trig_on_deploy", "trig_on_down", "stat_firepower", "stat_armor", "streak",
               "stat_supply", "ks_recon_drone", "ks_mortar", "ks_sentry", "ks_attack_helo", "ks_gunship", "stat_intel", "elite_star",
               "eliminated", "stat_deck", "score", "ui_lock"}
WIRED_PIECES = {"frm_standard_issue": "StandardIssueLook.draw_frame", "frm_socket_empty": "StandardIssueLook.draw_empty_socket",
                "frm_socket_locked": "StandardIssueLook.draw_locked_socket", "pnl_new_card": "new_card.gd", "pnl_new_inset": "new_card.gd"}
CODE_HOOK = {
    "kw_pick_v2": "wired: IconSheet.get_icon(&\"kw_pick\") asks UiKit for kw_pick_v2 (glossary, inspector, Y2+ text box). Board: banner_view.gd draws kind &\"kw_pick\" with CardLook.draw_pick_icon directly; change it to UiKit.draw_icon(o, &\"kw_pick_v2\", rr, ...) first",
    "frm_y2_unit": "needs code: CardView._draw() -> UiKit.draw_piece(self, &\"frm_y2_unit\", rect) before its polygons, + PIECE_MARGINS",
    "frm_y2_operator": "needs code: CardView._draw() (operator) and hand_area._make_operator_card -> UiKit.draw_piece(&\"frm_y2_operator\")",
    "frm_y2_standard_issue": "needs code: CardView._draw() (standard_issue) -> UiKit.draw_piece(&\"frm_y2_standard_issue\")",
    "frm_t1_orders": "needs code: CardView._draw() (tactic) -> UiKit.draw_piece(&\"frm_t1_orders\") instead of the outline polygons and the khaki band",
    "tex_orders_paper": "needs code: CardView._draw() (tactic) -> draw UiKit.piece(&\"tex_orders_paper\") tiled over the face at 60% alpha",
    "fx_glow_rail": "needs code: banner_view.gd rail highlight (two draw_rect calls) -> UiKit.draw_piece(o, &\"fx_glow_rail\", r.grow(8 * k), trait colour)",
    "fx_crack_damage": "needs code: CardLook.draw_crack -> UiKit.draw_piece(&\"fx_crack_damage\") (dark copy, then amber)",
    "plate_fp_reticle": "needs code: CardLook.draw_reticle -> UiKit.draw_piece(&\"plate_fp_reticle\", r, team colour), then the number",
    "plate_armor_ballistic": "needs code: CardLook.draw_armor -> UiKit.draw_piece(&\"plate_armor_ballistic\", r, grey or amber), then the number",
    "coin_level": "needs code: CardLook.draw_level_coin -> UiKit.draw_piece(&\"coin_level\", r, steel or brass), then the letter",
}
FALLBACK_OK = {"tex_orders_paper", "fx_crack_damage", "plate_fp_reticle", "plate_armor_ballistic", "coin_level"}
IMAGE_BEATS_CODE = {"frm_y2_unit", "frm_y2_operator", "frm_y2_standard_issue", "frm_t1_orders", "fx_glow_rail", "kw_pick_v2"}

for _s in S:
    i = _s["id"]
    if i in RETIRED:
        _s["status"] = "RETIRED: " + RETIRED[i]
    elif i in NEW_IDS:
        _s["status"] = "new (kc-ui-art2)"
    elif i == "frm_standard_issue":
        _s["status"] = "revised (kc-ui-art2)"
    elif i in IMPORTED:
        _s["status"] = "imported (batch 1)"
    else:
        _s["status"] = "active"
    if _s["cat"] == "card_art":
        _s["code_id"] = _s["file"][:-4]
    elif _s["cat"] == "icon":
        _s["code_id"] = i
    else:
        _s["code_id"] = i
    if i in CODE_HOOK:
        _s["hook"] = CODE_HOOK[i]
    elif i in RETIRED:
        _s["hook"] = "-"
    elif _s["cat"] == "icon" and i in WIRED_ICONS:
        _s["hook"] = "wired: IconSheet.get_icon / UiKit lookup"
    elif _s["cat"] == "background":
        _s["hook"] = "replaces a bitmap (TA swaps the file the screen loads today, or adds the path)"
    elif _s["cat"] == "card_art":
        _s["hook"] = "wired: BannerArtDB (UiKit.piece(&\"%s\"))" % _s["code_id"]
    elif i in WIRED_PIECES:
        _s["hook"] = "wired: UiKit.draw_piece in " + WIRED_PIECES[i]
    else:
        _s["hook"] = "needs code (no UiKit lookup yet)"
    if i in RETIRED:
        _s["fallback"] = "-"
    elif i in IMAGE_BEATS_CODE:
        _s["fallback"] = "code fallback works, but the image clearly beats it"
    elif i in FALLBACK_OK:
        _s["fallback"] = "code fallback is fine (image optional)"
    elif _s["cat"] in ("background", "card_art"):
        _s["fallback"] = "image needed (code has only a placeholder)"
    else:
        _s["fallback"] = "code fallback kept"

# ---------------------------------------------------------------- batch plan (kc-ui-art2), by visual impact
# Batch 1 is imported. Batches 2-5 are hand-picked; the rest are filled by gen.py (P1, then P2, then P3, groups of up to 10).
BATCHES = [
    ("P1", "New card look: Pick icon, Y2+ and T1 frames, rail glow, crack",
     ["kw_pick_v2", "frm_y2_unit", "frm_y2_operator", "frm_t1_orders", "tex_orders_paper", "fx_glow_rail", "fx_crack_damage"]),
    ("P1", "Standard Issue starter: the 5 arts and their frames",
     ["si_grunt", "si_trooper", "si_sergeant", "si_armored", "si_ammo_resupply", "frm_standard_issue", "frm_y2_standard_issue",
      "frm_socket_locked", "ui_lock"]),
    ("P1", "Keyword icons on every card (abilities chip, Y2+ text box)",
     ["kw_flank", "kw_pierce", "kw_suppress", "kw_patch", "kw_protector", "kw_guard", "kw_spotter", "kw_fireteam", "kw_overwatch", "effect_bolt"]),
    ("P1", "Trait chips, the painted stat badges and the New: explainer",
     ["trait_vanguard", "trait_specops", "trait_heavy", "trait_undead", "plate_fp_reticle", "plate_armor_ballistic", "coin_level",
      "pnl_new_card", "pnl_new_inset"]),
]
