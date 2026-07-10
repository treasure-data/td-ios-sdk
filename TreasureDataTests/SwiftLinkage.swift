//
//  SwiftLinkage.swift
//  TreasureDataTests
//
//  The SDK is a Swift-containing static library, so the test target must link
//  the Swift runtime (incl. the back-deployment compatibility libraries needed
//  at the iOS 12 deployment target). Having at least one Swift file in the target
//  makes Xcode link with the Swift driver, which adds those library search paths
//  automatically — portably across local and CI toolchains. This file otherwise
//  does nothing.
//

import Foundation
