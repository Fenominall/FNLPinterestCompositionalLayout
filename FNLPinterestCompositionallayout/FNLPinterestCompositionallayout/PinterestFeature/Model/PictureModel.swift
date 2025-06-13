//
//  PictureModel.swift
//  FNLPinterestCompositionallayout
//
//  Created by Fenominall on 6/13/25.
//

import Foundation

struct PictureModel: Sendable {
    
    // MARK: - URLs
    struct URls {
        let raw, full, regular, small, thumb: String
    }
    
    let description: String?
    let urls: URls
    let width: CGFloat
    let height: CGFloat
    let blurhHash: String
    
    var blurHashSize: CGSize {
        .init(width: width/100, height: height/100)
    }
}

extension PictureModel: Ratioable {
    var ratio: CGFloat {
        width / height
    }
}
