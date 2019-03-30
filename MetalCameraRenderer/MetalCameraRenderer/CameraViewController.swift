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

internal final class CameraViewController: MTKViewController {
    @IBOutlet weak var heightLayout: NSLayoutConstraint!
    
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
    var cellwidth:CGFloat = 0
    var cellheight:CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        metalCameraSession = MetalCameraSession(delegate: self)
        self.metalCameraSession.startCamera()
        self.cellwidth = self.heightLayout.constant
        self.cellheight = self.heightLayout.constant
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
                
                metalWriter.append(metalTexture: intexture, atTime: time)
            }
        }
    }

}




// MARK: - MetalCameraSessionDelegate
//@available(iOS 11.0, *)
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


//@available(iOS 11.0, *)
extension CameraViewController: VideoCaptureDelegate {
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


extension CameraViewController : UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return self.filterHelper.effectArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let contentCell = collectionView.dequeueReusableCell(withReuseIdentifier: "EffectCell", for: indexPath) as! EffectCell
        let filter = self.filterHelper.getFilter(At: indexPath.row)
        contentCell.effectImageView.image = UIImage(named: "icon")
        if contentCell.effectImageView.layer.cornerRadius == 0 {
            contentCell.effectImageView.layer.cornerRadius = contentCell.effectImageView.frame.height / 2
            contentCell.effectImageView.layer.masksToBounds = true
        }
        contentCell.effectTitle.text = filter.title
        return contentCell
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: cellwidth, height: self.cellheight)
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 5
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 5
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.baseKernel = self.filterHelper.getKernel(At: indexPath.row, Deivce: self.metalData)
    }
}
