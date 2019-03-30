//
//  VideoViewController.swift
//  Metal Camera
//
//
//  Created by Mostafizur Rahman on 25/10/2016.
//  Copyright © 2018 image-app.com. All rights reserved.
//

import UIKit
import AVFoundation
import Photos


class VideoViewController: UIViewController {

    @IBOutlet weak var backButton: UIButton!
    var videoURL:URL!
    var player:AVPlayer!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        player = AVPlayer(url: videoURL)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = self.view.bounds
        self.view.layer.addSublayer(playerLayer)
        
        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.player.play()
        self.view.bringSubviewToFront(self.backButton)
    }
    
    @IBAction func saveVideoData(_ sender: Any) {
        self.saveVideo()
    }
    func saveVideo(){
        PHPhotoLibrary.requestAuthorization { (authorizationStatus) in
            switch authorizationStatus {
            case .authorized :
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.videoURL)
                }) { saved, error in
                    if saved {
                        let alertController = UIAlertController(title: "Your video was successfully saved", message: nil, preferredStyle: .alert)
                        let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alertController.addAction(defaultAction)
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
                break
            case .notDetermined:
                print("not determined")
                break
            case .restricted:
                print("restricted")
                break
            case .denied:
                let notificationName = Notification.Name(rawValue: "media_reading_denied")
                NotificationCenter.default.post(name: notificationName, object: nil)
                print("denied")
                break
            }
        }
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    @IBAction func exitViedeoViewController(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
}
