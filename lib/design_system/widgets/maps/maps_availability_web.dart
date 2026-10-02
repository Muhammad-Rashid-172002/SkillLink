import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// On the web, `google_maps_flutter` needs the Maps JavaScript API script in
/// `web/index.html`. Without it every GoogleMap throws while building.
bool googleMapsLoaded() {
  final google = globalContext['google'];
  if (google == null || google.isUndefinedOrNull) return false;
  return (google as JSObject).has('maps');
}
