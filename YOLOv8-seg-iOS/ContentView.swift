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
    @State private var zoomFactor: CGFloat = 1.0


        
    
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

            // Camera view với các thành phần UI
            if isCameraActive {
                ZStack {
                    // Camera view
                    CameraView(imageHandler: { image in
                        viewModel.uiImage = image
                        isCameraActive = false
                    }, isCameraReady: $isCameraReady, zoomFactor: $zoomFactor)
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                    VStack {
                        HStack {
                            Text("Zoom: \(String(format: "%.1fx", zoomFactor))")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                                .padding(.leading)
                            Spacer()
                        }
                        Spacer()
                    }

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
                    
                    SaveButtonView(buttonTitle: "Save Image") {

                        let size = CGSize(width: 400, height: 400)
                        if let renderedImage = convertViewToImage(swiftUIView: imageView, size: size) {

                            UIImageWriteToSavedPhotosAlbum(renderedImage, nil, nil, nil)
                            print("Image saved successfully!")
                        } else {
                            print("Failed to render image.")
                        }
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
        // Kiểm tra quyền truy cập thư viện ảnh
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                // Lưu ảnh vào thư viện ảnh
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
        .disabled(isButtonDisabled) 
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
