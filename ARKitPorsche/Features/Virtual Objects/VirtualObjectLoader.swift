import Foundation
import ARKit

// Load and remove Virtual Objects
class VirtualObjectLoader {
	private(set) var loadedObjects = [VirtualObject]()
    
    private(set) var isLoading = false
	

    func loadVirtualObject(_ object: VirtualObject, loadedHandler: @escaping (VirtualObject) -> Void) {
        isLoading = true
		loadedObjects.append(object)
		
		// Load the content asynchronously.
        DispatchQueue.global(qos: .userInitiated).async {
            object.reset()
            object.load()

            self.isLoading = false
            loadedHandler(object)
        }
	}
    
    // MARK: - Removing Objects
    
    func removeAllVirtualObjects() {
        // Reverse the indices so we don't trample over indices as objects are removed.
        for index in loadedObjects.indices.reversed() {
            removeVirtualObject(at: index)
        }
    }
    
    func removeVirtualObject(at index: Int) {
        guard loadedObjects.indices.contains(index) else { return }

        loadedObjects[index].removeFromParentNode()
        loadedObjects.remove(at: index)
    }
}
