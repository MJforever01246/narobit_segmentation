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
    @Binding var zoomFactor: CGFloat // Thêm zoomFactor để điều chỉnh zoom
    

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController(isCameraReady: $isCameraReady, zoomFactor: $zoomFactor)
        controller.imageHandler = imageHandler
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

class CameraViewController: UIViewController {
    var captureSession: AVCaptureSession?
        var photoOutput = AVCapturePhotoOutput()
        var previewLayer: AVCaptureVideoPreviewLayer?

        var imageHandler: ((UIImage?) -> Void)?
        
        @Binding var isCameraReady: Bool
        @Binding var zoomFactor: CGFloat

        init(isCameraReady: Binding<Bool>, zoomFactor: Binding<CGFloat>) {
            _isCameraReady = isCameraReady
            _zoomFactor = zoomFactor
            super.init(nibName: nil, bundle: nil)
        }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupOverlay()
        
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

            // Thêm overlay sau khi camera được thiết lập
            setupOverlay()

            DispatchQueue.main.async {
                self.isCameraReady = true
            }
        } catch {
            print("Error setting up camera: \(error)")
        }
    }


    func setupOverlay() {
            // Xóa các overlay cũ (nếu có)
            view.layer.sublayers?.removeAll(where: { $0 is CAShapeLayer })
            view.subviews.forEach { $0.removeFromSuperview() }

            // Tạo một CAShapeLayer để vẽ hai đường
            let overlayLayer = CAShapeLayer()
            overlayLayer.frame = view.bounds
            overlayLayer.strokeColor = UIColor.red.cgColor
            overlayLayer.lineWidth = 10.0

            let overlayPath = UIBezierPath()
            let spacing: CGFloat = view.bounds.width * 0.55

            // Tính toán vị trí của hai đường thẳng
            let firstLineX = view.bounds.width / 2 - spacing / 2
            let secondLineX = view.bounds.width / 2 + spacing / 2

            // Vẽ đường đầu tiên
            overlayPath.move(to: CGPoint(x: firstLineX, y: 0))
            overlayPath.addLine(to: CGPoint(x: firstLineX, y: view.bounds.height))

            // Vẽ đường thứ hai
            overlayPath.move(to: CGPoint(x: secondLineX, y: 0))
            overlayPath.addLine(to: CGPoint(x: secondLineX, y: view.bounds.height))

            // Gán đường dẫn vào layer
            overlayLayer.path = overlayPath.cgPath

            // Thêm layer vào view camera
            view.layer.addSublayer(overlayLayer)


            
            let captureButton = UIButton(type: .custom)
            captureButton.frame = CGRect(x: (view.frame.width - 70) / 2, y: view.frame.height - 100, width: 70, height: 70)
            captureButton.backgroundColor = .white
            captureButton.layer.cornerRadius = 35
            captureButton.layer.borderWidth = 2
            captureButton.layer.borderColor = UIColor.gray.cgColor
            captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
            view.addSubview(captureButton)

            
            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
            view.addGestureRecognizer(pinchGesture)
        }



    @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let deviceInput = captureSession?.inputs.first as? AVCaptureDeviceInput else { return }
        let device = deviceInput.device

        if gesture.state == .changed {
            do {
                try device.lockForConfiguration()

                
                let newZoomFactor = max(1.0, min(device.videoZoomFactor * gesture.scale, device.activeFormat.videoMaxZoomFactor))


                zoomFactor = newZoomFactor

                // Áp dụng zoom mới cho camera
                device.videoZoomFactor = newZoomFactor

                // Mở khóa cấu hình sau khi thay đổi
                device.unlockForConfiguration()

                // Đặt lại scale của gesture để tránh hiệu ứng lặp
                gesture.scale = 1.0
            } catch {
                print("Error setting zoom factor: \(error)")
            }
        }
    }




    @objc func capturePhoto() {
        let photoSettings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }

    func updateZoom(_ factor: CGFloat) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = max(1.0, min(factor, device.activeFormat.videoMaxZoomFactor))
            device.unlockForConfiguration()
        } catch {
            print("Failed to update zoom: \(error)")
        }
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

class OverlayView: UIView {
    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Màu của đường
        context.setStrokeColor(UIColor.red.cgColor)
        context.setLineWidth(10.0)

        // Tính toán vị trí 2 đường thẳng dọc
        let spacing: CGFloat = rect.width * 0.3
        let firstLineX = rect.width / 2 - spacing / 2
        let secondLineX = rect.width / 2 + spacing / 2

        // Vẽ đường đầu tiên
        context.move(to: CGPoint(x: firstLineX, y: 0))
        context.addLine(to: CGPoint(x: firstLineX, y: rect.height))

        // Vẽ đường thứ hai
        context.move(to: CGPoint(x: secondLineX, y: 0))
        context.addLine(to: CGPoint(x: secondLineX, y: rect.height))

        // Render các đường
        context.strokePath()
    }
}

