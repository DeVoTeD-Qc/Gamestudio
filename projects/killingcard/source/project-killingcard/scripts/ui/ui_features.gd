# ui_features.gd
# Purpose: Switches for UI features that are parked (the code stays, the player never sees them).
#   FORECAST_EYE: the PREVIEW (forecast) eye on the match strip and its outcome overlay (p12,
#   outcome_preview.gd). The studio head (Nov 2026): "I'm not even sure we need that feature at all."
#   While false, in every run and every build (public and pitch): the eye is hidden, the P key does
#   nothing, the "Forecast" concept is not in ConceptRegistry (so it is never explained and the
#   Glossary does not list it). Set it to true to bring the whole feature back as it was.
# Dependencies: none.
# Author: Technical Artist Agent (kc follow-ups)
class_name UiFeatures
extends RefCounted

## The PREVIEW (forecast) eye and its overlay. false = parked (hidden everywhere).
const FORECAST_EYE: bool = false
