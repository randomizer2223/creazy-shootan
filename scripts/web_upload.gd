class_name WebUpload
## Вибір файлу картинки у браузері (через JavaScript).

const JS_OPEN := """
(function(){
  window._lieroUpload = null;
  var i = document.createElement('input');
  i.type = 'file';
  i.accept = 'image/*';
  i.onchange = function(e){
    var f = e.target.files[0];
    if (!f) return;
    var r = new FileReader();
    r.onload = function(){
      var s = r.result;
      window._lieroUpload = s.substring(s.indexOf(',') + 1);
    };
    r.readAsDataURL(f);
  };
  i.click();
})();
"""


static func open_picker() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(JS_OPEN, true)


## Повертає байти файлу, коли користувач вибрав файл, інакше порожній масив.
static func poll() -> PackedByteArray:
	if not OS.has_feature("web"):
		return PackedByteArray()
	var v = JavaScriptBridge.eval("window._lieroUpload || ''", true)
	if typeof(v) != TYPE_STRING or v == "":
		return PackedByteArray()
	JavaScriptBridge.eval("window._lieroUpload = null;", true)
	return Marshalls.base64_to_raw(v)


static func decode(bytes: PackedByteArray) -> Image:
	var img := Image.new()
	if img.load_png_from_buffer(bytes) == OK:
		return img
	if img.load_jpg_from_buffer(bytes) == OK:
		return img
	if img.load_webp_from_buffer(bytes) == OK:
		return img
	if img.load_bmp_from_buffer(bytes) == OK:
		return img
	return null
