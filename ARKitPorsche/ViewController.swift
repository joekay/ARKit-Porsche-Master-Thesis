import ARKit
import SceneKit
import UIKit
import ARKitEnvironmentMapper

class ViewController: UIViewController {
    
    @IBOutlet var sceneView: VirtualObjectARView!
    
    @IBOutlet weak var addObjectButton: UIButton!
    @IBOutlet weak var blurView: UIVisualEffectView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    @IBOutlet weak var ResetLightBtn: UIButton!
    @IBOutlet weak var ARKitLightingBtn: UIButton!
    @IBOutlet weak var ShowHideSettingsBtn: UIButton!
    
    var lightNode: SCNNode!
    var ambientLightNode: SCNNode!
    
    // Bool for settings
    var showSettings = true
    
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
    
    /*let environmentMapper = ARKitEnvironmentMapper(withImageName: "room")*/
    
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

        // Set up scene content.
        setupCamera()
        sceneView.scene.rootNode.addChildNode(focusSquare)

        ShowHideSettingsBtn.isHidden = true
        ARKitLightingBtn.isHidden = true
        ResetLightBtn.isHidden = true
        
        sceneView.automaticallyUpdatesLighting = false
        
        // Hook up status view controller callback(s).
        statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartExperience()
        }
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
        
        addAmbientLight()
        
        //configuration.isLightEstimationEnabled = false
        
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

        ResetLightBtn.isEnabled = true
        ActivateEnvMap()
        
    }
    
    // Reset Light button
    @IBAction func ResetLight(_ sender: Any) {
        
        // So that the user cant spam addAmbientLight
        // which illuminates the scene more every click
        RemoveAmbient()
        addAmbientLight()
        
    }
    
    @IBAction func ShowHideSettings(_ sender: Any) {
        showSettings = !showSettings
        
        if showSettings {
            ShowHideSettingsBtn.setTitle("Hide", for: .normal)
            ARKitLightingBtn.isHidden = false
            ResetLightBtn.isHidden = false
            
        } else {
            ShowHideSettingsBtn.setTitle("Show", for: .normal)
            ARKitLightingBtn.isHidden = true
            ResetLightBtn.isHidden = true
        }
        
    }
    
    
    
    // Function for reseting light to standard mode
    func addAmbientLight(){
        
        ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.darkGray
        ambientLightNode.light!.intensity = 8000
        
        ResetLightBtn.isEnabled = false
        
        sceneView.scene.rootNode.addChildNode(ambientLightNode)
        
        // Removes environment map if present
        sceneView.scene.lightingEnvironment.contents = nil
    }
    
    func RemoveAmbient(){
        ambientLightNode.removeFromParentNode()
    }
    
    func ActivateEnvMap(){
        
        ambientLightNode.removeFromParentNode()
        
    self.sceneView.session.configuration!.isLightEstimationEnabled = true
        
        if let environmentMap = UIImage(named: "Models.scnassets/environment_blur.exr") {
            sceneView.scene.lightingEnvironment.contents = environmentMap
        }
    }
    
}

