import UIKit
import ARKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("""
                ARKit is not available on this device.
            """)
        }

        return true
    }
	
	func applicationWillResignActive(_ application: UIApplication) {
		if let viewController = self.window?.rootViewController as? ViewController {
			viewController.blurView.isHidden = false
		}
	}
	
	func applicationDidBecomeActive(_ application: UIApplication) {
		if let viewController = self.window?.rootViewController as? ViewController {
			viewController.blurView.isHidden = true
		}
	}
}
