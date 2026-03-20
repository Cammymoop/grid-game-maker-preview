extends Node

@export var font_name = "img_font.png"
@export var out_name = "out_font"
@export var font_width = 6
@export var font_height = 9

@export var symbols : String = ''

# table of ascii codes for supported symbols
var supported_symbols = {
	'!': 33, '"': 34, '#': 35, '$': 36, '%': 37, '&': 38, "'": 39, '(': 40, ')': 41,
	'*': 42, '+': 43, ',': 44, '-': 45, '.': 46, '/': 47,
	':': 58, ';': 59, '<': 60, '=': 61, '>': 62, '?': 63, '@': 64,
	'[': 91, '\\': 92, ']': 93, '^': 94, '_': 95, '`': 96,
	'{': 123, '|': 124, '}': 125, '~': 126,
}

func _ready():
	make_font()

func make_font():
	print('lets make a font')
	var font_img = load("res://assets/font/" + font_name)
	var font : FontFile = FontFile.new()
	font.add_texture(font_img)
	font.set_height(font_height)
	
	var LETTERS = 26
	var LETTERS_PER_LINE = 21
	
	for i in range(LETTERS):
		var rect = Rect2(Vector2((i%LETTERS_PER_LINE) * font_width, (i/LETTERS_PER_LINE) * font_height), Vector2(font_width, font_height))
		font.add_char(KEY_A + i + 32, 0, rect)
		rect.position.y += font_height * 2
		font.add_char(KEY_A + i, 0, rect) #capitals
	
	var cur_y = font_height * 4
	
	for i in range(len(symbols)):
		var symbol = symbols[i]
		if not supported_symbols.has(symbol):
			continue
		var rect = Rect2(Vector2((i%LETTERS_PER_LINE) * font_width, cur_y + ((i/LETTERS_PER_LINE) * font_height)), Vector2(font_width, font_height))
		font.add_char(supported_symbols[symbol], 0, rect)
	
	cur_y += font_height * 2
	
	#numbers
	for i in range(10):
		var rect = Rect2(Vector2(i * font_width, cur_y), Vector2(font_width, font_height))
		font.add_char(48 + i, 0, rect)
	
	font.add_char(KEY_SPACE, 0, Rect2(Vector2(30, 8), Vector2(6, 7)))
	
	var label = find_child("Label")
	if label:
		label.add_theme_font_override("font", font)
	
	ResourceSaver.save("res://assets/font/" + out_name + ".tres", font)
