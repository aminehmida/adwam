import 'package:flutter/services.dart' show appFlavor;

/// Whether this build came off the `dev` release channel (`--flavor dev`),
/// which tracks `main` and installs alongside the released app.
///
/// `appFlavor` is a compile-time constant, so prod builds tree-shake the dev
/// badge and everything behind this flag out of the binary.
const bool isDevChannel = appFlavor == 'dev';
