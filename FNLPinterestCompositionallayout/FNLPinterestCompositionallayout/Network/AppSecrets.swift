//
//  AppSecrets.swift
//  FNLPinterestCompositionallayout
//
//  Created by Fenominall on 6/13/25.
//

import Foundation

enum AppSecrets {
    static var unsplashAccessKey: String {
        Bundle.main.infoDictionary?["UNSPLASH_ACCESS_KEY"] as? String ?? ""
    }
    
    static var unsplashSecretKey: String {
        Bundle.main.infoDictionary?["UNSPLASH_SECRET_KEY"] as? String ?? ""
    }
}

