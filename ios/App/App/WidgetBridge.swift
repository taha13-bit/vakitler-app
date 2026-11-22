import Foundation
import UIKit
import Capacitor
import WidgetKit

/// Shares the upcoming prayer times with the home-screen widget through the App Group.
@objc(WidgetBridgePlugin)
public class WidgetBridgePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "WidgetBridgePlugin"
    public let jsName = "WidgetBridge"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "setData", returnType: CAPPluginReturnPromise)
    ]

    static let appGroup = "group.com.vakitler.app"

    @objc func setData(_ call: CAPPluginCall) {
        guard let json = call.getString("json") else {
            call.reject("json is required")
            return
        }
        let defaults = UserDefaults(suiteName: WidgetBridgePlugin.appGroup)
        defaults?.set(json, forKey: "widgetData")
        WidgetCenter.shared.reloadAllTimelines()
        call.resolve()
    }
}

/// Bridge view controller that registers the app's own (local) plugins.
class MainViewController: CAPBridgeViewController {
    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(WidgetBridgePlugin())
    }
}
