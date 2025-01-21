//
//  CameraView.swift
//  YOLOv8-seg-iOS
//
//  Created by Viet Duc on 19/1/25.
//

import SwiftUI
import UIKit
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    var imageHandler: (UIImage?) -> Void
    @Binding var isCameraReady: Bool
    

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController(isCameraReady: $isCameraReady)
        controller.imageHandler = imageHandler
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

class CameraViewController: UIViewController {
    var captureSession: AVCaptureSession?
    var photoOutput = AVCapturePhotoOutput()
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var zoomFactor: CGFloat = 5.0
    
    let zoomLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.frame = CGRect(x: 16, y: 50, width: 120, height: 30)
        return label
    }()
    
    var imageHandler: ((UIImage?) -> Void)?
    
    @Binding var isCameraReady: Bool

    init(isCameraReady: Binding<Bool>) {
        _isCameraReady = isCameraReady
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupOverlay()

//        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
//        view.addGestureRecognizer(pinchGestureRecognizer)
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        view.addGestureRecognizer(pinchGestureRecognizer)
    }

    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo

        guard let session = captureSession else { return }

        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Back camera not found")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer?.videoGravity = .resizeAspectFill
            previewLayer?.frame = view.bounds

            if let previewLayer = previewLayer {
                view.layer.addSublayer(previewLayer)
            }

            session.startRunning()

            try setZoomFactor(to: 5)

            setupOverlay()

            DispatchQueue.main.async {
                self.isCameraReady = true
            }
        } catch {
            print("Error setting up camera: \(error)")
        }
    }

        func setZoomFactor(to factor: CGFloat) throws {
        guard let deviceInput = captureSession?.inputs.first as? AVCaptureDeviceInput else {
            throw NSError(domain: "Camera", code: -1, userInfo: [NSLocalizedDescriptionKey: "Camera device not found"])
        }
        let device = deviceInput.device
        try device.lockForConfiguration()
        device.videoZoomFactor = max(1.0, min(factor, device.activeFormat.videoMaxZoomFactor))
        device.unlockForConfiguration()
    }

    
    func updateZoomLabel() {
        zoomLabel.text = "Zoom: \(String(format: "%.1fx", zoomFactor))"
    }

    func setupOverlay() {
        
        view.layer.sublayers?.removeAll(where: { $0 is CAShapeLayer })
        view.subviews.forEach { $0.removeFromSuperview() }

        let overlayLayer = CAShapeLayer()
        overlayLayer.frame = view.bounds
        overlayLayer.strokeColor = UIColor.red.cgColor
        overlayLayer.lineWidth = 10.0

        let overlayPath = UIBezierPath()
        let spacing: CGFloat = view.bounds.width * 0.55

        let firstLineX = view.bounds.width / 2 - spacing / 2
        let secondLineX = view.bounds.width / 2 + spacing / 2

        overlayPath.move(to: CGPoint(x: firstLineX, y: 0))
        overlayPath.addLine(to: CGPoint(x: firstLineX, y: view.bounds.height))

        overlayPath.move(to: CGPoint(x: secondLineX, y: 0))
        overlayPath.addLine(to: CGPoint(x: secondLineX, y: view.bounds.height))

        overlayLayer.path = overlayPath.cgPath
        view.layer.addSublayer(overlayLayer)
        
        view.addSubview(zoomLabel)
        updateZoomLabel()
        
        let captureButton = UIButton(type: .custom)
        captureButton.frame = CGRect(x: (view.frame.width - 70) / 2, y: view.frame.height - 100, width: 70, height: 70)
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 2
        captureButton.layer.borderColor = UIColor.gray.cgColor
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(captureButton)
    }

    @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let deviceInput = captureSession?.inputs.first as? AVCaptureDeviceInput else { return }
        let device = deviceInput.device

        if gesture.state == .changed {
            do {
                try device.lockForConfiguration()

                // Zoom the camera preview only
                let newZoomFactor = max(1.0, min(device.videoZoomFactor * gesture.scale, device.activeFormat.videoMaxZoomFactor))
                device.videoZoomFactor = newZoomFactor
                zoomFactor = newZoomFactor

                gesture.scale = 1.0

                DispatchQueue.main.async {
                    self.updateZoomLabel()
                }

                device.unlockForConfiguration()
            } catch {
                print("Error setting zoom factor: \(error)")
            }
        }
    }


    @objc func capturePhoto() {
        let photoSettings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            imageHandler?(nil)
        } else if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            imageHandler?(image)
        } else {
            imageHandler?(nil)
        }
    }
}


