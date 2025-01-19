//
//  CameraView.swift
//  YOLOv8-seg-iOS
//
//  Created by Viet Duc on 19/1/25.
//

import SwiftUI
import UIKit

struct CameraView: UIViewControllerRepresentable {
    var imageHandler: (UIImage?) -> Void
    @Binding var isCameraReady: Bool // Thêm một binding để theo dõi trạng thái camera

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        if let view = picker.view {
            view.frame = UIScreen.main.bounds // Đặt frame của view camera cho vừa màn hình
        }

        // Đặt trạng thái isCameraReady là false khi bắt đầu
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Đợi 1 giây trước khi camera chuẩn bị sẵn sàng
            self.isCameraReady = true // Sau khi đợi, camera sẽ sẵn sàng
        }
        
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(imageHandler: imageHandler)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var imageHandler: (UIImage?) -> Void

        init(imageHandler: @escaping (UIImage?) -> Void) {
            self.imageHandler = imageHandler
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                imageHandler(image)
            } else {
                imageHandler(nil)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            imageHandler(nil)
            picker.dismiss(animated: true)
        }
    }
}




