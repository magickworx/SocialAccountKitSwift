/*****************************************************************************
 *
 * FILE:	AccountViewController.swift
 * DESCRIPTION:	SocialAccountKit: View Controller to Manage Accounts
 * DATE:	Wed, Sep 27 2017
 * UPDATED:	Mon, Nov 26 2018
 * AUTHOR:	Kouichi ABE (WALL) / 阿部康一
 * E-MAIL:	kouichi@MagickWorX.COM
 * URL:		http://www.MagickWorX.COM/
 * CHECKER:     http://quonos.nl/oauthTester/
 * COPYRIGHT:	(c) 2017-2018 阿部康一／Kouichi ABE (WALL), All rights reserved.
 * LICENSE:
 *
 *  Copyright (c) 2017-2018 Kouichi ABE (WALL) <kouichi@MagickWorX.COM>,
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

public protocol SAKAccountViewControllerDelegate: class
{
  func accountViewController(canEdit account: SAKAccount) -> Bool
}

public class SAKAccountViewController: UINavigationController
{
  public weak var editDelegate: SAKAccountViewControllerDelegate? = nil {
    didSet {
      if let rvc = self.topViewController as? AccountViewController {
        rvc.editDelegate = editDelegate
      }
    }
  }

  required public init(coder aDecoder: NSCoder) {
    fatalError("NSCoding not supported")
  }

  override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: Bundle!) {
    super.init(nibName: nil, bundle: nil)
  }

  public init(accountType type: SAKAccountType = SAKAccountType(.twitter)) {
    let rvc = AccountViewController(accountType: type)
    super.init(rootViewController: rvc)
  }
}

fileprivate let kTableViewCellIdentifier = "UITableViewCellReusableIdentifier"

class AccountViewController: UIViewController
{
  public weak var editDelegate: SAKAccountViewControllerDelegate? = nil

  let accountStore = SAKAccountStore.shared

  var oauth: OAuth? = nil

  var tableView: UITableView = UITableView(frame: .zero)
  var tableData: [SAKAccount] = []

  var isCreatable: Bool = true // Can I create new account?

  var accountType: SAKAccountType? = nil {
    didSet {
      if let accountType = accountType {
        oauth = {
          switch accountType.identifier {
            case  .twitter: return OAuth(TwitterOAuthConfiguration())
            case .facebook: return OAuth(FacebookOAuthConfiguration())
            case   .github: return OAuth(GitHubOAuthConfiguration())
            default: return nil
          }
        }()
        isCreatable = (oauth != nil)
      }
    }
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("NSCoding not supported")
  }

  override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: Bundle!) {
    super.init(nibName: nil, bundle: nil)
  }

  public convenience init(accountType type: SAKAccountType) {
    self.init(nibName: nil, bundle: nil)
    self.title = "Account Manager"

    defer {
      self.accountType = type
    }
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  override func loadView() {
    super.loadView()

    self.edgesForExtendedLayout = []
    self.extendedLayoutIncludesOpaqueBars = true

    self.view.backgroundColor = .white
    self.view.autoresizesSubviews = true
    self.view.autoresizingMask	= [ .flexibleWidth, .flexibleHeight ]

    tableView.register(UITableViewCell.self, forCellReuseIdentifier: kTableViewCellIdentifier)
    tableView.frame = self.view.bounds
    tableView.delegate = self
    tableView.dataSource = self
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 48
    tableView.allowsSelectionDuringEditing = true
    tableView.autoresizingMask = [ .flexibleWidth, .flexibleHeight ]
    tableView.contentInsetAdjustmentBehavior = .never
    self.view.addSubview(tableView)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let closeItem = UIBarButtonItem(barButtonSystemItem: .stop,
                                    target: self,
                                    action: #selector(closeAction))
    self.navigationItem.leftBarButtonItem = closeItem
    self.navigationItem.rightBarButtonItem = self.editButtonItem
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    loadData()

    addNotification()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    removeNotification()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
  }
}

extension AccountViewController
{
  func loadData() {
    DispatchQueue.main.async { [unowned self] in
      if let accountType = self.accountType,
         let accounts = self.accountStore.accounts(with: accountType) {
        self.tableData = accounts
        self.tableView.reloadData()
      }
    }
  }

  @objc func closeAction(_ sender: UIBarButtonItem) {
    dismiss(animated: true, completion: nil)
  }

  override func setEditing(_ editing: Bool, animated: Bool) {
    super.setEditing(editing, animated: animated)

    self.navigationItem.leftBarButtonItem?.isEnabled = !editing

    if !isCreatable {
      tableView.setEditing(editing, animated: animated)
      return
    }

    let section = 0
    let row = tableData.count
    let indexPath = IndexPath(row: row, section: section)

    tableView.beginUpdates()
    tableView.setEditing(editing, animated: animated)
    if editing { // Show the placeholder row
      tableView.insertRows(at: [indexPath], with: .automatic)
    }
    else { // Hide the placeholder row
      tableView.deleteRows(at: [indexPath], with: .fade)
    }
    tableView.endUpdates()

    if editing && row > 0 {
      tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
  }
}

extension AccountViewController: UITableViewDataSource
{
  func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return tableData.count + (tableView.isEditing && isCreatable ? 1 : 0)
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: kTableViewCellIdentifier, for: indexPath)
    cell.selectionStyle = .none
    cell.textLabel?.font = UIFont.systemFont(ofSize: 14.0)

    let row = indexPath.row
    if row == tableData.count {
      cell.editingAccessoryType = .disclosureIndicator
      cell.textLabel?.text = "Add New Account"
    }
    else {
      let account = tableData[row]
      cell.accessoryType = .none
      cell.editingAccessoryType = .none
      cell.textLabel?.text = account.username
      cell.detailTextLabel?.text = account.accountType.description
    }

    return cell
  }

  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return "Accounts"
  }
}

extension AccountViewController: UITableViewDelegate
{
  func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
    let row = indexPath.row
    if row == tableData.count {
      return .insert
    }
    return .delete
  }

  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    if let editDelegate = self.editDelegate {
      let row = indexPath.row
      guard row != tableData.count else { return tableView.isEditing }
      let account = tableData[row]
      return editDelegate.accountViewController(canEdit: account)
    }
    return tableView.isEditing
  }

  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      let row = indexPath.row
      let account = tableData[row]
      accountStore.removeAccount(account, withCompletionHandler: {
        [unowned self] (success, error) in
        self.tableData.remove(at: row)
        self.tableView.beginUpdates()
        self.tableView.deleteRows(at: [indexPath], with: .fade)
        self.tableView.endUpdates()
      })
    }
    else if editingStyle == .insert {
      createNewAccount()
    }
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)

    if tableView.isEditing && indexPath.row == tableData.count {
      createNewAccount()
    }
/*
    else {
      dump(tableData[indexPath.row])
    }
*/
  }
}

extension AccountViewController
{
  func addNotification() {
    let center = NotificationCenter.default
    center.addObserver(self,
                       selector: #selector(verfiyCredentials),
                       name: .OAuthDidVerifyCredentials,
                       object: nil)
    center.addObserver(self,
                       selector: #selector(missCredentials),
                       name: .OAuthDidMissCredentials,
                       object: nil)
    center.addObserver(self,
                       selector: #selector(authorizationFailure),
                       name: .OAuthDidEndInFailure,
                       object: nil)
  }

  func removeNotification() {
    let center = NotificationCenter.default
    center.removeObserver(self,
                          name: .OAuthDidVerifyCredentials,
                          object: nil)
    center.removeObserver(self,
                          name: .OAuthDidMissCredentials,
                          object: nil)
    center.removeObserver(self,
                          name: .OAuthDidEndInFailure,
                          object: nil)
  }

  @objc func verfiyCredentials(_ notification: Notification) {
    guard let userInfo = notification.userInfo else { return }
    if let accountType = self.accountType,
       let credentials = userInfo[OAuthCredentialsKey] as? OAuthCredential {
        saveCredentials(credentials, accountType: accountType)
    }
  }

  func saveCredentials(_ credentials: OAuthCredential, accountType: SAKAccountType) {
    let account = SAKAccount(accountType: accountType)
    switch accountType.identifier {
      case .twitter:
        if let credentials = credentials as? TwitterCredential,
           let name = credentials.screenName,
           let token = credentials.oauthToken,
           let secret = credentials.oauthTokenSecret {
          account.username = name
          account.credential = SAKAccountCredential(oAuthToken: token, tokenSecret: secret)
        }
      case .facebook:
        if let credentials = credentials as? FacebookCredential,
           let name = credentials.fullName,
           let type = credentials.tokenType,
           let token = credentials.oauth2Token,
           let refresh = credentials.refreshToken,
           let expiry = credentials.expiryDate {
          account.username = name
          account.credential = SAKAccountCredential(oAuth2Token: token, refreshToken: refresh, expiryDate: expiry, tokenType: type)
        }
      case .github:
        if let credentials = credentials as? GitHubCredential,
           let name = credentials.login,
           let type = credentials.tokenType,
           let token = credentials.oauth2Token,
           let refresh = credentials.refreshToken,
           let expiry = credentials.expiryDate {
          account.username = name
          account.credential = SAKAccountCredential(oAuth2Token: token, refreshToken: refresh, expiryDate: expiry, tokenType: type)
        }
      default:
        break
    }
    accountStore.saveAccount(account, withCompletionHandler: {
      (success, error) in
      guard success, error == nil else { return }
      DispatchQueue.main.async { [unowned self] in
        self.tableData.append(account)
        let section = 0
        let row = self.tableData.count - 1
        let indexPath = IndexPath(row: row, section: section)
        self.tableView.beginUpdates()
        self.tableView.insertRows(at: [indexPath], with: .automatic)
        self.tableView.endUpdates()
        self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
      }
    })
  }

  func createNewAccount() {
    guard let oauth = self.oauth, oauth.configuration.isReady else {
      configurationUnprepared()
      return
    }
    oauth.requestCredentials(handler: {
      [unowned self] (url, error) in
      if let authenticateURL = url, let accountType = self.accountType, error == nil {
        DispatchQueue.main.async { [unowned self] in
          autoreleasepool {
            let viewController = SAKSignInViewController(with: authenticateURL, accountType: accountType)
            viewController.callback = oauth.configuration.callbackURI
            switch accountType.identifier {
              case .twitter:
                viewController.clearCache(of: [ .diskCache, .memoryCache, .cookies ], in: "twitter.com")
              case .facebook:
//                viewController.clearCache(in: "facebook.com")
                viewController.clearCache(of: [ .diskCache, .memoryCache, .cookies ], in: "facebook.com")
              case .github:
                viewController.clearCache(of: [ .diskCache, .memoryCache, .cookies ], in: "github.com")
                viewController.clearCache(in: "githubusercontent.com")
              default:
                break
            }
            self.present(viewController, animated: true, completion: nil)
          }
        }
      }
      else if let error = error {
        var text = String()
        dump(error, to: &text)
        self.popup(title: "Error", message: text)
      }
    })
  }

  @objc func missCredentials(_ notification: Notification) {
    guard let userInfo = notification.userInfo else { return }
    if let error = userInfo[OAuthErrorInfoKey] as? Error {
      popup(title: "Error", message: error.localizedDescription)
    }
  }

  @objc func authorizationFailure(_ notification: Notification) {
    popup(title: "Failure", message: "Failed to authorize account. Check username and password once again.")
  }

  func configurationUnprepared() {
    if let accountType = self.accountType {
      let service = accountType.serviceName
      let text: String = {
        switch accountType.identifier {
          case .twitter:
            return "Confirm \(service).plist has set ConsumerKey and ConsumerSecret."
          case .facebook:
            return "Confirm \(service).plist has set AppID and AppSecret."
          case .github:
            return "Confirm \(service).plist has set ClientID and ClientSecret."
          default:
            return "Unsupported service: \(service)"
        }
      }()
      popup(title: "Attention", message: text)
    }
  }
}

extension AccountViewController
{
  fileprivate func popup(title: String, message: String) {
    DispatchQueue.main.async { [unowned self] in
      autoreleasepool {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
      }
    }
  }
}
