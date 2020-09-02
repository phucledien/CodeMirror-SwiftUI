//
//  CodeView.swift
//  
//
//  Created by Anthony Fernandez on 7/29/20.
//  Copyright © 2020 marshallino16. All rights reserved.
//

import Foundation
import SwiftUI
import WebKit


#if os(OSX)
typealias RepresentableView = NSViewRepresentable
#elseif os(iOS)
typealias RepresentableView = UIViewRepresentable
#endif



// MARK: - CodeView

public struct CodeView: RepresentableView {
  
  public var theme: CodeViewTheme
  public var code: String
  public var mode: Mode
  
  var onLoadSuccess: (() -> ())?
  var onLoadFail: ((Error) -> ())?
  var onContentChange: ((String) -> ())?
  
  
  public init(theme: CodeViewTheme, code: String, mode: Mode) {
    self.code = code
    self.mode = mode
    self.theme = theme
  }
  
  
  // MARK: - Life Cycle
  
  #if os(OSX)
  public func makeNSView(context: Context) -> WKWebView {
    createWebView(context)
  }
  #elseif os(iOS)
  public func makeUIView(context: Context) -> WKWebView {
    createWebView(context)
  }
  #endif
  
  #if os(OSX)
  public func updateNSView(_ codeMirrorView: WKWebView, context: Context) {
    
    updateWebView(context)
  }
  #elseif os(iOS)
  public func updateUIView(_ uiView: WKWebView, context: Context) {
    
    updateWebView(context)
  }
  #endif
  
  public func makeCoordinator() -> CodeViewController {
    CodeViewController(self)
  }
  
}



// MARK: - Public API

extension CodeView {
  
  public func onLoadSuccess(_ action: @escaping (() -> ())) -> Self {
    var copy = self
    copy.onLoadSuccess = action
    return copy
  }
  
  public func onLoadFail(_ action: @escaping ((Error) -> ())) -> Self {
    var copy = self
    copy.onLoadFail = action
    return copy
  }
  
  public func onContentChange(_ action: @escaping ((String) -> ())) -> Self {
    var copy = self
    copy.onContentChange = action
    return copy
  }
}



// MARK: - Private API

extension CodeView {
  
  private func createWebView(_ context: Context) -> WKWebView {
    let preferences = WKPreferences()
    preferences.javaScriptEnabled = true
    
    let userController = WKUserContentController()
    userController.add(context.coordinator, name: CodeViewRPC.isReady)
    userController.add(context.coordinator, name: CodeViewRPC.textContentDidChange)
    
    let configuration = WKWebViewConfiguration()
    configuration.preferences = preferences
    configuration.userContentController = userController
    
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    #if os(OSX)
    webView.setValue(false, forKey: "drawsBackground")
    webView.allowsMagnification = false
    #endif
    
    let codeMirrorBundle = try! Bundle.codeMirrorBundle()
    guard let indexPath = codeMirrorBundle.path(forResource: "index", ofType: "html") else {
      fatalError("CodeMirrorBundle is missing")
    }
    
    let data = try! Data(contentsOf: URL(fileURLWithPath: indexPath))
    
    webView.load(data, mimeType: "text/html", characterEncodingName: "utf-8", baseURL: codeMirrorBundle.resourceURL!)
    
    context.coordinator.setThemeName(theme.rawValue)
    context.coordinator.setTabInsertsSpaces(true)
    context.coordinator.setWebView(webView)
    
    context.coordinator.setMimeType(mode.mimeType)
    context.coordinator.setContent(code)
    
    return webView
  }
  
  fileprivate func updateWebView(_ context: CodeView.Context) {
    updateWhatsNecessary(elementGetter: context.coordinator.getMimeType(_:), elementSetter: context.coordinator.setMimeType(_:), currentElementState: self.mode.mimeType)
    
    updateWhatsNecessary(elementGetter: context.coordinator.getContent(_:), elementSetter: context.coordinator.setContent(_:), currentElementState: self.code)
    
    context.coordinator.setThemeName(self.theme.rawValue)
  }
  
  func updateWhatsNecessary(elementGetter: (JavascriptCallback?) -> Void,
                            elementSetter: @escaping (_ elementState: String) -> Void,
                            currentElementState: String) {
    elementGetter({ result in
      
      switch result {
      case .success(let resp):
        guard let previousElementState = resp as? String else { return }
        
        if previousElementState != currentElementState {
          elementSetter(currentElementState)
        }
        
        return
      case .failure(let error):
        print("Error \(error)")
        return
      }
    })
  }
  
}