extends Node

@export_group("Materials")
@export var box_outer_frame_material: StandardMaterial3D
@export var box_diagonal_bar_material: StandardMaterial3D
@export var box_inner_fill_material: StandardMaterial3D
@export var box_body_material: StandardMaterial3D
@export var box_hat_material: StandardMaterial3D
@export var indicator_material: StandardMaterial3D

var floor_color: Color
var wall_color: Color
var goal_color: Color

var DESERT_OASIS := {
	"background_color": Color("#3E2B1D"),
	"floor_color": Color("#F3E9D2"),
	"wall_color": Color("#E0A96D"),
	"goal_color": Color("#1A6C3E"),
	"box_outer_frame_color": Color("#C57B57"),
	"box_diagonal_bar_color": Color("#8C5230"),
	"box_inner_fill_color": Color("#E8D8C4"),
	"player_body_color": Color("#1A508B"),
	"player_hat_color": Color("#C4884B"),
	"indicator_color": Color("#D4A373")
}

var ARCTIC_LAB := {
	"background_color": Color("#AEC3D6"),
	"floor_color": Color("#DDE3EA"),
	"wall_color": Color("#7A96BA"),
	"goal_color": Color("#E66767"),
	"box_outer_frame_color": Color("#565E7A"),
	"box_diagonal_bar_color": Color("#E5BE5E"),
	"box_inner_fill_color": Color("#C2B4B6"),
	"player_body_color": Color("#E5BE5E"),
	"player_hat_color": Color("#2A3546"),
	"indicator_color": Color("#1D8EC4")
}

var OCEAN_DEPTHS := {
	"background_color": Color("#01050F"),
	"floor_color": Color("#014C63"),
	"wall_color": Color("#003B50"),
	"goal_color": Color("#EF835F"),
	"box_outer_frame_color": Color("#CD853F"),
	"box_diagonal_bar_color": Color("#EF835F"),
	"box_inner_fill_color": Color("#001A33"),
	"player_body_color": Color("#01B7A3"),
	"player_hat_color": Color("#001A33"),
	"indicator_color": Color("#FDD017")
}

var CYBERPUNK_NEON := {
	"background_color": Color("#030A1A"),
	"floor_color": Color("#1E1E24"),
	"wall_color": Color("#0B1D51"),
	"goal_color": Color("#A35A71"),
	"box_outer_frame_color": Color("#01A3B0"),
	"box_diagonal_bar_color": Color("#C28F58"),
	"box_inner_fill_color": Color("#3A414A"),
	"player_body_color": Color("#D4A264"),
	"player_hat_color": Color("#39FF14"),
	"indicator_color": Color("#9E6AC7")
}

var UNDERGROUND_CAVERN := {
	"background_color": Color("#0F0F0F"),
	"floor_color": Color("#2B2B2B"),
	"wall_color": Color("#45271F"),
	"goal_color": Color("#B87A47"),
	"box_outer_frame_color": Color("#A1694F"),
	"box_diagonal_bar_color": Color("#A18968"),
	"box_inner_fill_color": Color("#3A414A"),
	"player_body_color": Color("#4B533F"),
	"player_hat_color": Color("#2F343A"),
	"indicator_color": Color("#7D6551")
}


func _ready() -> void:
	apply(DESERT_OASIS)


func apply(theme: Dictionary) -> void:
	RenderingServer.set_default_clear_color(theme.get("background_color"))
	floor_color = theme.get("floor_color")
	wall_color = theme.get("wall_color")
	goal_color = theme.get("goal_color")
	box_outer_frame_material.albedo_texture = _create_texture_from_color(theme.get("box_outer_frame_color"))
	box_diagonal_bar_material.albedo_texture = _create_texture_from_color(theme.get("box_diagonal_bar_color"))
	box_inner_fill_material.albedo_texture = _create_texture_from_color(theme.get("box_inner_fill_color"))
	box_body_material.albedo_texture = _create_texture_from_color(theme.get("player_body_color"))
	box_hat_material.albedo_texture = _create_texture_from_color(theme.get("player_hat_color"))
	indicator_material.albedo_texture = _create_texture_from_color(theme.get("indicator_color"))


func _create_texture_from_color(color: Color) -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
