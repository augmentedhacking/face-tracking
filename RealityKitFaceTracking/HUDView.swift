//
//  HUDView.swift
//  RealityKitFaceTracking
//
//  Created by Sebastian Buys on 11/9/23.
//

import Foundation
import SwiftUI

struct HUDView: View {
    @StateObject var viewModel: ViewModel
    
    var body: some View {
        VStack(spacing: 10.0) {
            Text("JawOpen")
            HStack {
                if let jawOpen = viewModel.blendShapes[.jawOpen] {
                    Text("\(jawOpen.floatValue, specifier: "%.2f")")
                        .font(.system(size: 120.0))
                        .monospaced()
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    HUDView(viewModel: ViewModel())
}

