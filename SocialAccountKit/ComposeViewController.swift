/*****************************************************************************
 *
 * FILE:	ComposeViewController.swift
 * DESCRIPTION:	SocialAccountKit: View Controller to Compose Tweet
 * DATE:	Sun, Oct  8 2017
 * UPDATED:	Tue, Jan  5 2021
 * AUTHOR:	Kouichi ABE (WALL) / 阿部康一
 * E-MAIL:	kouichi@MagickWorX.COM
 * URL:		http://www.MagickWorX.COM/
 * CHECKER:     http://quonos.nl/oauthTester/
 * COPYRIGHT:	(c) 2017-2021 阿部康一／Kouichi ABE (WALL), All rights reserved.
 * LICENSE:
 *
 *  Copyright (c) 2017-2021 Kouichi ABE (WALL) <kouichi@MagickWorX.COM>,
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
 *****************************************************************************/

import Foundation
import UIKit
import QuartzCore

public enum SAKComposeViewControllerResult
{
  case cancelled
  case done([String:Any]?)
  case error(Error)
}

public typealias SAKComposeViewControllerCompletionHandler = (SAKComposeViewControllerResult) -> Void

public final class SAKComposeViewController: UIViewController
{
  public class func isAvailable(for accountType: SAKAccountType) -> Bool {
    switch accountType.identifier {
      case .twitter, .facebook:
        guard let accounts = SAKAccountStore.shared.accounts(with: accountType)  else { return false }
        return (accounts.count > 0)
      default: return false
    }
  }

  public var completionHandler: SAKComposeViewControllerCompletionHandler = {
    (result) in
    switch result {
      case .cancelled: break
      case .done(_): break
      case .error(_): break
    }
  }

  private let kLastAccountNameKey: String = "SAKLastAccountNameKey"
  private let accountStore: SAKAccountStore = SAKAccountStore.shared
  private var accounts = [SAKAccount]()
  private var account: SAKAccount? = nil

  private var accountType: SAKAccountType? = nil {
    didSet {
      if let type = accountType {
        loadAccounts(with: type)
      }
    }
  }

  private enum ComposeViewMode {
    case editing
    case selecting
  }

  private var viewMode: ComposeViewMode = .editing {
    didSet {
      switch viewMode {
        case .editing:
          textView.becomeFirstResponder()
        case .selecting:
          textView.resignFirstResponder()
      }
    }
  }

  private lazy var sheetView: UIView = {
    let sheetView: UIView = UIView(frame: .zero)
    sheetView.backgroundColor = .white
    sheetView.layer.cornerRadius = 8.0
    sheetView.autoresizesSubviews = true
    sheetView.autoresizingMask = [ .flexibleWidth, .flexibleHeight ]
    return sheetView
  }()

  private lazy var contentView: UIView = {
    let contentView: UIView = UIView(frame: .zero)
    contentView.backgroundColor = .clear
    contentView.autoresizesSubviews = true
    contentView.autoresizingMask = [ .flexibleWidth, .flexibleHeight ]
    return contentView
  }()

  private lazy var navigationBar: UINavigationBar = {
    let navigationBar: UINavigationBar = UINavigationBar(frame: .zero)
    navigationBar.pushItem(sheetItem, animated: false)
    navigationBar.titleTextAttributes = [
      .foregroundColor: UIColor.black
    ]
    navigationBar.barTintColor = .white
    if let image = backIndicator() {
      navigationBar.backIndicatorImage = image
      navigationBar.backIndicatorTransitionMaskImage = image
    }
    navigationBar.delegate = self
    return navigationBar
  }()

  private lazy var cancelItem: UIBarButtonItem = {
    let cancelItem: UIBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(handleCancel))
    if let color = self.view.tintColor {
      cancelItem.setTitleTextAttributes([ .foregroundColor: color ], for: [])
    }
    return cancelItem
  }()

  private lazy var postItem: UIBarButtonItem = {
    let postItem: UIBarButtonItem = UIBarButtonItem(title: "Post", style: .done, target: self, action: #selector(handlePost))
    if let color = self.view.tintColor {
      postItem.setTitleTextAttributes([ .foregroundColor: color ], for: [])
    }
    postItem.setTitleTextAttributes([
      .foregroundColor: UIColor.lightGray
    ], for: [.disabled])
    return postItem
  }()

  private lazy var sheetItem: UINavigationItem = {
    let sheetItem: UINavigationItem = {
      if let type = accountType {
        return UINavigationItem(title: type.description)
      }
      return UINavigationItem()
    }()
    sheetItem.hidesBackButton = false
    sheetItem.leftBarButtonItem = cancelItem
    sheetItem.rightBarButtonItem = postItem
    sheetItem.backBarButtonItem = {
      let backItem = UIBarButtonItem()
      if let color = self.view.tintColor {
        backItem.setTitleTextAttributes([ .foregroundColor: color ], for: [])
      }
      if let accountType = self.accountType {
        backItem.title = accountType.description
      }
      return backItem
    }()
    return sheetItem
  }()

  private lazy var composeView: UIView = UIView(frame: .zero)

  private lazy var textView: UITextView = {
    let textView: UITextView = UITextView(frame: .zero)
    textView.font = UIFont.systemFont(ofSize: 18.0)
    textView.delegate = self
    return textView
  }()

  private lazy var footerView: UIView = UIView(frame: .zero)

  private lazy var charactersLabel: UILabel = {
    let charactersLabel: UILabel = UILabel(frame: .zero)
    charactersLabel.font = UIFont.systemFont(ofSize: 12.0)
    charactersLabel.textColor = .lightGray
    charactersLabel.textAlignment = .left
    return charactersLabel
  }()

  private let kTableViewCellIdentifier: String = "UITableViewCellReusableIdentifier"
  private lazy var tableView: UITableView = {
    let tableView: UITableView = UITableView(frame: .zero)
    tableView.delegate = self
    tableView.dataSource = self
    tableView.separatorStyle = .none
    tableView.autoresizingMask = [ .flexibleWidth, .flexibleHeight ]
    return tableView
  }()

  private let mediaURLLength: Int = 23 // XXX: 添付画像などはどう処理する？
  private let maxTweetLength: Int = 140
  private var topMargin: CGFloat = 40.0

  private var numberOfChars: Int = 0 {
    didSet {
      if let accountType = self.accountType {
        accountType.with {
          [unowned self] (service) in
          let textLen = self.numberOfChars
          let hasText = textLen > 0
          switch service {
            case .twitter:
              let remaining = self.maxTweetLength - textLen
              let isValid: Bool = (remaining >= 0 && hasText)
              self.charactersLabel.text = "\(remaining)"
              self.postItem.isEnabled = isValid
              self.charactersLabel.textColor
                = isValid && remaining > self.mediaURLLength
                ? .lightGray : remaining == self.maxTweetLength ? .darkGray
                                                                : .red
            default:
              self.charactersLabel.text = "\(textLen)"
              self.postItem.isEnabled = hasText
          }
        }
      }
    }
  }

  required public init(coder aDecoder: NSCoder) {
    fatalError("NSCoding not supported")
  }

  override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: Bundle!) {
    super.init(nibName: nil, bundle: nil)

    self.modalPresentationStyle = .custom // XXX: 背景の透明化を有効にする
  }

  public convenience init(for accountType: SAKAccountType) {
    self.init(nibName: nil, bundle: nil)

    defer {
      self.accountType = accountType
    }
  }

  override public func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  override public func loadView() {
    super.loadView()

    self.edgesForExtendedLayout = []
    self.extendedLayoutIncludesOpaqueBars = true

    self.view.backgroundColor = UIColor(white: 0.0, alpha: 0.2)
    self.view.autoresizesSubviews = true
    self.view.autoresizingMask = [ .flexibleWidth, .flexibleHeight ]

    self.view.addSubview(sheetView)

    contentView.addSubview(navigationBar)
    contentView.addSubview(composeView)
    sheetView.addSubview(contentView)

    composeView.addSubview(textView)

    footerView.addSubview(charactersLabel)
    composeView.addSubview(footerView)

    contentView.addSubview(tableView)
  }

  override public func viewDidLoad() {
    super.viewDidLoad()

    self.numberOfChars = 0
  }

  override public func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    if let name = UserDefaults.standard.string(forKey: kLastAccountNameKey),
       let account = accounts.filter({ $0.username == name }).first {
      self.account = account
      tableView.reloadData()
    }
    else if let account = accounts.first {
      self.account = account
      tableView.reloadData()
    }
  }

  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    textView.becomeFirstResponder()
  }

  override public func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    if textView.isFirstResponder {
      textView.resignFirstResponder()
    }
  }

  override public func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    let  width: CGFloat = self.view.bounds.size.width
    let height: CGFloat = self.view.bounds.size.height

    let s: CGFloat = 8.0 // 上下余白
    let m: CGFloat = 30.0
    var x: CGFloat = m
    var y: CGFloat = topMargin
    var w: CGFloat = width - x * 2.0
    var h: CGFloat = floor(((height * 0.5) - y) * 0.8) + s
    sheetView.frame = CGRect(x: x, y: y, width: w, height: h)
    sheetView.roundCorners()
    sheetView.layer.masksToBounds = true

    x  = 0.0
    y  = 0.0
    h -= s
    contentView.frame = CGRect(x: x, y: y, width: w, height: h)

    let  contentWidth: CGFloat = contentView.frame.size.width
    let contentHeight: CGFloat = contentView.frame.size.height

    let headerHeight: CGFloat = 44.0
    let footerHeight: CGFloat = 24.0
    let tableHeight: CGFloat = 32.0
    let composeHeight: CGFloat = contentHeight - (headerHeight + tableHeight)

    x = 0.0
    y = 0.0
    w = contentWidth
    h = headerHeight
    navigationBar.frame = CGRect(x: x, y: y, width: w, height: h)

    y += h
    h  = composeHeight
    composeView.frame = CGRect(x: x, y: y, width: w, height: h)

    y += h
    h  = tableHeight
    tableView.frame = CGRect(x: x, y: y, width: w, height: h)
    tableView.rowHeight = tableHeight


    x = 0
    y = 0
    h = composeHeight - footerHeight
    textView.frame = CGRect(x: x, y: y, width: w, height: h)

    y += h
    h  = footerHeight
    footerView.frame = CGRect(x: x, y: y, width: w, height: h)

    charactersLabel.frame = footerView.bounds.insetBy(dx: 8.0, dy: 4.0)

    x = 0.0
    y = headerHeight - 1.0
    w = contentWidth
    h = 1.0
    var bottomLayer = CALayer()
    bottomLayer.frame = CGRect(x: x, y: y, width: w, height: h)
    bottomLayer.backgroundColor = UIColor.lightGray.cgColor
    navigationBar.layer.addSublayer(bottomLayer)

    y = footerHeight - 1.0
    bottomLayer = CALayer()
    bottomLayer.frame = CGRect(x: x, y: y, width: w, height: h)
    bottomLayer.backgroundColor = UIColor.lightGray.cgColor
    footerView.layer.addSublayer(bottomLayer)
  }
}

extension SAKComposeViewController
{
  private func dismiss(with result: SAKComposeViewControllerResult) {
    DispatchQueue.main.async {
      [weak self] in
      if let weakSelf = self {
        weakSelf.dismiss(animated: true, completion: {
          weakSelf.completionHandler(result)
        })
      }
    }
  }

  @objc func handleCancel(_ item: UIBarButtonItem) {
    dismiss(with: .cancelled)
  }

  @objc func handlePost(_ item: UIBarButtonItem) {
    if let accountType = self.accountType, let account = self.account,
       let text = textView.text {
      textView.resignFirstResponder()
      accountType.with {
        [unowned self] (service) in
        switch service {
          case .twitter:
            self.tweet(text, with: account)
          case .facebook:
            self.feed(text, with: account)
          default:
            break
        }
      }
    }
  }

  func tweet(_ text: String, with account: SAKAccount) {
    let endpoint = "https://api.twitter.com/1.1/statuses/update.json"
    if let url = URL(string: endpoint) {
      let parameters: [String:Any] = [
        "status": text,
        "trim_user": true
      ]
      do {
        let request = try SAKRequest(forAccount: account, requestMethod: .POST, url: url, parameters: parameters)
        request.perform(handler: {
          [unowned self] (data, response, error) in
          if let error = error {
            self.dismiss(with: .error(error))
          }
          else if let data = data {
            let json = (try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any]).flatMap { $0 }
            self.dismiss(with: .done(json))
          }
          else {
            self.dismiss(with: .done(nil))
          }
        })
      }
      catch let error {
        dismiss(with: .error(error))
      }
    }
  }

  func feed(_ text: String, with account: SAKAccount) {
    let endpoint = "https://graph.facebook.com/v9.0/me/feed"
    if let url = URL(string: endpoint) {
      let parameters: [String:Any] = [
        "message": text,
        "privacy": "{\"value\": \"SELF\"}"
      ]
      do {
        let request = try SAKRequest(forAccount: account, requestMethod: .POST, url: url, parameters: parameters)
        request.perform(handler: {
          [unowned self] (data, response, error) in
          if let error = error {
            self.dismiss(with: .error(error))
          }
          else if let data = data {
            let json = (try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any]).flatMap { $0 }
            self.dismiss(with: .done(json))
          }
          else {
            self.dismiss(with: .done(nil))
          }
        })
      }
      catch let error {
        dismiss(with: .error(error))
      }
    }
  }
}

extension SAKComposeViewController
{
  private func loadAccounts(with accountType: SAKAccountType) {
    accountStore.requestAccessToAccounts(with: accountType, completion: {
      [weak self] (granted: Bool, error: Error?) in
      guard let self = `self`, granted, error == nil else { return }
      if let accounts = self.accountStore.accounts(with: accountType) {
        self.accounts = accounts
      }
    })
  }
}

extension SAKComposeViewController: UITextViewDelegate
{
  public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    if let string = textView.text {
      let newText = string.replacingCharacters(in: range, with: text)
      numberOfChars = newText.count
    }
    return true
  }
    
  public func textViewDidBeginEditing(_ textView: UITextView) {
    if let text = textView.text {
      // XXX: 文字列の終端にカーソルを移動
      let len = text.count
      textView.selectedRange = NSRange(location: len, length: 0)
    }
  }
}

extension SAKComposeViewController: UITableViewDataSource
{
  public func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch viewMode {
      case .editing:
        return (account == nil ? 0 : 1)
      case .selecting:
        return accounts.count
    }
  }

  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell: UITableViewCell = {
      guard let cell = tableView.dequeueReusableCell(withIdentifier: kTableViewCellIdentifier) else {
        return UITableViewCell(style: .value1, reuseIdentifier: kTableViewCellIdentifier)
      }
      return cell
    }()
    cell.selectionStyle = .none
    cell.textLabel?.font = UIFont.systemFont(ofSize: 14.0)

    switch viewMode {
      case .editing:
        cell.textLabel?.text = "Account"
        if let account = self.account {
          cell.detailTextLabel?.text = account.username
        }
        cell.accessoryType = .disclosureIndicator
      case .selecting:
        let row = indexPath.row
        let account = accounts[row]
        cell.textLabel?.text = account.accountDescription
        cell.detailTextLabel?.text = nil
        cell.accessoryType = .none
    }

    return cell
  }
}

extension SAKComposeViewController: UITableViewDelegate
{
  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)

    switch viewMode {
      case .editing:
        let item = UINavigationItem(title: "Accounts")
        navigationBar.pushItem(item, animated: true)
      case .selecting:
        let row = indexPath.row
        self.account = accounts[row]
        navigationBar.popItem(animated: true)
        if let name = account?.username {
          UserDefaults.standard.set(name, forKey: kLastAccountNameKey)
        }
    }
  }
}

extension SAKComposeViewController: UINavigationBarDelegate
{
  public func navigationBar(_ navigationBar: UINavigationBar, shouldPush item: UINavigationItem) -> Bool {
    DispatchQueue.main.async {
      [unowned self] in
      self.viewMode = .selecting
      self.composeView.isHidden = true
      self.tableView.frame = {
        let origin = self.composeView.frame.origin
        var size = self.composeView.frame.size
        size.height += self.tableView.frame.size.height
        return CGRect(origin: origin, size: size)
      }()
      self.tableView.separatorStyle = .singleLine
      self.tableView.reloadData()
    }
    return true
  }

  public func navigationBar(_ navigationBar: UINavigationBar, didPush item: UINavigationItem) {
  }

  public func navigationBar(_ navigationBar: UINavigationBar, shouldPop item: UINavigationItem) -> Bool {
    DispatchQueue.main.async { [unowned self] in
      self.viewMode = .editing
      self.composeView.isHidden = false
      self.tableView.frame = {
        var origin = self.tableView.frame.origin
        var size = self.tableView.frame.size
        origin.y += self.composeView.frame.size.height
        size.height -= self.composeView.frame.size.height
        return CGRect(origin: origin, size: size)
      }()
      self.tableView.separatorStyle = .none
      self.tableView.reloadData()
    }
    return true
  }

  public func navigationBar(_ navigationBar: UINavigationBar, didPop item: UINavigationItem) {
  }
}

extension SAKComposeViewController
{
  private func backIndicator() -> UIImage? {
    let  width: CGFloat = 14.0
    let height: CGFloat = 22.0
    let   size: CGSize  = CGSize(width: width, height: height)
    let opaque: Bool    = false
    let  scale: CGFloat = 0.0

    let  m: CGFloat = 4.0
    let sx: CGFloat = m
    let sy: CGFloat = m
    let ex: CGFloat = width - m
    let ey: CGFloat = height - m
    let cy: CGFloat = floor(height * 0.5)

    var x: CGFloat = ex
    var y: CGFloat = sy

    UIGraphicsBeginImageContextWithOptions(size, opaque, scale)

    let path = UIBezierPath()
    path.lineWidth = 2.0
    path.lineCapStyle = .round
    path.lineJoinStyle = .miter
    path.move(to: CGPoint(x: x, y: y))
    x = sx
    y = cy
    path.addLine(to: CGPoint(x: x, y: y))
    x = ex
    y = ey
    path.addLine(to: CGPoint(x: x, y: y))
    self.view.tintColor.setStroke()
    path.stroke()

    let image = UIGraphicsGetImageFromCurrentImageContext()

    UIGraphicsEndImageContext()

    return image?.withRenderingMode(.alwaysOriginal)
  }
}


fileprivate extension UIView
{
  /*
   * iphone - how to set cornerRadius for only top-left and top-right corner of
   * a UIView? - Stack Overflow
   * https://stackoverflow.com/questions/10167266/how-to-set-cornerradius-for-only-top-left-and-top-right-corner-of-a-uiview
   */
  func roundCorners(_ corners: UIRectCorner = .allCorners, radius: CGFloat = 8.0) {
    let path = UIBezierPath(roundedRect: self.bounds,
                            byRoundingCorners: corners,
                            cornerRadii: CGSize(width: radius, height: radius))
    let mask = CAShapeLayer()
    mask.path = path.cgPath
    self.layer.mask = mask
  }
}

fileprivate extension String
{
  func replacingCharacters(in range: NSRange, with text: String) -> String {
    return self.replacingCharacters(in: self.range(from: range)!, with: text)
  }

  func range(from nsRange: NSRange) -> Range<String.Index>? {
    guard
      let from16 = utf16.index(utf16.startIndex, offsetBy: nsRange.location, limitedBy: utf16.endIndex),
      let to16 = utf16.index(utf16.startIndex, offsetBy: nsRange.location + nsRange.length, limitedBy: utf16.endIndex),
      let from = from16.samePosition(in: self),
      let to = to16.samePosition(in: self)
      else { return nil }
    return from ..< to
  }
}
