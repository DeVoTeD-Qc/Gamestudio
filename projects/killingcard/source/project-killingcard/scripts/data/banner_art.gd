# banner_art.gd
# Purpose: One calling-card banner art (card-system.md §2.1, banner-art-direction.md §3). A banner is
#   ONE master image (3:2, 1536x1024 from ChatGPT, shipped at 1152x768) cut twice:
#   - the 4:1 BANNER band (full width, height = width / 4) centred at banner_y (board, inspector),
#   - the 2:3 HAND column (full height, width = height * 2 / 3) centred at portrait_x (hand card A).
#   Re-centring a crop is a number change here, never a re-export.
#   Display only: the rules never read it. BannerArtDB (scripts/ui/art/banner_art_db.gd) finds the
#   art for a card art id: res://data/banners/<art_id>.tres when the head's art has arrived, else a
#   placeholder made from Killstreak's card art (or a gradient + silhouette).
#   The tag fields of the artist's CSV (style, subject, ...) are not used by the UI yet; they are
#   kept as one Dictionary so the CSV import (card-system.md §4.6) can fill them later.
# Author: Mechanics Developer Agent (kc-board)
class_name BannerArt
extends Resource

## Banner file name without extension (kc_b_marksman_neon), or a card id for placeholders.
@export var id: StringName = &""
## Art title shown in the inspector ("Marksman Neon"), <= 24 characters.
@export var title: String = ""
## Card (chassis) id this art belongs to (art points to chassis, never the other way).
@export var card_id: StringName = &""
## The master image. Leave empty and set image_path for a WebP shipped with the "keep" importer.
@export var texture: Texture2D = null
## res:// path of the master image (decoded at runtime like CardArt's bitmaps), used when texture is null.
@export var image_path: String = ""
## Centre of the 4:1 band, 0..1 of the image height (art direction default 0.47).
@export_range(0.0, 1.0, 0.01) var banner_y: float = 0.47
## Centre of the 2:3 hand column, 0..1 of the image width (default 0.5).
@export_range(0.0, 1.0, 0.01) var portrait_x: float = 0.5
## &"no", &"yes" or &"later" (CSV column). Animation only plays on focus / placement.
@export var animated: StringName = &"no"
@export var is_default: bool = true
@export var artist: String = ""
@export var licence: String = ""
@export var source_note: String = ""
@export var tags: Dictionary = {}
## True for art made by BannerArtDB from older card art / a gradient (shown as such in the inspector).
@export var placeholder: bool = false

## The banner ratio on the board (4:1) and the hand crop ratio (2:3).
const BANNER_RATIO: float = 4.0
const PORTRAIT_RATIO: float = 2.0 / 3.0


## Pixel rect of the 4:1 band inside an image of image_size (clamped inside the image).
func banner_region(image_size: Vector2) -> Rect2:
	return BannerArt.band_rect(image_size, banner_y)


## Pixel rect of the 2:3 hand column inside an image of image_size.
func portrait_region(image_size: Vector2) -> Rect2:
	return BannerArt.column_rect(image_size, portrait_x)


static func band_rect(image_size: Vector2, centre_y: float) -> Rect2:
	var w: float = image_size.x
	var h: float = minf(image_size.y, w / BANNER_RATIO)
	if h < w / BANNER_RATIO:
		# Image wider than 4:1: keep the full height and crop the width around the centre.
		w = h * BANNER_RATIO
	var y: float = clampf(centre_y * image_size.y - h * 0.5, 0.0, image_size.y - h)
	var x: float = (image_size.x - w) * 0.5
	return Rect2(roundf(x), roundf(y), roundf(w), roundf(h))


static func column_rect(image_size: Vector2, centre_x: float) -> Rect2:
	var h: float = image_size.y
	var w: float = minf(image_size.x, h * PORTRAIT_RATIO)
	var x: float = clampf(centre_x * image_size.x - w * 0.5, 0.0, image_size.x - w)
	return Rect2(roundf(x), 0.0, roundf(w), roundf(h))
