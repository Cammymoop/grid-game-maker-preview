extends RichTextLabel

func _ready() -> void:
    meta_clicked.connect(on_meta_clicked)
    meta_hover_started.connect(on_meta_hover_started)
    meta_hover_ended.connect(on_meta_hover_ended)

func on_meta_hover_started(meta: Variant) -> void:
    meta_underlined = true

func on_meta_hover_ended(meta: Variant) -> void:
    meta_underlined = false

func set_link_url(url: String) -> void:
    text = "[url]%s[/url]" % [url]

func on_meta_clicked(meta: Variant) -> void:
    var url_string: String = str(meta)
    if not url_string.begins_with("http://") and not url_string.begins_with("https://"):
        return
    OS.shell_open(url_string)