//
//  BlurHashDecoder.swift
//  FNLPinterestCompositionallayout
//
//  Created by Fenominall on 6/13/25.
//

import UIKit
import CoreGraphics

//## Standalone decoder and encoder
//
//[BlurHashDecode.swift](BlurHashDecode.swift) and [BlurHashEncode.swift](BlurHashEncode.swift) contain a decoder
//and encoder for BlurHash to and from `UIImage`. Both files are completeiy standalone, and can simply be copied into your
//project directly.
//
//### Decoding
//
//[BlurHashDecode.swift](BlurHashDecode.swift) implements the following extension on `UIImage`:
//
//    public convenience init?(blurHash: String, size: CGSize, punch: Float = 1)
//
//This creates a UIImage containing the placeholder image decoded from the BlurHash string, or returns nil if decoding failed.
//The parameters are:
//
//* `blurHash` - A string containing the BlurHash.
//* `size` - The requested output size. You should keep this small, and let UIKit scale it up for you. 32 pixels wide is plenty.
//* `punch` - Adjusts the contrast of the output image. Tweak it if you want a different look for your placeholders.
//*/

protocol BlurHashDecoding {
    func decode(blurHash: String, size: CGSize, punch: Float) -> UIImage?
}

final class BlurHashDecoder: BlurHashDecoding {
    
        func decode(blurHash: String, size: CGSize, punch: Float = 1) -> UIImage? {
        guard blurHash.count >= 6 else { return nil }
        
        let sizeFlag = String(blurHash[0]).decode83()
        let numY = (sizeFlag / 9) + 1
        let numX = (sizeFlag % 9) + 1
        
        let quantisedMaximumValue = String(blurHash[1]).decode83()
        let maximumValue = Float(quantisedMaximumValue + 1) / 166
        
        guard blurHash.count == 4 + 2 * numX * numY else { return nil }
        
        let colours: [(Float, Float, Float)] = (0 ..< numX * numY).map { i in
            if i == 0 {
                let value = String(blurHash[2 ..< 6]).decode83()
                return decodeDC(value)
            } else {
                let value = String(blurHash[4 + i * 2 ..< 4 + i * 2 + 2]).decode83()
                return decodeAC(value, maximumValue: maximumValue * punch)
            }
        }
        
        return createImage(from: colours, size: size, numX: numX, numY: numY)
    }
    
    // MARK: - Private Helpers
    
    private func createImage(from colours: [(Float, Float, Float)], size: CGSize, numX: Int, numY: Int) -> UIImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerRow = width * 3
        
        guard let data = CFDataCreateMutable(kCFAllocatorDefault, bytesPerRow * height) else { return nil }
        CFDataSetLength(data, bytesPerRow * height)
        guard let pixels = CFDataGetMutableBytePtr(data) else { return nil }
        
        for y in 0 ..< height {
            for x in 0 ..< width {
                var r: Float = 0
                var g: Float = 0
                var b: Float = 0
                
                for j in 0 ..< numY {
                    for i in 0 ..< numX {
                        let basis = cos(Float.pi * Float(x) * Float(i) / Float(width)) * cos(Float.pi * Float(y) * Float(j) / Float(height))
                        let colour = colours[i + j * numX]
                        r += colour.0 * basis
                        g += colour.1 * basis
                        b += colour.2 * basis
                    }
                }
                
                pixels[3 * x + 0 + y * bytesPerRow] = UInt8(linearTosRGB(r))
                pixels[3 * x + 1 + y * bytesPerRow] = UInt8(linearTosRGB(g))
                pixels[3 * x + 2 + y * bytesPerRow] = UInt8(linearTosRGB(b))
            }
        }
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        guard let provider = CGDataProvider(data: data) else { return nil }
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 24,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func decodeDC(_ value: Int) -> (Float, Float, Float) {
        let intR = value >> 16
        let intG = (value >> 8) & 255
        let intB = value & 255
        return (sRGBToLinear(intR), sRGBToLinear(intG), sRGBToLinear(intB))
    }
    
    private func decodeAC(_ value: Int, maximumValue: Float) -> (Float, Float, Float) {
        let quantR = value / (19 * 19)
        let quantG = (value / 19) % 19
        let quantB = value % 19
        
        return (
            signPow((Float(quantR) - 9) / 9, 2) * maximumValue,
            signPow((Float(quantG) - 9) / 9, 2) * maximumValue,
            signPow((Float(quantB) - 9) / 9, 2) * maximumValue
        )
    }
    
    private func signPow(_ value: Float, _ exp: Float) -> Float {
        copysign(pow(abs(value), exp), value)
    }
    
    private func linearTosRGB(_ value: Float) -> Int {
        let v = max(0, min(1, value))
        if v <= 0.0031308 { return Int(v * 12.92 * 255 + 0.5) }
        else { return Int((1.055 * pow(v, 1 / 2.4) - 0.055) * 255 + 0.5) }
    }
    
    private func sRGBToLinear<Type: BinaryInteger>(_ value: Type) -> Float {
        let v = Float(Int64(value)) / 255
        if v <= 0.04045 { return v / 12.92 }
        else { return pow((v + 0.055) / 1.055, 2.4) }
    }
    
}

// MARK: - String Decoding Extension

private let decodeCharacters: [String: Int] = {
    let encodeCharacters = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~"
    var dict = [String: Int]()
    for (index, char) in encodeCharacters.enumerated() {
        dict[String(char)] = index
    }
    return dict
}()

private extension String {
    func decode83() -> Int {
        var value = 0
        for char in self {
            if let digit = decodeCharacters[String(char)] {
                value = value * 83 + digit
            }
        }
        return value
    }
    
    subscript(offset: Int) -> Character {
        self[index(startIndex, offsetBy: offset)]
    }
    
    subscript(bounds: CountableClosedRange<Int>) -> Substring {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[start...end]
    }
    
    subscript(bounds: CountableRange<Int>) -> Substring {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[start..<end]
    }
}

