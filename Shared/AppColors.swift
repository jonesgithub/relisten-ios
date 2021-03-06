//
//  AppColors.swift
//  Relisten
//
//  Created by Alec Gorge on 3/7/17.
//  Copyright © 2017 Alec Gorge. All rights reserved.
//

import UIKit
import AGAudioPlayer
import ChameleonFramework

public class _AppColors : Equatable {
    
    public let primary: UIColor
    public let textOnPrimary: UIColor
    public let highlight : UIColor
    
    public let soundboard: UIColor
    public let remaster: UIColor
    
    public let mutedText: UIColor
    public let lightGreyBackground: UIColor
    
    private let complements : [UIColor]
    
    public static func == (lhs: _AppColors, rhs: _AppColors) -> Bool {
        return lhs === rhs
    }
    
    public init(primary: UIColor, textOnPrimary: UIColor, highlight: UIColor? = nil, soundboard: UIColor, remaster: UIColor, mutedText: UIColor, lightGreyBackground: UIColor) {
        self.primary = primary
        self.textOnPrimary = textOnPrimary
        self.soundboard = soundboard
        self.remaster = remaster
        self.mutedText = mutedText
        self.lightGreyBackground = lightGreyBackground
        
        self.complements = NSArray(ofColorsWith: .complementary, using: self.primary, withFlatScheme: false) as! [UIColor]
        
        if let highlight = highlight {
            self.highlight = highlight
        } else {
            self.highlight = self.complements[0]
        }
    }
}

public let RelistenAppColors = _AppColors(
    primary: UIColor(red:0, green:0.616, blue:0.753, alpha:1),
    textOnPrimary: UIColor.white,
    soundboard: UIColor(red:0.0/255.0, green:128.0/255.0, blue:95.0/255.0, alpha:1.0),
    remaster: UIColor(red:0, green:0.616, blue:0.753, alpha:1),
    mutedText: UIColor.gray,
    lightGreyBackground: UIColor(white: 0.97, alpha: 1.0)
)

public let RelistenPlayerColors = AGAudioPlayerColors(main: RelistenAppColors.primary, accent: RelistenAppColors.textOnPrimary)

public let PhishODAppColors = _AppColors(
    primary: UIColor(red:0, green:128.0/255.0, blue:95.0/255.0, alpha:1),
    textOnPrimary: UIColor.white,
    soundboard: UIColor(red:0.0/255.0, green:128.0/255.0, blue:95.0/255.0, alpha:1.0),
    remaster: UIColor(red:0, green:0.616, blue:0.753, alpha:1),
    mutedText: UIColor.gray,
    lightGreyBackground: UIColor(white: 0.97, alpha: 1.0)
)

public let PhishODPlayerColors = AGAudioPlayerColors(main: PhishODAppColors.primary, accent: PhishODAppColors.textOnPrimary)


public var AppColors = RelistenAppColors

public func AppColors_SwitchToPhishOD(_ viewController: UINavigationController?) {
    if AppColors != PhishODAppColors {
        AppColors = PhishODAppColors
        
        RelistenApp.sharedApp.setupAppearance(viewController)
        
        PlaybackController.sharedInstance.viewController.applyColors(PhishODPlayerColors)
    }
}

public func AppColors_SwitchToRelisten(_ viewController: UINavigationController?) {
    if AppColors != RelistenAppColors {
        AppColors = RelistenAppColors
        
        RelistenApp.sharedApp.setupAppearance(viewController)
        
        PlaybackController.sharedInstance.viewController.applyColors(RelistenPlayerColors)
    }
}
