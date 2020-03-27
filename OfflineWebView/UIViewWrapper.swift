//
//  UIViewWrapper.swift
//  OfflineWebView
//
//  Created by Ernesto Elsäßer on 27.03.20.
//  Copyright © 2020 Ernesto Elsaesser. All rights reserved.
//

import SwiftUI
  
struct UIViewWrapper: UIViewRepresentable {
    
    let view: UIView
    
    func makeUIView(context: Context) -> UIView  {
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
