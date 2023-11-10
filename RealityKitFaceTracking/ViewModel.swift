//
//  ViewModel.swift
//  RealityKitFaceTracking
//
//  Created by Sebastian Buys on 11/7/23.
//

import Combine
import Foundation
import ARKit

class ViewModel: ObservableObject {
    @Published var blendShapes: [ARFaceAnchor.BlendShapeLocation : NSNumber] = [:]
}
