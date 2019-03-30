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
import AVFoundation



enum CaptureType {
    case cameraFeed
    case metalFeed
    case unknown
}

internal final class CameraViewController: MTKViewController {
    @IBOutlet weak var heightLayout: NSLayoutConstraint!
    
    let themeColor = UIColor.init(rgb: 0xFF0066)
    @IBOutlet weak var cameraCaptureButton: UIButton!
    @IBOutlet weak var effectCaptureButton: UIButton!
    @IBOutlet weak var stopCaptureButton: UIButton!
    
    var timeMin = 0
    var timeSec = 0
    weak var timer: Timer?
    var yourLabel:UILabel!
    var recLayer:CALayer!
    var selectedIdf = "NM0"
    var displayTime:CMTime!
    var metalCameraSession: MetalCameraSession!
    var totalGifImages: [UIImage]?
    var countOfGifFrameGiven = 0
    let cellSpace:CGFloat = 2.5
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
    
    @IBOutlet weak var filterCollection: UICollectionView!
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.main.async {
            self.filterCollection.reloadData()
            self.effectCaptureButton.layer.cornerRadius = self.effectCaptureButton.frame.height / 2
            self.effectCaptureButton.layer.masksToBounds = true
            self.stopCaptureButton.layer.cornerRadius = self.stopCaptureButton.frame.height / 2
            self.stopCaptureButton.layer.masksToBounds = true
            
        }
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

    @IBAction func switchCamera(_ sender: Any) {
        //Change camera source
        if let ml = metalCameraSession {
            let session = ml.captureSession
            //Indicate that some changes will be made to the session
            session.beginConfiguration()
            
            //Remove existing input
            guard let currentCameraInput: AVCaptureInput = session.inputs.first else {
                return
            }
            
            session.removeInput(currentCameraInput)
            
            //Get new input
            var newCamera: AVCaptureDevice! = nil
            if let input = currentCameraInput as? AVCaptureDeviceInput {
                if (input.device.position == .back) {
                    newCamera = cameraWithPosition(position: .front)
                } else {
                    newCamera = cameraWithPosition(position: .back)
                }
            }
            
            //Add input to session
            var err: NSError?
            var newVideoInput: AVCaptureDeviceInput!
            do {
                newVideoInput = try AVCaptureDeviceInput(device: newCamera)
            } catch let err1 as NSError {
                err = err1
                newVideoInput = nil
            }
            
            if newVideoInput == nil || err != nil {
                print("Error creating capture device input: \(err?.localizedDescription)")
            } else {
                session.addInput(newVideoInput)
            }
            
            //Commit all the configuration changes at once
            session.commitConfiguration()
        }
    }
    
    // Find a camera with the specified AVCaptureDevicePosition, returning nil if one is not found
    func cameraWithPosition(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if #available(iOS 10.0, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
            for device in discoverySession.devices {
                if device.position == position {
                    return device
                }
            }
        } else {
            // Fallback on earlier versions
        }
        
        
        return nil
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
        self.recLayer = CALayer()
        self.recLayer.frame = CGRect(x: 22, y: UIScreen.main.bounds.height - 25, width: 22, height: 22)
        self.recLayer.cornerRadius = 11
        self.recLayer.masksToBounds = true
        let colourAnim = CABasicAnimation(keyPath: "backgroundColor")
        colourAnim.fromValue = UIColor.white.cgColor
        colourAnim.toValue = UIColor.init(rgb: 0xFF0066).cgColor
        colourAnim.duration = 1.0
        colourAnim.autoreverses = true
        colourAnim.repeatCount = Float.infinity
        self.recLayer.add(colourAnim, forKey: "colourAnimation")
        self.recLayer.backgroundColor = UIColor.init(rgb: 0xFF0066).cgColor
        self.view.layer.insertSublayer(self.recLayer, at: 0)
        
        self.yourLabel = UILabel(frame: CGRect(x: 50, y: UIScreen.main.bounds.height - 25, width: 150, height: 22))
        self.yourLabel.font = UIFont.systemFont(ofSize: 14, weight: UIFont.Weight.light)
        self.view.addSubview(self.yourLabel)
        startTimer()
    }
    
    @IBAction func finishCapturing(_ sender: UIButton) {
        if self.captureType == .metalFeed {
            self.recLayer.removeAllAnimations()
            self.recLayer.removeFromSuperlayer()
            self.recLayer = nil
            self.yourLabel.removeFromSuperview()
            self.stopTimer()
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
//        self.cameraCaptureButton.isHidden = hidden
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

    
    @objc fileprivate func timerTick(){
        timeSec += 1
        
        if timeSec == 60{
            timeSec = 0
            timeMin += 1
        }
        
        let timeNow = String(format: "%02d:%02d", timeMin, timeSec)
        
        yourLabel.text = timeNow
    }
    
    // resets both vars back to 0 and when the timer starts again it will start at 0
    @objc fileprivate func resetTimerToZero(){
        timeSec = 0
        timeMin = 0
        stopTimer()
    }
    
    
    
    // if you need to reset the timer to 0 and yourLabel.txt back to 00:00
    @objc fileprivate func resetTimerAndLabel(){
        
        resetTimerToZero()
        yourLabel.text = String(format: "%02d:%02d", timeMin, timeSec)
    }
    
    // stops the timer at it's current time
    @objc fileprivate func stopTimer(){
        
        timer?.invalidate()
    }
    // MARK:- Timer Functions
    fileprivate func startTimer(){
        
        // if you want the timer to reset to 0 every time the user presses record you can uncomment out either of these 2 lines
        
        timeSec = 0
        timeMin = 0
        
        // If you don't use the 2 lines above then the timer will continue from whatever time it was stopped at
        let timeNow = String(format: "%02d:%02d", timeMin, timeSec)
        yourLabel.text = timeNow
        
        stopTimer() // stop it at it's current time before starting it again
        if #available(iOS 10.0, *) {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.timerTick()
            }
        } else {
            timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(timerTick), userInfo: nil, repeats: true)
            
            // Fallback on earlier versions
        }
        timer?.tolerance = 0.1
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
//        if contentCell.effectImageView.layer.cornerRadius == 0 {
            contentCell.effectImageView.layer.cornerRadius = 35
            contentCell.effectImageView.layer.masksToBounds = true
//        }
        if self.selectedIdf.elementsEqual(filter.filterID){
            contentCell.effectImageView.layer.borderColor = self.themeColor.cgColor
            contentCell.effectImageView.layer.borderWidth = 3
        } else {
            contentCell.effectImageView.layer.borderWidth = 0
        }
        contentCell.effectTitle.text = filter.title
        return contentCell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as! EffectCell).effectImageView.layer.cornerRadius =  (cell as! EffectCell).effectImageView.frame.height / 2
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: cellwidth - cellSpace * 2, height: self.cellheight - cellSpace * 2)
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 8
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: cellSpace, left: cellSpace * 5, bottom: cellSpace, right: cellSpace * 5)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 8
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let filter = self.filterHelper.getFilter(At: indexPath.row)
        
        var index = 0
        for fl in self.filterHelper.effectArray {
        
            if fl.filterID.elementsEqual(self.selectedIdf){
                break
            }
            index += 1
        }
        let _index = IndexPath(row: index, section: 0)
        if let cell = collectionView.cellForItem(at: _index) as? EffectCell {
            cell.effectImageView.layer.borderWidth = 0
        }
        self.selectedIdf = filter.filterID
        self.baseKernel = self.filterHelper.getKernel(At: indexPath.row, Deivce: self.metalData)
        
        let _cell = collectionView.cellForItem(at: indexPath) as! EffectCell
        _cell.effectImageView.layer.borderColor = self.themeColor.cgColor
        _cell.effectImageView.layer.borderWidth = 3;
        self.filterCollection.reloadData()
    }
}
extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    convenience init(rgb: Int) {
        self.init(
            red: (rgb >> 16) & 0xFF,
            green: (rgb >> 8) & 0xFF,
            blue: rgb & 0xFF
        )
    }
}
