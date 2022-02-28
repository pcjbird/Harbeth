//
//  C7FilterCollector.swift
//  Harbeth
//
//  Created by Condy on 2022/2/25.
//

import AVFoundation
import CoreVideo
import MetalKit

/// 相机数据采集器，在主线程返回图片
/// The camera data collector returns pictures in the main thread.
public final class C7FilterCollector: CALayer {
    
    public var groupFilters: [C7FilterProtocol]
    public lazy var captureSession: AVCaptureSession = AVCaptureSession()
    
    private var textureCache: CVMetalTextureCache?
    private let callback: C7FilterImageCallback
    
    public init(callback: @escaping C7FilterImageCallback) {
        self.callback = callback
        self.groupFilters = []
        super.init()
        setupCaptureSession()
        #if !targetEnvironment(simulator)
        // 生成全局纹理缓存，Generate a global texture cache.
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, Device.device(), nil, &textureCache)
        #endif
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCaptureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
        guard let camera = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: camera) else {
                  return
              }
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        // video output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.collector.metal"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        if let connection = videoOutput.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!
        }
        captureSession.commitConfiguration()
    }
}

extension C7FilterCollector: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        if let image = pixelBuffer.mt.convert2C7Image(textureCache: textureCache, filters: groupFilters) {
            DispatchQueue.main.sync { callback(image) }
        }
    }
}
