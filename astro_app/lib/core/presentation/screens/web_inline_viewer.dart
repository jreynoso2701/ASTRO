// Conditional import barrel para el visor inline web.
//
// En web carga la implementación real con HtmlElementView + iframe.
// En móvil/desktop carga el stub.
export 'web_inline_viewer_stub.dart'
    if (dart.library.html) 'web_inline_viewer_web.dart';
