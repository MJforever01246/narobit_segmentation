//
//  ContentView.swift
//  YOLOv8-seg-iOS
//
//  Created by Marcel Opitz on 18.05.23.
//

import SwiftUI
import _PhotosUI_SwiftUI
import CoreImage
import PhotosUI
import UIKit

struct ContentView: View {
    
    @ObservedObject var viewModel: ContentViewModel
    
    @State var showBoxes: Bool = true
    @State var showMasks: Bool = true
    @State var presentMaskPreview: Bool = false
    @State private var isPresentingCamera: Bool = false
    @State private var isCameraReady: Bool = false
    @State private var isCameraActive = false
    @State private var zoomFactor: CGFloat = 5.0


        
    
    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                imageView

                settingsForm
                    .padding(.horizontal)
                    .padding(.top, 32)

                Spacer()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .sheet(isPresented: $presentMaskPreview) {
                buildMasksSheet()
            }

            if isCameraActive {
                ZStack {
                    // Camera view
                    CameraView(imageHandler: { image in
                        viewModel.predictions = []
                        viewModel.maskPredictions = []
                        viewModel.combinedMaskImage = nil
                        viewModel.uiImage = image
                        isCameraActive = false
                    }, isCameraReady: $isCameraReady)
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                }
            }
        }
    }


    
    var imageView: some View {
        Group {
            if let uiImage = viewModel.uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color
                    .gray
                    .aspectRatio(contentMode: .fit)
            }
        }
        .overlay(
            buildMaskImage(mask: viewModel.combinedMaskImage)
                .opacity(showMasks ? 0.5 : 0))
        .overlay(
            DetectionViewRepresentable(
                predictions: $viewModel.predictions)
            .opacity(showBoxes ? 1 : 0))
        .frame(maxHeight: 400)
    }
    
    var fixedImageView: some View {
        Group {
            if let uiImage = viewModel.uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .antialiased(false)
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)

            } else {
                Color
                    .gray
                    .aspectRatio(contentMode: .fit)
            }
        }
        .overlay(
            buildMaskImage(mask: viewModel.combinedMaskImage)
                .opacity(showMasks ? 0.5 : 0))
        .overlay(
            DetectionViewRepresentable(
                predictions: $viewModel.predictions)
            .opacity(showBoxes ? 1 : 0))
        .frame(width: 960, height: 960)      }
    
    var settingsForm: some View {
        Form {
            Section {
                PhotosPicker(
                    "Pick Image",
                    selection: $viewModel.imageSelection,
                    matching: .images)
                Button("Open Camera") {
                    isCameraActive = true

                }
                SaveButtonView(buttonTitle: "Save Image" ) {
                    if (viewModel.processing || viewModel.uiImage == nil) {return;};
                    let size = CGSize(width: 960, height: 960)
                    if let renderedImage = convertViewToImage(swiftUIView: fixedImageView, size: size) {

                        UIImageWriteToSavedPhotosAlbum(renderedImage, nil, nil, nil)
                        print("Image saved successfully!")
                    } else {
                        print("Failed to render image.")
                    }

                }
            }
            
            Section {
                Picker(
                    "Framework",
                    selection: $viewModel.selectedDetector
                ) {
                    
                    Text("PyTorch")
                        .tag(0)
                    Text("TFLite")
                        .tag(1)
                    Text("Vision")
                        .tag(2)
                    Text("CoreML")
                        .tag(3)
                }
                .pickerStyle(.segmented)
                
                VStack {
                    Slider(value: $viewModel.confidenceThreshold, in: 0...1)
                    Text("Confidence threshold: \(viewModel.confidenceThreshold, specifier: "%.2f")")
                }
                VStack {
                    Slider(value: $viewModel.iouThreshold, in: 0...1)
                    Text("IoU threshold: \(viewModel.iouThreshold, specifier: "%.2f")")
                }
                VStack {
                    Slider(value: $viewModel.maskThreshold, in: 0...1)
                    Text("Mask threshold: \(viewModel.maskThreshold, specifier: "%.2f")")
                }
                
                Button {
                    Task {
                        await viewModel.runInference()
                    }
                } label: {
                    HStack {
                        Text(viewModel.status?.message ?? "Run inference")
                        Spacer()
                        if viewModel.processing {
                            ProgressView()
                        }
                    }
                }.disabled(viewModel.processing || viewModel.uiImage == nil)
                
                Button(action: {
                    openWebPage()
                }) {
                    Text("Visit Our Website")
                        .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                }
            }
            
            Section {
                if !viewModel.maskPredictions.isEmpty {
                    Toggle("Show boxes:", isOn: $showBoxes)
                    Toggle("Show masks:", isOn: $showMasks)
                    Button("Clear predictions") {
                        viewModel.predictions = []
                        viewModel.maskPredictions = []
                        viewModel.combinedMaskImage = nil
                    }
                    Button("Show all masks") {
                        presentMaskPreview.toggle()
                    }
                    
                    
                }
                
            }
        }
    }

    @ViewBuilder private func buildMaskImage(mask: UIImage?) -> some View {
        if let mask {
            Image(uiImage: mask)
                .resizable()
                .antialiased(false)
                .interpolation(.none)
        }
    }
    
    @ViewBuilder private func buildMasksSheet() -> some View {
        ScrollView {
            LazyVStack(alignment: .center, spacing: 8) {
                ForEach(Array(viewModel.maskPredictions.enumerated()), id: \.offset) { index, maskPrediction in
                    VStack(alignment: .center) {
                        Group {
                            if let maskImg = maskPrediction.getMaskImage() {
                                Image(uiImage: maskImg)
                                    .resizable()
                                    .antialiased(false)
                                    .interpolation(.none)
                                    .aspectRatio(contentMode: .fit)
                                    .background(Color.black)
                                
                                SaveButtonView(buttonTitle: "Save mask") {
                                    
                                    saveImageToGallery(maskImg)
                                }

                            
                            } else {
                                let _ = print("maskImg is nil")
                            }
                        }
                        Divider()
                    }.frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
        }
    }
    
    private func saveImageToGallery(_ image: UIImage) {
        
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
        
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            } else {
                
                DispatchQueue.main.async {
                    
                    print("Không có quyền truy cập thư viện ảnh")
                }
            }
        }
    }

    private func saveImageToLibrary() {
        guard let image = viewModel.combinedMaskImage else {
                    print("No image to save")
                    return
                }

        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        
        print("Image saved to the library!")
    }
    
    func openWebPage() {
        if let url = URL(string: "https://www.narobit.com") {
            UIApplication.shared.open(url)
        }
    }
    
    func convertViewToImageWithFixedSize<T: View>(
        swiftUIView: T,
        canvasSize: CGSize,
        imageSize: CGSize
    ) -> UIImage? {
        // Tạo hosting controller cho SwiftUI view
        let hostingController = UIHostingController(rootView: swiftUIView)
        let view = hostingController.view
        view?.bounds = CGRect(origin: .zero, size: canvasSize)
        view?.backgroundColor = .clear

        // Tạo renderer
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { context in
            // Đặt nền canvas màu trắng
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            // Tính toán tỷ lệ và vị trí để vẽ ảnh gốc (uiImage)
            let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
            let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let origin = CGPoint(
                x: (canvasSize.width - scaledImageSize.width) / 2,
                y: (canvasSize.height - scaledImageSize.height) / 2
            )

            // Vẽ ảnh gốc tại vị trí và kích thước đã tính toán
            if let currentImageView = view {
                currentImageView.layer.render(in: context.cgContext)
            }
        }
    }



}


func convertViewToImage<V: View>(swiftUIView: V, size: CGSize) -> UIImage? {
    
    let hostingController = UIHostingController(rootView: swiftUIView)
    
    
    hostingController.view.frame = CGRect(origin: .zero, size: size)
    
    
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
        hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
    }
}

struct SaveButtonView: View {
    @State private var isLoading = false
    @State private var isSaveDone = false
    @State private var isButtonDisabled = false
    
    let buttonTitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            handleSaveButton()
        }) {
            if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.gray)
                }
                .background(Color.white)
                .cornerRadius(5)
            } else if isSaveDone {
                Text("Save Done")
                    .foregroundColor(.green)
                    .background(Color.white)
                    .cornerRadius(5)
            } else {
                Text(buttonTitle)
                    .foregroundColor(.blue)
                    .background(Color.white)
                    .cornerRadius(5)
            }
        }
        .disabled(isLoading || isSaveDone || isButtonDisabled)  //
    }
    
    private func handleSaveButton() {
        isLoading = true
        isButtonDisabled = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            
            action()

            isLoading = false
            isSaveDone = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSaveDone = false
                isButtonDisabled = false
            }
        }
    }
}

