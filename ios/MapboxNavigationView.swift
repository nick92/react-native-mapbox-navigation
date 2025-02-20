import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections

// // adapted from https://pspdfkit.com/blog/2017/native-view-controllers-and-react-native/ and https://github.com/mslabenyak/react-native-mapbox-navigation/blob/master/ios/Mapbox/MapboxNavigationView.swift
extension UIView {
  var parentViewController: UIViewController? {
    var parentResponder: UIResponder? = self
    while parentResponder != nil {
      parentResponder = parentResponder!.next
      if let viewController = parentResponder as? UIViewController {
        return viewController
      }
    }
    return nil
  }
}

class MapboxNavigationView: UIView, NavigationViewControllerDelegate {
  weak var navViewController: NavigationViewController?
  var embedded: Bool
  var embedding: Bool
  var options: NavigationRouteOptions
  
  @objc var waypoints: NSArray = [] {
    didSet { setNeedsLayout() }
  }
  
  @objc var shouldSimulateRoute: Bool = false
  @objc var showsEndOfRouteFeedback: Bool = false
  @objc var showsRouteFeedback: Bool = false
  @objc var hideStatusView: Bool = false
  @objc var mute: Bool = false
  
  @objc var onLocationChange: RCTDirectEventBlock?
  @objc var onRouteProgressChange: RCTDirectEventBlock?
  @objc var onError: RCTDirectEventBlock?
  @objc var onCancelNavigation: RCTDirectEventBlock?
  @objc var onArrive: RCTDirectEventBlock?
  
  override init(frame: CGRect) {
    self.embedded = false
    self.embedding = false
    self.options = NavigationRouteOptions(coordinates: [])
    super.init(frame: frame)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    if (navViewController == nil && !embedding && !embedded) {
      embed()
    } else {
      navViewController?.view.frame = bounds
    }
  }
  
  override func removeFromSuperview() {
    super.removeFromSuperview()
    // cleanup and teardown any existing resources
    self.navViewController?.removeFromParent()
  }
  
  private func embed() {
    guard waypoints.count > 0 else { return }
    
    embedding = true
    
    var points: [Waypoint] = []
    var i: Int = 0;
    
    for waypoint in self.waypoints {
        let way = waypoint as! NSArray
        let point = Waypoint(coordinate: CLLocationCoordinate2D(latitude: way[1] as! CLLocationDegrees, longitude: way[0] as! CLLocationDegrees))
        
        if(i > 0 && i != waypoints.count-1){
            point.separatesLegs = false
        }
        
        points.append(point)
        i+=1
    }
    
    let options = NavigationRouteOptions(waypoints: points, profileIdentifier: .automobileAvoidingTraffic)

    Directions.shared.calculate(options) { [weak self] (_, result) in
      guard let strongSelf = self, let parentVC = strongSelf.parentViewController else {
        return
      }
      
      switch result {
        case .failure(let error):
            print("error: \(error.localizedDescription)")
          strongSelf.onError!(["message": error.localizedDescription])
        case .success(let response):
          guard let weakSelf = self else {
            return
          }
          
          let navigationService = MapboxNavigationService(routeResponse: response, routeIndex: 0, routeOptions: options, simulating: strongSelf.shouldSimulateRoute ? .always : .never)
          
          let navigationOptions = NavigationOptions(styles: [CustomStyle()], navigationService: navigationService)
          let vc = NavigationViewController(for: response, routeIndex: 0, routeOptions: options, navigationOptions: navigationOptions)
          
          vc.showsReportFeedback = strongSelf.showsRouteFeedback
          vc.showsEndOfRouteFeedback = strongSelf.showsEndOfRouteFeedback
          StatusView.appearance().isHidden = strongSelf.hideStatusView
          NavigationSettings.shared.voiceMuted = strongSelf.mute
          vc.delegate = strongSelf
                  
          parentVC.addChild(vc)
          strongSelf.addSubview(vc.view)
          vc.view.frame = strongSelf.bounds
          vc.didMove(toParent: parentVC)
          strongSelf.navViewController = vc
      }
      
      strongSelf.embedding = false
      strongSelf.embedded = true
    }
  }
  
  func navigationViewController(_ navigationViewController: NavigationViewController, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
    onLocationChange?(["longitude": location.coordinate.longitude, "latitude": location.coordinate.latitude])
    onRouteProgressChange?(["distanceTraveled": progress.distanceTraveled,
                            "durationRemaining": progress.durationRemaining,
                            "fractionTraveled": progress.fractionTraveled,
                            "distanceRemaining": progress.distanceRemaining])
  }
  
  func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
    if (!canceled) {
      return;
    }
    onCancelNavigation?(["message": ""]);
  }
  
  func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) -> Bool {
    onArrive?(["message": ""]);
    return true;
  }

}

class CustomStyle: DayStyle {
    required init() {
        super.init()
        mapStyleURL = URL(string: "mapbox://styles/mapbox/navigation-day-v1")!
        styleType = .night
        fontFamily = "Ubuntu"
    }

    override func apply() {
        super.apply()
        BottomBannerView.appearance().backgroundColor = .darkGray
        BottomBannerView.appearance().textColor = .white
        BottomBannerView.appearance().tintColor = .white

        
        TopBannerView.appearance().backgroundColor = .darkGray
        TopBannerView.appearance().textColor = .white
        TopBannerView.appearance().tintColor = .white
    }
}
