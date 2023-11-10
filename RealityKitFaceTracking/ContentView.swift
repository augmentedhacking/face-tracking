//
//  ContentView.swift
//  RealityKitFaceTracking
//
//  Created by Sebastian Buys on 11/7/23.
//

import SwiftUI
import RealityKit

struct ContentView : View {
    @ObservedObject var viewModel = ViewModel()
    
    var body: some View {
        ZStack {
            ARViewContainer(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            HUDView(viewModel: viewModel)
        }
       
    }
}

struct ARViewContainer: UIViewRepresentable {
    var viewModel: ViewModel
    
    func makeUIView(context: Context) -> ARView {
        return FaceTrackingARView(viewModel: viewModel, frame: .zero)
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
}

#Preview {
    ContentView()
}
