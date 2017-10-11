# SocialAccountKitSwift

iOS 11 以降使えなくなった、Account.framework と Social.framework の代替フレームワーク。SocialAccountKit.framework を使えば、iOS 10.3 までと同じ感じで Twitter や Facebook の API にアクセスできるよ。

## できること／できないこと

- [x] 複数の Twitter アカウントに対応
- [x] 複数の Facebook アカウントに対応
- [x] 公開されている API に直接アクセスが可能
- [x] **API Key** と **API Secret** を設定するだけの簡単導入
- [x] 少ない修正で Account.framework と Social.framework から移行可能

- [ ] 画像添付（開発者が API を直接アクセスするコードを実装すれば可能）
- [ ] Facebook のトークン再発行
- [ ] 十分なエラー処理


## 用意するもの

Twitter あるいは Facebook のサイトでアプリを登録し、API Key と API Secret を取得する必要がある。

### Twitter

1. [Twitter Application Management](https://apps.twitter.com/) ページにアクセスする。
2. **Create New App** を実行して、アプリケーションを登録する。
3. **Keys and Access Tokens** タブを選択し、 **Consumer Key** と **Consumer Secret** の文字列をコピーする。
4. Xcode Project 内の Twitter.plist の CosumerKey と ConsumerSecret にペーストする。

```Twitter.plist
<plist version="1.0">
<dict>
  <key>ConsumerKey</key>
  <string>YOUR CONSUMER KEY</string>
  <key>ConsumerSecret</key>
  <string>YOUR CONSUMER SECRET</string>
</dict>
</plist>
```

### Facebook

1. [開発者向け Facebook](https://developers.facebook.com/) にページにアクセスする。
2. 右上の **マイアプリ** から **新しいアプリを追加** を選択し、アプリを登録する。
3. ダッシュボード画面の **アプリID** と **app secret** の文字列をコピーする。
4. Xcode Project 内の Facebook.plist の AppID と AppSecret にペーストする。

```Facebook.plist
<plist version="1.0">
<dict>
  <key>AppID</key>
  <string>YOUR APP ID</string>
  <key>AppSecret</key>
  <string>YOUR APP SECRET</string>
  <key>Permissions</key>
  <array>
    <string>public_profile</string>
    <string>email</string>
    <string>manage_pages</string>
    <string>publish_pages</string>
    <string>publish_actions</string>
    <string>user_posts</string>
    <string>user_friends</string>
  </array>
</dict>
</plist>
```

**Permissions** の値を調整したい場合は、[アクセス許可のリファレンス - Facebook ログイン](https://developers.facebook.com/docs/facebook-login/permissions) を参照してね。

さらにもう一手間、認証設定をするよ。

1. プロダクト画面で **Facebook ログイン** を追加する。
2. **クライアントOAuth設定** 画面を開く。
3. **クライアントOAuthログイン** と **埋め込みブラウザOAuthログイン** を **はい** に変更する。


## SoicalAccountKitDemo の実行

Twitter.plist と Facebook.plist の設定が完了したら、実際にデモアプリを起動してみよう。

Xcode の Build Target を SocialAccountKitDemo に変更して Build を実行。

![デモアプリ](screenshots/ss_demo_top.png "デモ画面")

デモ画面の右上の **＋** でアカウントの登録と管理が可能。あとは、実際にアカウントを登録して、デモアプリを試してね。アカウント登録が問題なく完了すれば、タイムラインを見たり、投稿したりできるよ。


## 自作アプリへの組み込み方法

### SocialAccountKit.framework のビルド

Xcode の Build Target に SocialAccountKitFatBinary を指定して Build を実行すると、SocialAccountKit.framework が作成される。これを自作アプリの Xcode の Embedded Binaries に設定する。良く使うなら、${HOME}/Library/Frameworks フォルダなどにコピーしておこう。

#### サクッと習得するには

SocialAccountKitDemo を動作可能にしてから、SocialAccountKitDemo フォルダの RootViewController.swift のソースコードを見ながら、デモを操作してみよう。実装したい機能のコードが見つかるはず。


### アカウント管理

iOS 11 よりも前は、iOS の設定アプリ内で Twitter や Facebook アカウントの管理ができた。iOS 11 以降は設定項目が無くなったので、アプリ側で管理する必要がある。

SocialAccountKit.framework では、SAKAccoutViewController クラスを提供する。これを、次のようなソースコードを書いて呼び出す。

```Swift
  let accountType = SAKAccountType(.twitter)
  let viewController = SAKAccountViewController(accountType: accountType)
  present(viewController, animated: true, completion: nil)
```

![アカウント管理画面](screenshots/ss_demo_manager.png "アカウント管理画面")


### 管理アカウントへの操作

SAKAccountViewController を使って登録したアカウントは、次の方法でアクセスできる。この例では、登録されている全ての Twitter アカウントを取得する。accounts 配列にアカウント情報が保存されるので、UIAlertController などを使ってアカウントの選択機能を提供できる。


```Swift
  let store = SAKAccountStore.shared
  var accounts = [SAKAccount]()

  let accountType = SAKAccountType(.twitter)
  store.requestAccessToAccounts(with: accountType, completion: {
    [unowned self] (granted: Bool, error: Error?) in
    guard granted, error == nil else { return }
    if let accounts = self.store.accounts(with: self.accountType) {
      self.accounts = accounts
    }
  })
```

![アカウント選択画面](screenshots/ss_demo_choose.png "アカウント選択画面")


### 投稿

Twitter や Facebook に投稿する場合は、SAKComposeViewController クラスが利用可能だ。直接、API にアクセスする方法もあるが、このクラスを利用した方が便利かも。

```Swift
  let accountType = SAKAccountType(.twitter)
  if SAKComposeViewController.isAvailable(for: accountType) {
    let viewController = SAKComposeViewController(forAccountType: accountType)
    viewController.completionHandler = {
      [unowned self] (result: SAKComposeViewControllerResult) -> Void in
      switch result {
        case .cancelled:
          print("cancelled")
        case .done(let json): // XXX: 'json' may be 'nil'.
          dump(json)
        case .error(let error):
          print(error.localizedDescription)
      }
    }
    present(viewController, animated: true, completion: nil)
  }
```

![投稿画面](screenshots/ss_demo_post.png "投稿画面")


### Twitter / Facebook API へのアクセス

Twitter や Facebook の API にアクセスには、以下のソースコードのように記述する。これは、Twitter の Home Timeline を取得する実装例だ。実際のソースコードはもっと長いので、SocialAccountKitDemo フォルダ内の RootViewController.swift の fetchHomeTimeline() を見てね。

```Swift
  let accountType = SAKAccountType(.twitter)
  if let requestURL = URL(string: "https://api.twitter.com/1.1/statuses/home_timeline.json") {
    let parameters: [String:Any] = [
      "count" : 20
    ]
    do {
      let request = try SAKRequest(forAccount: account, requestMethod: .GET, url: requestURL, parameters: parameters)
      request.perform(handler: {
        [unowned self] (data, response, error) in
        guard error == nil, let data = data else {
          dump(error)
          return
        }
        if let httpResponse = response as? HTTPURLResponse {
          if httpResponse.statusCode == 200 {
            let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [Dictionary<String,Any>]
            dump(json)
          }
          else {
            print("Status code is \(httpResponse.statusCode)")
          }
        }
      })
    }
    catch let error {
      print(error.localizedDescription)
    }
  }
```

![Tiwtter Timeline 画面](screenshots/ss_demo_tiwtter.png "Twitter 画面")



## クラス一覧

### SAKAccountType

#### Initializer
- init(\_ typeIdentifier: SAKServiceTypeIdentifier)

#### Methods
- func with(\_ block: @escaping (SAKServiceTypeIdentifier) -> Void)

#### Properties
- var accessGranted: Bool
- var description: String

```Swift
enum SAKServiceTypeIdentifier: Int32
{
  case twitter
  case facebook
  case instagram
}
```

### SAKAccount

#### Initializer
- init(accountType type: SAKAccountType, identifier: String)

#### Properties
- var username: String?
- var description: String
- var accountDescription: String
- var userFullName: String // Facebook only

### SAKAccountStore (Singleton)

#### Methods
- func account(withIdentifier identifier: String) -> SAKAccount?
- func accounts(with type: SAKAccountType) -> [SAKAccount]?
- func accountType(withAccountTypeIdentifier typeIdentifier: SAKServiceTypeIdentifier) -> SAKAccountType

- func saveAccount(\_ account: SAKAccount, withCompletionHandler handler: @escaping SAKAccountStoreSaveCompletionHandler)
- func removeAccount(\_ account: SAKAccount, withCompletionHandler handler: @escaping SAKAccountStoreRemoveCompletionHandler)
- func renewCredential(for account: SAKAccount, completion: @escaping SAKAccountStoreCredentialRenewalHandler)

- func requestAccessToAccounts(with accountType: SAKAccountType, options: Dictionary<String,String>? = nil, completion: @escaping SAKAccountStoreRequestAccessCompletionHandler)

#### Properties
- var accounts = [SAKAccount]() // readonly

#### Typealiases
- typealias SAKAccountStoreSaveCompletionHandler = (\_ success: Bool, \_ error: Error?) -> Void
- typealias SAKAccountStoreRemoveCompletionHandler = (\_ success: Bool, \_ error: Error?) -> Void
- typealias SAKAccountStoreRequestAccessCompletionHandler = (\_ granted: Bool, \_ error: Error?) -> Void
- typealias SAKAccountStoreCredentialRenewalHandler = (\_ result: SAKAccountCredentialRenewResult, \_ error: Error?) -> Void

```Swift
enum SAKAccountCredentialRenewResult
{
  case renewed
  case rejected
  case failed
}
```

### SAKComposeViewController

- class func isAvailable(for accountType: SAKAccountType) -> Bool

#### Initializer
- init(forAccountType type: SAKAccountType)

#### Properties
- var completionHandler: SAKComposeViewControllerCompletionHandler

#### Typealias
- typealias SAKComposeViewControllerCompletionHandler = (SAKComposeViewControllerResult) -> Void

```Swift
enum SAKComposeViewControllerResult
{
  case cancelled
  case done([String:Any]?)
  case error(Error)
}
```

### SAKRequest

#### Initializer
- init(forAccount account: SAKAccount, requestMethod method: SAKRequestMethod, url: URL, parameters: [String:Any] = [:]) throws

#### Methods
- func perform(handler: @escaping SAKRequestHandler)

#### Properties
- var account: SAKAccount? // readonly
- var method: SAKRequestMethod // readonly
- var URL: URL? // readonly
- var parameters: [String:Any] // readonly

#### Typealias
- typealias SAKRequestHandler = (Data?, URLResponse?, Error?) -> Void

```Swift
enum SAKRequestMethod: String
{
  case GET    = "GET"
  case POST   = "POST"
  case DELETE = "DELETE"
  case PUT    = "PUT"
}
```


## Requirements

 - Swift4
 - iOS 11.0 or later
 - Xcode 9.0 or later

## ToDo

 - Facebook のアクセストークンの有効期限切れ時の処理

## License Agreement

Copyright (c) 2017, Kouichi ABE (WALL) All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

