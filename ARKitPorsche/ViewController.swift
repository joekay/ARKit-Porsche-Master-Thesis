import ARKit
import SceneKit
import UIKit

class ViewController: UIViewController {
    
    @IBOutlet var sceneView: VirtualObjectARView!
    
    @IBOutlet weak var addObjectButton: UIButton!
    @IBOutlet weak var blurView: UIVisualEffectView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    @IBOutlet weak var ARKitLightingBtn: UIButton!
    
    var lightNode: SCNNode!
    var ambientLightNode: SCNNode!
    
    // UI Elements
    var focusSquare = FocusSquare()
    
    // Top ViewController with status and reset button
    lazy var statusViewController: StatusViewController = {
        return childViewControllers.lazy.flatMap({ $0 as? StatusViewController }).first!
    }()
	
	// The view controller that displays the virtual object selection menu.
	var objectsViewController: VirtualObjectSelectionViewController?
    
    var lighting = Lighting()
    
    // MARK: - ARKit Configuration Properties
    
    // A type which manages gesture manipulation of virtual content in the scene.
    lazy var virtualObjectInteraction = VirtualObjectInteraction(sceneView: sceneView)
    
    // Coordinates the loading and unloading of reference nodes for virtual objects.
    let virtualObjectLoader = VirtualObjectLoader()
    
    // Marks if the AR experience is available for restart.
    var isRestartAvailable = true
    
    var lightNodes = [SCNNode]()
    
    // A serial queue used to coordinate adding or removing nodes from the scene.
    let updateQueue = DispatchQueue(label: "com.mhp.ARKitPorsche")
    
    var screenCenter: CGPoint {
        let bounds = sceneView.bounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    /// Convenience accessor for the session owned by ARSCNView.
    var session: ARSession {
        return sceneView.session
    }
    
    // MARK: - View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        // Show fps and timing information
        sceneView.showsStatistics = true
        
        // Feature points
        // sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]

        // Set up scene content.
        setupCamera()
        sceneView.scene.rootNode.addChildNode(focusSquare)

        ARKitLightingBtn.isHidden = true
        
        sceneView.automaticallyUpdatesLighting = false
        if let environmentMap = UIImage(named: "Models.scnassets/environment_blur.exr") {
            sceneView.scene.lightingEnvironment.contents = environmentMap
        }
        
        // Setup environment mapping.
        // let environmentMap = UIImage(named: "Models.scnassets/StaticEnvMap/environment_blur.exr")!
        // sceneView.scene.lightingEnvironment.contents = environmentMap

        // Hook up status view controller callback(s).
        statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartExperience()
        }
        
        /*let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showVirtualObjectSelectionViewController))
        // Set the delegate to ensure this gesture is only used when there are no virtual objects in the scene.
        tapGesture.delegate = self
        sceneView.addGestureRecognizer(tapGesture)*/
    }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		// Prevent the screen from being dimmed to avoid interuppting the AR experience.
		UIApplication.shared.isIdleTimerDisabled = true

        // Start the `ARSession`.
        resetTracking()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

        session.pause()
	}

    
    // MARK: - Scene content setup

    func setupCamera() {
        guard let camera = sceneView.pointOfView?.camera else {
            fatalError("Expected a valid `pointOfView` from the scene.")
        }

        camera.wantsHDR = true
        camera.exposureOffset = -1
        camera.minimumExposure = -1
        camera.maximumExposure = 3
    }
    
    /// Creates a new AR configuration to run on the `session`.
	func resetTracking() {
		virtualObjectInteraction.selectedObject = nil
		
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        // configuration.planeDetection = [.horizontal, .vertical]
        
        
        //configuration.isLightEstimationEnabled = true
        
		session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        statusViewController.scheduleMessage("Find a surface to place the Porsche", inSeconds: 7.5, messageType: .planeEstimation)
	}

	func updateFocusSquare() {
        let isObjectVisible = virtualObjectLoader.loadedObjects.contains { object in
            return sceneView.isNode(object, insideFrustumOf: sceneView.pointOfView!)
        }
        
        if isObjectVisible {
            focusSquare.hide()
            
        } else {
            focusSquare.unhide()
            statusViewController.scheduleMessage("Try moving left and right", inSeconds: 5.0, messageType: .focusSquare)
        }
		
		if let result = self.sceneView.smartHitTest(screenCenter) {
			updateQueue.async {
				self.sceneView.scene.rootNode.addChildNode(self.focusSquare)
				let camera = self.session.currentFrame?.camera
				self.focusSquare.state = .detecting(hitTestResult: result, camera: camera)
			}
		} else {
			updateQueue.async {
				self.focusSquare.state = .initializing
				self.sceneView.pointOfView?.addChildNode(self.focusSquare)
			}
			self.addObjectButton.isHidden = true
			return
		}
		
        addObjectButton.isHidden = false
        statusViewController.cancelScheduledMessage(for: .focusSquare)
	}
    
    // Error Handling
    func displayErrorMessage(title: String, message: String) {
        // Blur the background.
        blurView.isHidden = false
        
        // Present an alert informing about the error that has occurred.
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.blurView.isHidden = true
            self.resetTracking()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
    
    // ARKit Lighting button
    @IBAction func BtnAPressed(_ sender: Any) {

        yolo()
        
    }
    
    func yolo(){
        /*guard let currentFrame = sceneView.session.currentFrame,
            let lightEstimate = currentFrame.lightEstimate else {
                return
        }*/
        ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.darkGray
        
        sceneView.scene.rootNode.addChildNode(ambientLightNode)
        
        /*guard let lightEstimate = self.sceneView.session.currentFrame?.lightEstimate else { return }
        let intensity = lightEstimate.ambientIntensity
        //lightNode.light!.intensity = intensity
        ambientLightNode.light!.intensity = intensity*/
        
        

    }
    
    func updateLightNodesLightEstimation() {
        DispatchQueue.main.async {
            guard let lightEstimate = self.sceneView.session.currentFrame?.lightEstimate else { return }
            
            let ambientIntensity = lightEstimate.ambientIntensity
            let ambientColorTemperature = lightEstimate.ambientColorTemperature
            
            for lightNode in self.lightNodes {
                guard let light = lightNode.light else { continue }
                light.intensity = ambientIntensity
                light.temperature = ambientColorTemperature
            }
        }
    }
    
    
    private func insertSpotlight() {
        let spotLight = SCNLight()
        spotLight.type = .spot
        spotLight.spotInnerAngle = 45
        spotLight.spotOuterAngle = 45
        
        let spotLightNode = SCNNode()
        spotLightNode.light = spotLight
        spotLightNode.name = "SpotNode"
        spotLightNode.position = SCNVector3(0, 1.0, 0)
        spotLightNode.eulerAngles = SCNVector3Make(-Float.pi / 2, 0, -0.2)
        
        sceneView.scene.rootNode.addChildNode(spotLightNode)
    }
    
    func lightNodesLightEstimation() {
        DispatchQueue.main.async {
            let lightEstimate = self.sceneView.session.currentFrame?.lightEstimate
            
            
            let ambientIntensity = lightEstimate!.ambientIntensity
            let ambientColorTemperature = lightEstimate!.ambientColorTemperature
            
            for lightNode in self.lightNodes {
                guard let light = lightNode.light else { continue }
                light.intensity = ambientIntensity
                light.temperature = ambientColorTemperature
            }
        }
    }
    
}

