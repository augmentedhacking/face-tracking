//
//  FaceTrackingARView.swift
//  RealityKitFaceTracking
//
//  Created by Sebastian Buys on 11/7/23.
//

import Foundation
import ARKit
import simd
import Combine
import RealityKit
import UIKit
import Metal

// RealityKit ARFaceAnchor documentation
// https://developer.apple.com/documentation/arkit/arfaceanchor

class FaceTrackingARView: ARView {
    private var subscriptions = Set<AnyCancellable>()

    var viewModel: ViewModel
    
    // RealityKit entity added automatically for detected face
    private var faceEntity: HasModel?
    
    // Anchor entity for tracking world origin
    var worldOriginAnchor: AnchorEntity!
    
    // ARKit anchor added for face
    var faceAnchor: ARFaceAnchor?
    
    // Our own RealityKit entities for anchoring and rendering
    var faceAnchorEntity: AnchorEntity?
    var faceModelEntity: ModelEntity?
    
    var lookAtPoint: simd_float3?
    
    // Texture for debugging face mesh
    var faceTexture = try! TextureResource.load(named: "wireframeTextureGray")
    
    // Last screen touch point
    private var lastTouchPoint: UITouch?
    
    // Custom initializer
    init(viewModel: ViewModel, frame: CGRect) {
        self.viewModel = viewModel
        
        super.init(frame: frame)
    }
    
    // Required initializer - not implemented
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Required initializer - not implemented
    required init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        self.setupARSession()
        self.setupSubscriptions()
        self.setupScene()
    }
    
    private func setupARSession() {
        // Determine if face tracking is supported
        guard ARFaceTrackingConfiguration.isSupported else {
            fatalError("Face tracking is not supported on this device")
        }
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.maximumNumberOfTrackedFaces = 1
        
        print(ARFaceTrackingConfiguration.supportedNumberOfTrackedFaces)
        
        session.delegate = self
        session.run(configuration)
    }
    
    private func setupScene() {
        // Add world origin anchor
        let worldOriginAnchor = AnchorEntity(world: .zero)
        self.scene.addAnchor(worldOriginAnchor)
        self.worldOriginAnchor = worldOriginAnchor
    }
    
    private func setupSubscriptions() {
        // Subscribe to scene update events
        scene
            .subscribe(to: SceneEvents.Update.self, onSceneUpdate)
            .store(in: &subscriptions)
    }
    
    private func reset() {
        setupARSession()
        setupScene()
    }

    
    // Scene update handler
    // Called every frame because we subscribed to "SceneEvents.Update" in setupSubscriptions()
    private func onSceneUpdate(_ event: Event) {
        // Get face model entity or return if not found
        guard let faceModelEntity = self.faceModelEntity else {
            return
        }
   
        guard let lastTouchPoint = lastTouchPoint else {
            return
        }
        
        let lastTouchLocation = lastTouchPoint.location(in: self)
        
        // Create a ray through last touch point in 2D view space
        guard let ray = self.ray(through: lastTouchLocation) else { return }

        // Raycast using ray to find first entity that ray intersects with
        guard let raycastResult = scene.raycast(origin: ray.origin, direction: ray.direction, query: .nearest, mask: .all, relativeTo: nil).first, raycastResult.entity == faceModelEntity else {
            return
        }
        
        // Create ball and add to face model entity where ray hit
        let ballEntity = ModelEntity(mesh: .generateSphere(radius: .random(in: 0.005...0.02)), materials: [SimpleMaterial(color: .random, isMetallic: false)])
        faceModelEntity.addChild(ballEntity)
        let faceLocalPosition = faceModelEntity.convert(position: raycastResult.position, from: worldOriginAnchor)
        ballEntity.position = faceLocalPosition
        ballEntity.position.z += (ballEntity.model?.mesh.bounds.boundingRadius ?? 0)

    }
    
    // Find face entity added to scene by ARFaceTrackingConfiguration
//    private func findFaceEntity(scene: RealityKit.Scene) -> HasModel? {
//        // Create query predicate for entities that contain both SceneUnderstandingComponent and ModelComponent
//        let queryPredicate: QueryPredicate<Entity> = .has(SceneUnderstandingComponent.self) && .has(ModelComponent.self)
//        let entityQuery = EntityQuery(where: queryPredicate)
//        
//        // Search for entities that match predicate, filtering for first entitiy that contains a SceneUnderstandingComponent type face
//        let firstFace = scene.performQuery(entityQuery).first {
//            $0.components[SceneUnderstandingComponent.self]?.entityType == .face
//        } as? HasModel
//        
//        return firstFace
//    }
}

// MARK: - ARSessionDelegate methods
extension FaceTrackingARView: ARSessionDelegate {
    // Tells the delegate that one or more anchors have been added to the session.
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Filter for face anchors and grab first one
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            return
        }
        
        // Save reference to this ARFaceAnchor (ARKit)
        self.faceAnchor = faceAnchor
        
        // Create an AnchorEntity from the ARFaceAnchor (RealityKit)
        faceAnchorEntity = AnchorEntity()
        scene.addAnchor(faceAnchorEntity!)
        
        // Create ModelEntity
        let faceModelEntity = ModelEntity()
        faceModelEntity.name = "Face"
        
        // offset 0.5cm from face
        faceModelEntity.transform.matrix = .init(translation: [0, 0, 0.005])
        
        self.faceModelEntity = faceModelEntity
        self.faceAnchorEntity?.addChild(faceModelEntity)
    }
    
    // Tells the delegate that the session has adjusted the properties of one or more anchors.
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Filter for face anchors
        let updatedFaceAnchors = anchors.compactMap({ $0 as? ARFaceAnchor })
        
        // Find face anchor that matches the one we are tracking
        guard let updatedFaceAnchor = (updatedFaceAnchors.first { $0 == self.faceAnchor }) else {
            return
        }
        
        // Grab look at point and save value
        let lookAtPoint = updatedFaceAnchor.lookAtPoint
        self.lookAtPoint = lookAtPoint
        
        // Grab blend shapes and update viewModel
        let blendShapes = updatedFaceAnchor.blendShapes
        viewModel.blendShapes = blendShapes
        
        self.faceAnchorEntity?.transform.matrix = updatedFaceAnchor.transform
        
        guard let meshResource = makeRealityKitFaceMesh(from: updatedFaceAnchor) else {
            return
        }
        
        if let _ = faceModelEntity?.model {
            faceModelEntity?.model?.mesh = meshResource
        } else {
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(tint: .white, texture: .init(faceTexture))

            // Add occlusion material
            let occlusionMaterial = OcclusionMaterial()
            
            faceModelEntity?.model = ModelComponent(mesh: meshResource, materials: [material])
        }
     
        // Update collision shape
        let shapeResource = ShapeResource.generateConvex(from: meshResource)
        faceModelEntity?.collision = CollisionComponent(shapes: [shapeResource])
    }
    
    // Tells the delegate that one or more anchors have been removed from the session.
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
    }
}

// MARK: - Touch handling
extension FaceTrackingARView {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchPoint = touches.first
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchPoint = touches.first
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchPoint = nil
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchPoint = nil
    }
}

func makeRealityKitFaceMesh(from anchor: ARFaceAnchor) -> MeshResource? {
    // Create RealityKit mesh from ARFaceAnchor geometry
    var meshDescriptor = MeshDescriptor()
    meshDescriptor.positions = MeshBuffers.Positions(anchor.geometry.vertices)
    meshDescriptor.primitives = .triangles(anchor.geometry.triangleIndices.map { UInt32($0)})
    meshDescriptor.textureCoordinates = MeshBuffers.TextureCoordinates(anchor.geometry.textureCoordinates)
    
    return try? MeshResource.generate(from: [meshDescriptor])
}

extension UIColor {
    static var random: UIColor {
        return UIColor(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1),
            alpha: 1
        )
    }
}
