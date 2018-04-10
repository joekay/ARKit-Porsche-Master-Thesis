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
            
            if lightBActive{
            if(lightEstimate.ambientIntensity > 1400){
                estimatedLightIntensity = 1400
            }else if(lightEstimate.ambientIntensity < 600){
                estimatedLightIntensity = 600
            }else{
                estimatedLightIntensity = lightEstimate.ambientIntensity
            }
            
            sceneView.scene.rootNode.childNode(withName: "car", recursively: true)?.childNode(withName: "spot1", recursively: true)?.light?.intensity = estimatedLightIntensity
            
            sceneView.scene.rootNode.childNode(withName: "car", recursively: true)?.childNode(withName: "spot2", recursively: true)?.light?.intensity = estimatedLightIntensity
            
            sceneView.scene.rootNode.childNode(withName: "car", recursively: true)?.childNode(withName: "spot3", recursively: true)?.light?.intensity = estimatedLightIntensity
            
            sceneView.scene.rootNode.childNode(withName: "car", recursively: true)?.childNode(withName: "spot4", recursively: true)?.light?.intensity = estimatedLightIntensity
            
            //print("AAA: " , estimatedLightIntensity)
            //print("Intensity: " , lightEstimate.ambientIntensity," Temp: ", lightEstimate.ambientColorTemperature)
            }
            
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
        
        //counter = counter + 1
        
        if mapperActive{
        if let environmentMapper = self.environmentMapper {
            environmentMapper.updateMap(withFrame: frame)
        }
        }
        if lightBActive{
            
            var img: CGImage?
            VTCreateCGImageFromCVPixelBuffer(frame.capturedImage, nil, &img)
            
            // Update reflection every 200 frame
            //print(counter)
            if (counter == 1 || counter % 1000 == 0) {
                sceneView.scene.rootNode.childNode(withName: "car", recursively: true)?.childNode(withName: "body", recursively: true)?.geometry?.material(named: "Material__792 color")?.reflective.contents = img
            
                sceneView.scene.rootNode.childNode(withName: "car", recursively: true)?.childNode(withName: "door_rf_ok", recursively: true)?.geometry?.material(named: "Material__790color")?.reflective.contents = img

                sceneView.scene.rootNode.childNode(withName: "car", recursively: true)?.childNode(withName: "door_lf_ok", recursively: true)?.geometry?.material(named: "Material__791color")?.reflective.contents = img
            }
            
        }
        if (counter > 5000){
            counter = 0
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
    
    /*func blurredImage(with sourceImage: CGImage) -> CGImage {
        //  Create our blurred image
        let context = CIContext(options: nil)
        let inputImage = CIImage(cgImage: sourceImage)
        //  Setting up Gaussian Blur
        var filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        filter?.setValue(6.0, forKey: "inputRadius")
        let result = filter?.value(forKey: kCIOutputImageKey) as? CIImage
        
        /*  CIGaussianBlur has a tendency to shrink the image a little, this ensures it matches
         *  up exactly to the bounds of our original image */
        
        let cgImage = context.createCGImage(result ?? CIImage(), from: inputImage.extent)
        return cgImage!
    }*/
    
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
