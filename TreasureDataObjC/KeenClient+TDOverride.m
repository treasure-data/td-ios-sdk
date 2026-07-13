//
//  KeenClient+TDOverride.m
//  TreasureDataObjC
//
//  Intentionally empty. The `KeenClient (TDOverride)` category only re-declares
//  KeenClient's private `sendEvents:...` selector so Swift can override it; the
//  implementation lives in KeenClient itself (and the Swift TDClient override).
//  This translation unit exists so the SwiftPM C-family target has a source to
//  compile and can be imported as the `TreasureDataObjC` module.
//

#import "KeenClient+TDOverride.h"
