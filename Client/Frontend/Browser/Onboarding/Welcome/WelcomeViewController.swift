// Copyright 2021 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import UIKit
import SnapKit
import BraveShared
import Shared
import pop

private enum WelcomeViewID: Int {
  case background = 1
  case iconView = 2
  case contents = 3
  case callout = 4
  case searchView = 5
  case skipButton = 6
  case iconBackground = 7
}

class WelcomeViewController: UIViewController {
  private let profile: Profile?
  private var state: WelcomeViewCalloutState?

  var onAdsWebsiteSelected: ((URL?) -> Void)?
  var onSkipSelected: (() -> Void)?

  convenience init(profile: Profile?) {
    self.init(
      profile: profile,
      state: .welcome(title: Strings.Onboarding.welcomeScreenTitle)
    )
  }

  init(profile: Profile?, state: WelcomeViewCalloutState?) {
    self.profile = profile
    self.state = state
    super.init(nibName: nil, bundle: nil)
    self.transitioningDelegate = self
    self.modalPresentationStyle = .fullScreen
    self.loadViewIfNeeded()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let backgroundImageView = UIImageView().then {
    $0.image = #imageLiteral(resourceName: "welcome-view-background")
    $0.contentMode = .scaleAspectFill
  }

  private let contentContainer = UIStackView().then {
    $0.axis = .vertical
    $0.spacing = 8
    $0.layoutMargins = UIEdgeInsets(top: 0.0, left: 22.0, bottom: 0.0, right: 22.0)
    $0.isLayoutMarginsRelativeArrangement = true
  }

  private let calloutView = WelcomeViewCallout(pointsUp: false)

  private let iconView = UIImageView().then {
    $0.image = #imageLiteral(resourceName: "welcome-view-icon")
    $0.contentMode = .scaleAspectFit
    $0.setContentCompressionResistancePriority(.init(rawValue: 100), for: .vertical)
  }

  private let searchView = WelcomeViewSearchView().then {
    $0.isHidden = true
    $0.setContentHuggingPriority(.required, for: .vertical)
    $0.setContentCompressionResistancePriority(.init(rawValue: 800), for: .vertical)
  }

  private let skipButton = UIButton(type: .custom).then {
    $0.setTitle(Strings.OBSkipButton, for: .normal)
    $0.setTitleColor(.white, for: .normal)
    $0.alpha = 0.0
    $0.setContentHuggingPriority(.required, for: .vertical)
    $0.setContentCompressionResistancePriority(.required, for: .vertical)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    doLayout()

    if let state = state {
      setLayoutState(state: state)
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    Preferences.General.basicOnboardingCompleted.value = OnboardingState.completed.rawValue

    if case .welcome = self.state {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        self.animateToPrivacyState()
      }
    }
  }

  private func doLayout() {
    backgroundImageView.tag = WelcomeViewID.background.rawValue
    contentContainer.tag = WelcomeViewID.contents.rawValue
    calloutView.tag = WelcomeViewID.callout.rawValue
    iconView.tag = WelcomeViewID.iconView.rawValue
    searchView.tag = WelcomeViewID.searchView.rawValue
    skipButton.tag = WelcomeViewID.skipButton.rawValue

    skipButton.addTarget(self, action: #selector(onSkipButtonPressed(_:)), for: .touchUpInside)

    let stack = UIStackView().then {
      $0.distribution = .equalSpacing
      $0.axis = .vertical
      $0.setContentHuggingPriority(.init(rawValue: 5), for: .vertical)
    }

    let scrollView = UIScrollView()

    [backgroundImageView, scrollView, skipButton].forEach {
      view.addSubview($0)
    }

    scrollView.addSubview(stack)
    scrollView.snp.makeConstraints {
      $0.leading.trailing.top.equalToSuperview()
      $0.bottom.equalTo(skipButton).inset(16)
    }

    scrollView.contentLayoutGuide.snp.makeConstraints {
      $0.width.equalTo(scrollView.frameLayoutGuide.snp.width)
      $0.height.greaterThanOrEqualTo(scrollView.frameLayoutGuide.snp.height)
    }

    stack.snp.makeConstraints {
      $0.edges.equalTo(scrollView.contentLayoutGuide.snp.edges)
    }

    stack.addStackViewItems(
      .view(UIView.spacer(.vertical, amount: 1)),
      .view(contentContainer),
      .view(UIView.spacer(.vertical, amount: 1)))

    [calloutView, iconView, searchView].forEach {
      contentContainer.addArrangedSubview($0)
    }

    backgroundImageView.snp.makeConstraints {
      $0.edges.equalToSuperview()
    }

    skipButton.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview()
      $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
      $0.height.equalTo(48.0)
    }
  }

  private func setLayoutState(state: WelcomeViewCalloutState) {
    self.state = state

    switch state {
    case .welcome:
      iconView.transform = .identity
      contentContainer.spacing = 25.0
      iconView.snp.remakeConstraints {
        $0.height.equalTo(100.0)
      }
      calloutView.setState(state: state)

    case .privacy:
      skipButton.alpha = 0.0
      contentContainer.spacing = 25.0
      
      [iconView, calloutView, searchView].forEach {
        contentContainer.addArrangedSubview($0)
      }
      
      iconView.snp.remakeConstraints {
        $0.height.equalTo(100.0)
      }
      calloutView.setState(state: state)

    case .defaultBrowser:
      iconView.image = #imageLiteral(resourceName: "welcome-view-phone")
      skipButton.alpha = 1.0
      contentContainer.spacing = 0.0
      iconView.snp.remakeConstraints {
        $0.height.equalTo(200.0)
      }
      calloutView.setState(state: state)

    case .defaultBrowserCallout:
      iconView.image = #imageLiteral(resourceName: "welcome-view-phone")
      contentContainer.spacing = 0.0
      iconView.snp.remakeConstraints {
        $0.height.equalTo(200.0)
      }
      calloutView.setState(state: state)

    case .ready:
      iconView.image = #imageLiteral(resourceName: "welcome-view-icon")
      contentContainer.spacing = 0.0
      iconView.snp.remakeConstraints {
        $0.height.equalTo(traitCollection.horizontalSizeClass == .regular ? 250 : 150)
      }
      skipButton.alpha = 1.0

      contentContainer.arrangedSubviews.forEach {
        $0.removeFromSuperview()
      }

      [iconView, calloutView, searchView].forEach {
        contentContainer.addArrangedSubview($0)
        $0.isHidden = false
      }

      websitesForRegion().forEach { item in
        searchView.addButton(icon: item.icon, title: item.title) { [unowned self] in
          self.onWebsiteSelected(item)
        }
      }

      searchView.addButton(
        icon: #imageLiteral(resourceName: "welcome-view-search-view-generic"),
        title: Strings.Onboarding.searchViewEnterWebsiteRowTitle
      ) { [unowned self] in
        self.onEnterCustomWebsite()
      }

      calloutView.setState(state: state)
    }
  }

  private func animateToPrivacyState() {
    let nextController = WelcomeViewController(
      profile: profile,
      state: nil)
    nextController.onAdsWebsiteSelected = onAdsWebsiteSelected
    nextController.onSkipSelected = onSkipSelected
    let state = WelcomeViewCalloutState.privacy(
      title: Strings.Onboarding.welcomeScreenTitle,
      details: Strings.Onboarding.welcomeScreenDescription,
      primaryButtonTitle: Strings.Onboarding.privacyScreenButtonTitle,
      primaryAction: {
        self.close()
        self.onSkipSelected?()
      }
    )
    nextController.setLayoutState(state: state)
    self.present(nextController, animated: true, completion: nil)
  }

  private func animateToDefaultBrowserState() {
    let nextController = WelcomeViewController(
      profile: profile,
      state: nil)
    nextController.onAdsWebsiteSelected = onAdsWebsiteSelected
    nextController.onSkipSelected = onSkipSelected
    let state = WelcomeViewCalloutState.defaultBrowser(
      info: WelcomeViewCalloutState.WelcomeViewDefaultBrowserDetails(
        title: Strings.Callout.defaultBrowserCalloutTitle,
        details: Strings.Callout.defaultBrowserCalloutDescription,
        primaryButtonTitle: Strings.Callout.defaultBrowserCalloutPrimaryButtonTitle,
        secondaryButtonTitle: Strings.DefaultBrowserCallout.introSkipButtonText,
        primaryAction: {
          nextController.onSetDefaultBrowser()
        },
        secondaryAction: {
          nextController.animateToReadyState()
        }
      )
    )
    nextController.setLayoutState(state: state)
    self.present(nextController, animated: true, completion: nil)
  }

  private func animateToReadyState() {
    let nextController = WelcomeViewController(
      profile: profile,
      state: nil)
    nextController.onAdsWebsiteSelected = onAdsWebsiteSelected
    nextController.onSkipSelected = onSkipSelected
    let state = WelcomeViewCalloutState.ready(
      title: Strings.Onboarding.readyScreenTitle,
      details: Strings.Onboarding.readyScreenDescription,
      moreDetails: Strings.Onboarding.readyScreenAdditionalDescription)
    nextController.setLayoutState(state: state)
    self.present(nextController, animated: true, completion: nil)
  }

  @objc
  private func onSkipButtonPressed(_ button: UIButton) {
    close()
    onSkipSelected?()
  }

  private func onWebsiteSelected(_ item: WebsiteRegion) {
    close()
    if let url = URL(string: item.domain) {
      onAdsWebsiteSelected?(url)
    }
  }

  private func onEnterCustomWebsite() {
    close()
    onAdsWebsiteSelected?(nil)
  }

  private func onSetDefaultBrowser() {
    guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
      return
    }
    UIApplication.shared.open(settingsUrl)
    animateToReadyState()
  }

  private func close() {
    var presenting: UIViewController = self
    while true {
      if let presentingController = presenting.presentingViewController {
        presenting = presentingController
        if presenting.isKind(of: BrowserViewController.self) {
          break
        }
        continue
      }

      if let presentingController = presenting as? UINavigationController,
        let topController = presentingController.topViewController {
        presenting = topController
        if presenting.isKind(of: BrowserViewController.self) {
          break
        }
      }

      break
    }
    presenting.dismiss(animated: true, completion: nil)
  }

  private struct WebsiteRegion {
    let icon: UIImage
    let title: String
    let domain: String
  }

  private func websitesForRegion() -> [WebsiteRegion] {
    var siteList = [WebsiteRegion]()

    switch Locale.current.regionCode {
    // Canada
    case "CA":
      siteList = [
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-yahoo"), title: "Yahoo", domain: "https://yahoo.com/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-environment-canada"), title: "Environment Canada", domain: "https://weather.gc.ca/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-cdn-tire"), title: "Canadian Tire", domain: "https://canadiantire.ca/"),
      ]

    // United Kingdom
    case "GB":
      siteList = [
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-bbc"), title: "BBC", domain: "https://bbc.co.uk/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-sky"), title: "Sky", domain: "https://sky.com/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-wired"), title: "Wired", domain: "https://wired.com/"),
      ]

    // Germany
    case "DE":
      siteList = [
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-yahoo"), title: "Yahoo", domain: "https://yahoo.com/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-gmx"), title: "GMX", domain: "https://gmx.net/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-mobilede"), title: "Mobile", domain: "https://mobile.de/"),
      ]

    // France
    case "FR":
      siteList = [
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-yahoo"), title: "Yahoo", domain: "https://yahoo.com/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-jdf"), title: "Les Journal des Femmes", domain: "https://journaldesfemmes.fr/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-programme-tv"), title: "Programme TV", domain: "https://programme-tv.net/"),
      ]

    // India
    case "IN":
      siteList = [
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-hotstar"), title: "Hot Star", domain: "https://hotstar.com/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-cricketbuzz"), title: "Cricket Buzz", domain: "https://cricbuzz.com/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-flipkart"), title: "Flipkart", domain: "https://flipkart.com/"),
      ]

    // Australia
    case "AU":
      siteList = [
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-news-au"), title: "News", domain: "https://news.com.au/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-gumtree"), title: "Gumtree", domain: "https://gumtree.com.au/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-realestate-au"), title: "Real Estate", domain: "https://realestate.com.au/"),
      ]

    // Ireland
    case "IE":
      siteList = [
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-rte"), title: "RTÉ", domain: "https://rte.ie/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-independent"), title: "Independent", domain: "https://independent.ie/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-donedeal"), title: "DoneDeal", domain: "https://donedeal.ie/"),
      ]

    // Japan
    case "JP":
      siteList = [
        WebsiteRegion(icon: #imageLiteral(resourceName: "faviconYahoo"), title: "Yahoo! JAPAN", domain: "https://m.yahoo.co.jp/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-wired"), title: "Wired(日本版)", domain: "https://wired.jp/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-number-bunshin"), title: "Number Web", domain: "https://number.bunshun.jp/"),
      ]

    // United States
    case "US":
      siteList = [
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-yahoo"), title: "Yahoo", domain: "https://yahoo.com/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-wired"), title: "Wired", domain: "https://wired.com/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-espn"), title: "ESPN", domain: "https://espn.com/"),
      ]

    default:
      siteList = [
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-yahoo"), title: "Yahoo", domain: "https://yahoo.com/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-wired"), title: "Wired", domain: "https://wired.com/"),
        WebsiteRegion(icon: #imageLiteral(resourceName: "welcome-view-search-view-espn"), title: "ESPN", domain: "https://espn.com/"),
      ]
    }
    return siteList
  }
}

extension WelcomeViewController: UIViewControllerTransitioningDelegate {
  func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    return WelcomeAnimator(isPresenting: true)
  }

  func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    return WelcomeAnimator(isPresenting: false)
  }
}

// Disabling orientation changes
extension WelcomeViewController {
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .default
  }

  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return .portrait
  }

  override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
    return .portrait
  }

  override var shouldAutorotate: Bool {
    return false
  }
}

private class WelcomeAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  let isPresenting: Bool

  private struct WelcomeViewInfo {
    let backgroundImageView: UIView
    let contentContainer: UIView
    let calloutView: UIView
    let iconView: UIView
    let searchEnginesView: UIView
    let skipButton: UIView

    var allViews: [UIView] {
      return [
        backgroundImageView,
        contentContainer,
        calloutView,
        iconView,
        searchEnginesView,
        skipButton,
      ]
    }

    init?(view: UIView) {
      guard let backgroundImageView = view.subview(with: WelcomeViewID.background.rawValue),
        let contentContainer = view.subview(with: WelcomeViewID.contents.rawValue),
        let calloutView = view.subview(with: WelcomeViewID.callout.rawValue),
        let iconView = view.subview(with: WelcomeViewID.iconView.rawValue),
        let searchEnginesView = view.subview(with: WelcomeViewID.searchView.rawValue),
        let skipButton = view.subview(with: WelcomeViewID.skipButton.rawValue)
      else {
        return nil
      }

      self.backgroundImageView = backgroundImageView
      self.contentContainer = contentContainer
      self.calloutView = calloutView
      self.iconView = iconView
      self.searchEnginesView = searchEnginesView
      self.skipButton = skipButton
    }
  }

  init(isPresenting: Bool) {
    self.isPresenting = isPresenting
  }

  func performDefaultAnimation(using transitionContext: UIViewControllerContextTransitioning) {
    let container = transitionContext.containerView

    guard let fromView = transitionContext.view(forKey: UITransitionContextViewKey.from) else {
      transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
      return
    }

    guard let toView = transitionContext.view(forKey: UITransitionContextViewKey.to) else {
      transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
      return
    }

    // Setup
    fromView.frame = container.bounds
    toView.frame = container.bounds
    container.addSubview(toView)
    fromView.setNeedsLayout()
    fromView.layoutIfNeeded()
    toView.setNeedsLayout()
    toView.layoutIfNeeded()

    // Setup animation
    let totalAnimationTime = self.transitionDuration(using: transitionContext)

    toView.alpha = 0.0
    UIView.animate(withDuration: totalAnimationTime, delay: 0.0, options: .curveEaseInOut) {
      toView.alpha = 1.0
    } completion: { finished in
      transitionContext.completeTransition(!transitionContext.transitionWasCancelled && finished)
    }
  }

  func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    let container = transitionContext.containerView

    guard let fromView = transitionContext.view(forKey: UITransitionContextViewKey.from) else {
      performDefaultAnimation(using: transitionContext)
      return
    }

    guard let toView = transitionContext.view(forKey: UITransitionContextViewKey.to) else {
      performDefaultAnimation(using: transitionContext)
      return
    }

    // Get animatable views
    guard let fromWelcomeView = WelcomeViewInfo(view: fromView),
      let toWelcomeView = WelcomeViewInfo(view: toView)
    else {
      performDefaultAnimation(using: transitionContext)
      return
    }

    // Setup
    fromView.frame = container.bounds
    toView.frame = container.bounds
    container.addSubview(toView)
    fromView.setNeedsLayout()
    fromView.layoutIfNeeded()
    toView.setNeedsLayout()
    toView.layoutIfNeeded()

    // Setup animation
    let totalAnimationTime = self.transitionDuration(using: transitionContext)
    let fromViews = fromWelcomeView.allViews
    let toViews = toWelcomeView.allViews

    toWelcomeView.contentContainer.setNeedsLayout()
    toWelcomeView.contentContainer.layoutIfNeeded()

    // Do animations
    for e in fromViews.enumerated() {
      let fromView = e.element
      var toAlpha = 0.0
      let toView = toViews[e.offset].then {
        toAlpha = $0.alpha
        $0.alpha = 0.0
      }

      if fromView == fromWelcomeView.backgroundImageView {
        continue
      }

      if fromView == fromWelcomeView.skipButton {
        UIView.animate(withDuration: totalAnimationTime, delay: 0.0, options: .curveEaseInOut) {
          fromView.transform = toView.transform
        } completion: { finished in
          toView.alpha = toAlpha
        }
      } else {
        POPBasicAnimation(propertyNamed: kPOPViewFrame)?.do {
          $0.fromValue = fromView.frame
          $0.toValue = toView.frame
          $0.duration = totalAnimationTime
          $0.beginTime = CACurrentMediaTime()
          fromView.layer.pop_add($0, forKey: "frame")
        }

        UIView.animate(
          withDuration: totalAnimationTime,
          delay: 0.0,
          options: [.curveEaseInOut]
        ) {
          fromView.alpha = 0.0
          toView.alpha = toAlpha
        } completion: { finished in

        }
      }
    }

    if let fromCallout = fromWelcomeView.calloutView as? WelcomeViewCallout,
      let toCallout = toWelcomeView.calloutView as? WelcomeViewCallout {
      fromCallout.animateFromCopy(view: toCallout, duration: totalAnimationTime, delay: 0.0)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + totalAnimationTime) {
      toWelcomeView.backgroundImageView.alpha = 1.0
      transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
    }
  }

  func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    return 0.5
  }
}

private extension UIView {
  func subview(with tag: Int) -> UIView? {
    if self.tag == tag {
      return self
    }

    for view in self.subviews {
      if view.tag == tag {
        return view
      }

      if let view = view.subview(with: tag) {
        return view
      }
    }
    return nil
  }
}
