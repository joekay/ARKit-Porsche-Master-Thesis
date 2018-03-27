import ARKit
import VideoToolbox

extension ViewController: ARSCNViewDelegate, ARSessionDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.virtualObjectInteraction.updateObjectToCurrentTrackingPosition()
            self.updateFocusSquare()
        }
		
		// If the object selection menu is open, update availability of items
		if objectsViewController != nil {
			let planeAnchor = focusSquare.currentPlaneAnchor
			objectsViewController?.updateObjectAvailability(for: planeAnchor)
		}
        
        // Settings for lighting environment incuding light intensity
        let lightingEnvironment = sceneView.scene.lightingEnvironment
        if let lightEstimate = session.currentFrame?.lightEstimate {
        lightingEnvironment.intensity = lightEstimate.ambientIntensity / BaseIntensity
            //print(lightEstimate.ambientColorTemperature)
        } else {
        lightingEnvironment.intensity = BaseIntensity
        }
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        DispatchQueue.main.async {
            self.statusViewController.cancelScheduledMessage(for: .planeEstimation)
            self.statusViewController.showMessage("Surface detected")
            if self.virtualObjectLoader.loadedObjects.isEmpty {
                self.statusViewController.scheduleMessage("Ready to place a Porsche", inSeconds: 7.5, messageType: .contentPlacement)
            }
        }
        updateQueue.async {
            for object in self.virtualObjectLoader.loadedObjects {
                object.adjustOntoPlaneAnchor(planeAnchor, using: node)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, frame: ARFrame, for anchor: ARAnchor) {
        updateQueue.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                for object in self.virtualObjectLoader.loadedObjects {
                    object.adjustOntoPlaneAnchor(planeAnchor, using: node)
                }
            } else {
                if let objectAtAnchor = self.virtualObjectLoader.loadedObjects.first(where: { $0.anchor == anchor }) {
                    objectAtAnchor.simdPosition = anchor.transform.translation
                    objectAtAnchor.anchor = anchor
                }
            }
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        statusViewController.showTrackingQualityInfo(for: camera.trackingState, autoHide: true)
        
        switch camera.trackingState {
        case .notAvailable, .limited:
            statusViewController.escalateFeedback(for: camera.trackingState, inSeconds: 3.0)
        case .normal:
            statusViewController.cancelScheduledMessage(for: .trackingStateEscalation)
			
			// Unhide content after successful relocalization.
			virtualObjectLoader.loadedObjects.forEach { $0.isHidden = false }
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if mapperActive{
        if let environmentMapper = self.environmentMapper {
            environmentMapper.updateMap(withFrame: frame)
        }
        }
        if lightBActive{
            print("Light b active")
            /*
            //VTCreateCGImageFromCVPixelBuffer(frame.capturedImage, nil, )
            sceneView.scene.lightingEnvironment.contents = CreateCGImageFromCVPixelBuffer(pixelBuffer: frame.capturedImage)*/
            var cgImage: CGImage?
            VTCreateCGImageFromCVPixelBuffer(frame.capturedImage, nil, &cgImage)
             sceneView.scene.lightingEnvironment.contents = cgImage
            
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        // Use `flatMap(_:)` to remove optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            self.displayErrorMessage(title: "The AR session failed.", message: errorMessage)
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
		// Hide content before going into the background.
		virtualObjectLoader.loadedObjects.forEach { $0.isHidden = true }
    }
	
	func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        /*
         Allow the session to attempt to resume after an interruption.
         This process may not succeed, so the app must be prepared
         to reset the session if the relocalizing status continues
         for a long time -- see `escalateFeedback` in `StatusViewController`.
         */
		return true
	}
}
