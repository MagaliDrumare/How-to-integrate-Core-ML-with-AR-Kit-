//
//  ViewController.swift
//  IntegratedCoreML
//
//  Created by DRUMARE on 17/11/2017.
//  Copyright © 2017 DRUMARE. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {
 
    @IBOutlet var sceneView: ARSCNView!
    
    // import the model
    private var resnetModel = Resnet50()
    // résultat du Hit test
    private var hitTestResult :ARHitTestResult!
    // résultat renvoyer par l'API CoreML
    private var visionRequests = [VNRequest]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Call the main function registerGestureRecognizer
        // execute all the fuctions below.
        
        registerGestureRecognizer()
        
    }
    
    // Code for Tap Gesture functionality
    
    // function registerGestureRecognizer
    // input : target: self; action: #selector(tapped)
    // output : add to the sceneView a GestureRecognizer
    // call @objc func tapped
    private func registerGestureRecognizer(){
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        self.sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
  
    // function called by registerGestureRecognizer
    // input : (recognizer : UIGestureRecognizer)
    // outputs : hitTestResult , pixelBuffer
    // hitTestResult will serve to determine the coordinates of the text in func displayPrediction.
    // pixelBuffer is the input that is passed to obtain the prediction of Core ML Model in func performVisionRequest.
    @objc func tapped(recognizer : UIGestureRecognizer) {
        
        // keep the tapped zone
        let sceneView = recognizer.view as! ARSCNView
        let touchLocation = self.sceneView.center
        
        // keep the currentFrame
        guard let currentFrame = sceneView.session.currentFrame else{
            return
        }
        // register the touchlocation in hitTestResults
        let hitTestResults = sceneView.hitTest(touchLocation, types: .featurePoint)
        
        if hitTestResults.isEmpty{
            return
        }
        guard let hitTestResult = hitTestResults.first else {
            return
        }
        
        self.hitTestResult = hitTestResult
        let pixelBuffer = currentFrame.capturedImage
        
        performVisionRequest(pixelBuffer: pixelBuffer)
        
    }
    
    // Code for ARKit functionality
    
    // function called by performVisionRequest to diplay the prediction of Core ML Model
    // input : text : String
    // outputs : parentNode (sphere and text representation in the ARSCNView)
    
    private func displayPredictions(text :String) {
        // node creation calling the function createText
        let node = createText(text:text)
        
        // position of the node calling var hitTestResult
        node.position = SCNVector3(self.hitTestResult.worldTransform.columns.3.x, self.hitTestResult.worldTransform.columns.3.y, self.hitTestResult.worldTransform.columns.3.z)
        
        self.sceneView.scene.rootNode.addChildNode(node)
        
    }
    // private function createText called by the function displayPrediction
    private func createText (text: String) -> SCNNode {
        
        let parentNode = SCNNode()
        
        // creation of the SphereNode
        // sphere caracteristics
        let sphere = SCNSphere(radius: 0.01)
        let sphereMaterial = SCNMaterial()
        sphereMaterial.diffuse.contents = UIColor.orange
        sphere.firstMaterial = sphereMaterial
        // creation of the node
        let sphereNode = SCNNode(geometry:sphere)
        
        // creation of the TextNode
        
        // text caracteristics
        let textGeometry = SCNText(string: text, extrusionDepth: 0)
        //
        textGeometry.alignmentMode = kCAAlignmentCenter
        textGeometry.firstMaterial?.diffuse.contents = UIColor.orange
        textGeometry.firstMaterial?.specular.contents = UIColor.white
        textGeometry.firstMaterial?.isDoubleSided = false
        
        var font = UIFont(name:"futura", size: 0.15)
        textGeometry.font = font
        // creation of the node
        let textNode = SCNNode(geometry: textGeometry)
        // scale
        textNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
        
        // add sphereNode and textNode to the parentNode
        parentNode.addChildNode(sphereNode)
        parentNode.addChildNode(textNode)
        return parentNode
        }
    
    
    // Code for Core ML integration
    
    // function performVisionRequest called by @objc func tapped performVisionRequest(pixelBuffer: pixelBuffer)
    
    private func performVisionRequest(pixelBuffer :CVPixelBuffer) {
    
    // step 1 : create the VisionModel that will be passed to the VNCoreMLRequest
    // use the private var resnetModel = Resnet50()
    // don't forget to import Vision
    let visionModel = try! VNCoreMLModel(for: self.resnetModel.model)
    
        // step 2 : create the VNCoreMLRequest : request with VisionModel
    let request  = VNCoreMLRequest(model : visionModel) {request, error in
            if error != nil {
                return
            }
        // Step 3: Display the result of the request
            guard let observations = request.results else {
                return
            }
            
            let observation = observations.first as!VNClassificationObservation
            
            print ("Name \(observation.identifier) and confidence is \(observation.confidence)")
            
            DispatchQueue.main.sync{
                // call the function displayPredictions private func displayPredictions(text :String)
                // to implement the result of the prediction text: observation.identifier
                // with the right presentation criteria in the sceneView
                self.displayPredictions(text: observation.identifier)
            }
    
    }
        
        // Step 4 : imagerequestHandler mandatory to activate the VNCoreMLRequest : request
        
        request.imageCropAndScaleOption = .centerCrop
        self.visionRequests = [request]
        
        // initialize the VNImageRequestHandler
        let imageRequestHander = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation : .upMirrored, options : [:])
        
        // call the request with the VNImageRequestHandler created : imageRequestHander
        DispatchQueue.global().async {
            try! imageRequestHander.perform(self.visionRequests)
        }
        
    
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
