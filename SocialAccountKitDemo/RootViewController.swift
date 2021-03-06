/*****************************************************************************
 *
 * FILE:	RootViewController.swift
 * DESCRIPTION:	SocialAccountKitDemo: View Controller to Demonstrate Framework
 * DATE:	Sun, Oct  1 2017
 * UPDATED:	Tue, Jan  5 2021
 * AUTHOR:	Kouichi ABE (WALL) / 阿部康一
 * E-MAIL:	kouichi@MagickWorX.COM
 * URL:		http://www.MagickWorX.COM/
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

import UIKit
import SocialAccountKitSwift

final class RootViewController: BaseViewController
{
  private let kTableViewCellIdentifier: String = "UITableViewCellReusableIdentifier"
  private lazy var tableView: UITableView = {
    let tableView: UITableView = UITableView(frame: self.view.bounds)
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: kTableViewCellIdentifier)
    tableView.delegate = self
    tableView.dataSource = self
    tableView.allowsSelection = false
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 64.0
    tableView.autoresizingMask = [ .flexibleWidth, .flexibleHeight ]
    return tableView
  }()
  private var tableData: [String] = []

  private var composeItem: UIBarButtonItem = UIBarButtonItem()

  private let store: SAKAccountStore = SAKAccountStore.shared
  private var accounts = [SAKAccount]()

  private var accountType: SAKAccountType = SAKAccountType(.twitter)

  private let signInService: SAKSignInService = SAKSignInService(accountType: SAKAccountType(.appOnly))

  override func setup() {
    super.setup()

    self.title = "SocialAccountKitDemo"

    setAppOnlyAccount()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  override func loadView() {
    super.loadView()

    self.view.addSubview(tableView)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    makeNaviBarItems()
    makeToolbar()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    getAccounts()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    let safeAreaInsets: UIEdgeInsets = self.view.safeAreaInsets

    let  width: CGFloat = self.view.bounds.size.width - (safeAreaInsets.left + safeAreaInsets.right)
    let height: CGFloat = self.view.bounds.size.height - (safeAreaInsets.top + safeAreaInsets.bottom)

    tableView.frame = {
      let x: CGFloat = safeAreaInsets.left
      let y: CGFloat = safeAreaInsets.top
      let w: CGFloat = width
      let h: CGFloat = height
      return CGRect(x: x, y: y, width: w, height: h)
    }()
  }
}

private extension RootViewController
{
  func getAccounts() {
    store.requestAccessToAccounts(with: accountType, completion: {
      [unowned self] (granted: Bool, error: Error?) in
      guard granted, error == nil else { return }
      if let accounts = self.store.accounts(with: self.accountType) {
        self.accounts = accounts
      }
    })
  }

  func setAppOnlyAccount() {
    if let accountType = signInService.accountType {
      store.requestAccessToAccounts(with: accountType, completion: {
        [unowned self] (granted: Bool, error: Error?) in
        guard granted, error == nil else { return }
        if let accounts = self.store.accounts(with: accountType), accounts.count == 0 {
          self.signInService.signIn(completion: {
            (successful, account, error) in
            if successful {
              print("Ok. You should enable UIs interaction on your app.")
              dump(account)
            }
            else {
              dump(error)
            }
          })
        }
      })
    }
  }
}

extension RootViewController
{
  private func makeNaviBarItems() {
    self.navigationItem.leftBarButtonItem = {
      let image  = UIImage(systemName: "person.circle")
      return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(handleChoose))
    }()
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(handleAdd))
  }

  @objc private func handleAdd(_ item: UIBarButtonItem) {
    autoreleasepool {
      let viewController = SAKAccountViewController(accountType: accountType)
      viewController.modalPresentationStyle = .overFullScreen
      self.present(viewController, animated: true, completion: nil)
    }
  }

  @objc private func handleChoose(_ item: UIBarButtonItem) {
    let alert = UIAlertController(title: accountType.description, message: "Choose an account", preferredStyle: .actionSheet)
    for account in accounts {
      alert.addAction(UIAlertAction(title: account.username, style: .default, handler: {
        [unowned self] (action: UIAlertAction) -> Void in
        self.accountType.with {
          (service) in
          switch service {
            case .twitter:
              self.fetchHomeTimeline(with: account)
            case .facebook:
              self.fetchFeed(with: account)
            case .appOnly:
              self.fetchUserTimeline(with: account)
            default:
              break
          }
        }
      }))
    }
    if let pvc = alert.popoverPresentationController {
      pvc.sourceView = self.view
      if let navigationController = self.navigationController {
        pvc.sourceRect = navigationController.navigationBar.frame
      }
      else {
        let w: CGFloat = self.view.bounds.size.width
        let h: CGFloat = self.view.bounds.size.height
        let x: CGFloat = floor(w * 0.5)
        let y: CGFloat = floor(h * 0.5)
        pvc.sourceRect = CGRect(x: x, y: y, width: 1.0, height: 1.0)
      }
      pvc.permittedArrowDirections = .down
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    present(alert, animated: true, completion: nil)
  }
}

fileprivate enum ServiceType: Int
{
  case twitter
  case facebook
  case appOnly
}

extension RootViewController
{
  private func makeToolbar() {
    let services = [ "Twitter", "Facebook", "AppOnly" ]
    let segmentedControl = UISegmentedControl(items: services)
    segmentedControl.selectedSegmentIndex = ServiceType.twitter.rawValue
    segmentedControl.addTarget(self, action: #selector(serviceChanged), for: .valueChanged)

    var items: [UIBarButtonItem] = []
    let flexItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace,
                                   target: nil,
                                   action: nil)

    composeItem = UIBarButtonItem(barButtonSystemItem: .compose,
                                  target: self,
                                  action: #selector(composeAction))
    items.append(composeItem)

    items.append(flexItem)
    let customItem = UIBarButtonItem(customView: segmentedControl)
    items.append(customItem)
    items.append(flexItem)

    self.navigationController?.isToolbarHidden = false
    self.toolbarItems = items
    segmentedControl.sizeToFit()
  }

  @objc private func serviceChanged(_ segmentedControl: UISegmentedControl) {
    guard let serviceType = ServiceType(rawValue: segmentedControl.selectedSegmentIndex) else { return }

    accountType = {
      switch serviceType {
        case  .twitter: return SAKAccountType(.twitter)
        case .facebook: return SAKAccountType(.facebook)
        case  .appOnly: return SAKAccountType(.appOnly)
      }
    }()
    tableData.removeAll()
    tableView.reloadData()
    getAccounts()
  }

  @objc private func composeAction(_ sender: UIBarButtonItem) {
    if SAKComposeViewController.isAvailable(for: accountType) {
      autoreleasepool {
        let viewController = SAKComposeViewController(for: accountType)
        viewController.completionHandler = {
          [unowned self] (result: SAKComposeViewControllerResult) -> Void in
          switch result {
            case .cancelled:
              print("cancelled")
            case .done(let json): // XXX: 'json' may be 'nil'.
              if let dict = json {
                self.accountType.with {
                  (service) in
                  switch service {
                    case .twitter:
                      if let text = dict["text"] as? String {
                        self.popup(title: "Successful", message: text)
                      }
                    case .facebook:
                      if let text = dict["id"] as? String {
                        self.popup(title: "Successful", message: "post ID: " + text)
                      }
                    default:
                      break
                  }
                }
              }
              else {
                self.popup(title: "Successful", message: "Tweeted")
              }
            case .error(let error):
              self.popup(title: "Error", message: error.localizedDescription)
          }
        }
        present(viewController, animated: true, completion: nil)
      }
    }
    else {
      popup(title: "Notice", message: "Post feature is unavailable on \(accountType.description).")
    }
  }
}

extension RootViewController
{
  func fetchHomeTimeline(with account: SAKAccount) {
    if let requestURL = URL(string: "https://api.twitter.com/1.1/statuses/home_timeline.json") {
      let parameters: [String:Any] = [
        "exclude_replies": false,
        "include_entities" : false,
        "count" : 20
      ]
      do {
        let request = try SAKRequest(forAccount: account, requestMethod: .GET, url: requestURL, parameters: parameters)
        request.perform(handler: {
          [unowned self] (data, response, error) in
          guard error == nil, let data = data else {
            self.popup(title: "Error", message: error!.localizedDescription)
            return
          }
          self.tableData.removeAll()
          if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
              do {
                if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [Dictionary<String,Any>] {
                  for entity: [String:Any] in json {
                    if let text = entity["text"] as? String,
                       let user = entity["user"] as? [String:Any],
                       let name = user["screen_name"] as? String {
                      let tweet = "@\(name)\n\(text)"
                      self.tableData.append(tweet)
                    }
                  }
                  DispatchQueue.main.async { [unowned self] in
                    self.tableView.reloadData()
                    if self.tableData.count > 0 {
                      let indexPath = IndexPath(row: 0, section: 0)
                      self.tableView.scrollToRow(at: indexPath, at: .top, animated: true)
                    }
                  }
                }
                else {
                  dump(data)
                }
              }
              catch let error {
                self.popup(title: "Parse Error", message: error.localizedDescription)
              }
            }
            else {
              print("Status code is \(httpResponse.statusCode)")
              let responseString = String(data: data, encoding: .utf8)
              dump(responseString)
            }
          }
        })
      }
      catch let error {
        self.popup(title: "Request Error", message: error.localizedDescription)
      }
    }
  }
}

extension RootViewController
{
  func fetchFeed(with account: SAKAccount) {
    if let requestURL = URL(string: "https://graph.facebook.com/me/feed") {
      let parameters: [String:Any] = [:]
      do {
        let request = try SAKRequest(forAccount: account, requestMethod: .GET, url: requestURL, parameters: parameters)
        request.perform(handler: {
          [unowned self] (data, response, error) in
          guard error == nil, let data = data else {
            self.popup(title: "Error", message: error!.localizedDescription)
            return
          }
          self.tableData.removeAll()
          if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
              do {
                if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? Dictionary<String,Any>, let data = json["data"] as? Array<Dictionary<String,String>> {
                  for entity in data {
                    if let message = entity["message"],
                       let timestamp = entity["created_time"] {
                      let text = "\(message)\n\(timestamp)"
                      self.tableData.append(text)
                    }
                  }
                  DispatchQueue.main.async { [unowned self] in
                    self.tableView.reloadData()
                    if self.tableData.count > 0 {
                      let indexPath = IndexPath(row: 0, section: 0)
                      self.tableView.scrollToRow(at: indexPath, at: .top, animated: true)
                    }
                  }
                }
                else {
                  dump(data)
                }
              }
              catch let error {
                self.popup(title: "Parse Error", message: error.localizedDescription)
              }
            }
            else {
              print("Status code is \(httpResponse.statusCode)")
              let responseString = String(data: data, encoding: .utf8)
              dump(responseString)
            }
          }
        })
      }
      catch let error {
        self.popup(title: "Request Error", message: error.localizedDescription)
      }
    }
  }
}

extension RootViewController
{
  func fetchUserTimeline(with account: SAKAccount) {
    if let requestURL = URL(string: "https://api.twitter.com/1.1/statuses/user_timeline.json") {
      let parameters: [String:Any] = [
        "screen_name": "iphone_dev_jp",
        "exclude_replies": true,
        "include_rts": false,
        "count" : 50
      ]
      do {
        let request = try SAKRequest(forAccount: account, requestMethod: .GET, url: requestURL, parameters: parameters)
        request.perform(handler: {
          [unowned self] (data, response, error) in
          guard error == nil, let data = data else {
            self.popup(title: "Error", message: error!.localizedDescription)
            return
          }
          self.tableData.removeAll()
          if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
              do {
                if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [Dictionary<String,Any>] {
                  for entity: [String:Any] in json {
                    if let text = entity["text"] as? String,
                       let user = entity["user"] as? [String:Any],
                       let name = user["screen_name"] as? String {
                      let tweet = "@\(name)\n\(text)"
                      self.tableData.append(tweet)
                    }
                  }
                  DispatchQueue.main.async { [unowned self] in
                    self.tableView.reloadData()
                    if self.tableData.count > 0 {
                      let indexPath = IndexPath(row: 0, section: 0)
                      self.tableView.scrollToRow(at: indexPath, at: .top, animated: true)
                    }
                  }
                }
                else {
                  dump(data)
                }
              }
              catch let error {
                self.popup(title: "Parse Error", message: error.localizedDescription)
              }
            }
            else {
              print("Status code is \(httpResponse.statusCode)")
              let responseString = String(data: data, encoding: .utf8)
              dump(responseString)
            }
          }
        })
      }
      catch let error {
        self.popup(title: "Request Error", message: error.localizedDescription)
      }
    }
  }
}


extension RootViewController: UITableViewDataSource
{
  func create_UITableViewCell(at indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: kTableViewCellIdentifier, for: indexPath)
    cell.selectionStyle = .none
    cell.textLabel?.font = UIFont.systemFont(ofSize: 18.0)
    cell.textLabel?.numberOfLines = 0
    cell.textLabel?.lineBreakMode = .byWordWrapping
    return cell
  }

  func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return tableData.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = self.create_UITableViewCell(at: indexPath)

    let row: Int = indexPath.row
    let text = tableData[row]
    cell.textLabel?.text = text

    return cell
  }
}

extension RootViewController: UITableViewDelegate
{
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
  }
}
