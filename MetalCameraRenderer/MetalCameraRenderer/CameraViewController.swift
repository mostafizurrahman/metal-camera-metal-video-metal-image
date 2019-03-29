//
//  ViewController.swift
//  MetalShaderCamera
//
//  Created by Mostafizur Rahman on 25/10/2016.
//  Copyright © 2018 image-app.com. All rights reserved.
//

import UIKit
import Metal
import CoreMedia
import CoreImage

enum CaptureType {
    case cameraFeed
    case metalFeed
    case unknown
}

@available(iOS 11.0, *)
internal final class CameraViewController: MTKViewController {
    
    @IBOutlet weak var cameraCaptureButton: UIButton!
    @IBOutlet weak var effectCaptureButton: UIButton!
    @IBOutlet weak var stopCaptureButton: UIButton!
    
    
    
    var displayTime:CMTime!
    var metalCameraSession: MetalCameraSession!
    var totalGifImages: [UIImage]?
    var countOfGifFrameGiven = 0
    
    var selectedIndex:Int = 0
    var captureType:CaptureType = .unknown
    var metalVideoWriter:MetalVideoWriter?
    var cameraVideoWriter:CameraVideoWriter?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        metalCameraSession = MetalCameraSession(delegate: self)
        self.metalCameraSession.startCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
       
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.global().async {
            print("wait")
            DispatchQueue.main.async {
                if !self.metalCameraSession.captureSession.isRunning {
                    self.metalCameraSession.captureSession.startRunning()
                }
            }
        }
        
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if self.metalCameraSession.captureSession.isRunning {
            self.metalCameraSession.captureSession.stopRunning()
        }
    }
    let serialQueue = DispatchQueue(label: "queuename")
    
    @IBAction func startVideoCapturing(_ sender: UIButton) {
       self.changeButtonVisibility(true)
        self.captureType = .cameraFeed
    }
    
    @IBAction func startEffectCapturing(_ sender: UIButton) {
        self.changeButtonVisibility(true)
        self.captureType = .metalFeed
    }
    
    
    @IBAction func finishCapturing(_ sender: UIButton) {
        if self.captureType == .metalFeed {
            self.metalCameraSession.captureSessionQueueAudio.async {
                self.metalWriteQueue.async {
                    self.shouldWritetexture = false
                    self.metalVideoWriter?.endVideoCapture()
                }
            }
        } else if self.captureType == .cameraFeed {
            self.cameraVideoWriter?.endVideoCapture()
        }
        self.captureType = .unknown
    }
    
    
    public func changeButtonVisibility(_ hidden:Bool){
        self.effectCaptureButton.isHidden = hidden
        self.cameraCaptureButton.isHidden = hidden
        self.stopCaptureButton.isHidden = !hidden
        self.metalCameraSession.captureSessionQueueAudio.async {
            self.shouldWritetexture = true
        }
    }
    
    // perform segue to next view controller with video url
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let idf = segue.identifier else {
            return
        }
        if idf.elementsEqual("VideoSegue") {
            if let vc = segue.destination as? VideoViewController {
                vc.videoURL = (sender as! URL)
            }
        }
    }
    
    override func writeVideo(Texture intexture: MTLTexture) {
        if self.captureType == .metalFeed {
            
            if self.metalVideoWriter == nil {
                self.metalVideoWriter = MetalVideoWriter.init(withMetalTexture: intexture,
                                                              atSourceTime: self.displayTime)
                self.metalVideoWriter?.captureDelegate = self
            } else {
                guard let metalWriter = self.metalVideoWriter,
                    let time = self.displayTime else {
                    return
                }
                
                self.serialQueue.async {
                    metalWriter.append(metalTexture: intexture, atTime: time)
                }
            }
        }
    }

}




// MARK: - MetalCameraSessionDelegate
@available(iOS 11.0, *)
extension CameraViewController: CameraSessionDelegate {

    func metalCameraSession(_ session: MetalCameraSession, didAudioBufer buffer: CMSampleBuffer) {
        if self.captureType == .cameraFeed ||
            self.captureType == .metalFeed {
            if let camWriter = self.captureType == .metalFeed ? self.metalVideoWriter : self.cameraVideoWriter {
                camWriter.appendAudioSample(buffer)
            }
        }
    }
    
    func metalCameraSession(_ session: MetalCameraSession, didVideoBuffer buffer: CMSampleBuffer) {
        // starts cameara feed writing if video capture type is changed to cameraFeed
        if self.captureType == .cameraFeed  {
            if self.cameraVideoWriter == nil {
                self.cameraVideoWriter = CameraVideoWriter.init(withSampleBuffer: buffer)
                self.cameraVideoWriter?.captureDelegate = self
            } else {
                guard let camWriter = self.cameraVideoWriter else {
                    return
                }
                camWriter.appendVideoSample(buffer)
            }
        }
    }
    
    func metalCameraSession(_ session: MetalCameraSession,
                            didReceiveFrameAsTextures textures: [MTLTexture],
                            atTime sourceTime: CMTime) {
        
        self.texture = textures[0]
        self.displayTime = sourceTime
        
    }
    
    
    
    func metalCameraSession(_ session: MetalCameraSession,
                            didUpdateState: MetalCameraSessionState,
                            error: MetalCameraSessionError?) {
        
    }
}


extension CameraViewController: VideoCaptureDelegate{
    func onVideoCaptureStarted(){
        print("video writing started! type : \(self.captureType)")
        DispatchQueue.main.async {
//            if self.captureType == .met
        }
    }
    func onVideoCaptureEnded(videoUrl url:URL){
        DispatchQueue.main.async {
            self.metalVideoWriter = nil
            self.cameraVideoWriter = nil
            self.performSegue(withIdentifier: "VideoSegue", sender: url)
            self.changeButtonVisibility(false)
        }
    }
}

