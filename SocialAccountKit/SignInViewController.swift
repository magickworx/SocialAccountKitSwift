/*****************************************************************************
 *
 * FILE:	SignInViewController.swift
 * DESCRIPTION:	SocialAccountKit: View Controller for Sign In Service
 * DATE:	Fri, Sep 22 2017
 * UPDATED:	Fri, Sep 22 2017
 * AUTHOR:	Kouichi ABE (WALL) / 阿部康一
 * E-MAIL:	kouichi@MagickWorX.COM
 * URL:		http://www.MagickWorX.COM/
 * CHECKER:     http://quonos.nl/oauthTester/
 * COPYRIGHT:	(c) 2017 阿部康一／Kouichi ABE (WALL), All rights reserved.
 * LICENSE:
 *
 *  Copyright (c) 2017 Kouichi ABE (WALL) <kouichi@MagickWorX.COM>,
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *   1. Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *
 *   2. Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *   THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 *   ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 *   THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 *   PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
 *   LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *   INTERRUPTION)  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *   ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 *   THE POSSIBILITY OF SUCH DAMAGE.
 *
 * $Id: AppDelegate.m,v 1.6 2017/04/12 09:59:00 kouichi Exp $
 *
 *****************************************************************************/

import Foundation
import UIKit
import WebKit

public class SAKSignInViewController: UIViewController
{
  public var callback: String = "swift-oauth://callback"

  public internal(set) var requestURL: URL?

  var configuration = WKWebViewConfiguration()
  var webView: WKWebView?

  required public init(coder aDecoder: NSCoder) {
    fatalError("NSCoding not supported")
  }

  init() {
    super.init(nibName: nil, bundle: nil)
  }

  public convenience init(with url: URL, configuration: WKWebViewConfiguration? = nil) {
    self.init()
    self.requestURL = url
    if let configuration = configuration {
      self.configuration = configuration
    }
  }

  deinit {
    if let webView = self.webView, webView.isLoading {
      webView.stopLoading()
    }
  }

  override public func loadView() {
    super.loadView()

    self.edgesForExtendedLayout = []
    self.extendedLayoutIncludesOpaqueBars = true
    self.automaticallyAdjustsScrollViewInsets = false

    self.view.backgroundColor = .white
    self.view.autoresizesSubviews = true
    self.view.autoresizingMask	= [ .flexibleWidth, .flexibleHeight ]

    var frame: CGRect = self.view.bounds
    let statusBarHeight: CGFloat = UIApplication.shared.statusBarFrame.size.height
    frame.origin.y    += statusBarHeight
    frame.size.height -= statusBarHeight

    if let navBarHeight: CGFloat = self.navigationController?.navigationBar.bounds.size.height {
      frame.origin.y    += navBarHeight
      frame.size.height -= navBarHeight
    }

    webView = WKWebView(frame: frame, configuration: configuration)
    webView?.autoresizingMask = [ .flexibleWidth, .flexibleHeight ]
    webView?.navigationDelegate = self
    self.view.addSubview(webView!)
  }

  override public func viewDidLoad() {
    super.viewDidLoad()

    if let webView = self.webView, let url = self.requestURL {
      var request = URLRequest(url: url)
      request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
      webView.load(request)
    }
  }

  override public func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
}

extension SAKSignInViewController: WKNavigationDelegate
{
  public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if let callbackURL = navigationAction.request.url {
      let urlString = callbackURL.absoluteString
      if urlString.hasPrefix(callback) {
        self.dismiss(animated: true, completion: {
          NotificationCenter.default.post(name: .OAuthDidAuthenticateRequestToken, object: nil, userInfo: [
            OAuthAuthenticateCallbackURLKey: callbackURL
          ])
        })
      }
    }
    decisionHandler(.allow)
  }
}
