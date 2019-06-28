/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main application delegate.
*/

import UIKit
import CoreNFC

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        
        // 处理由NFC后台标签读取特性创建的用户活动
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb else {
            return false
        }
        
        // 确认NSUserActivity对象包含一个有效的NDEF消息
        let ndefMessage = userActivity.ndefMessagePayload
        guard !ndefMessage.records.isEmpty,
            ndefMessage.records[0].typeNameFormat != .empty else {
                return false
        }
        
        guard let scanViewController = window?.rootViewController as? ScanViewController else {
            fatalError("")
        }
        
        DispatchQueue.main.async {
            // 消息发送到“ScanViewController”进行处理
            _ = scanViewController.updateWithNDEFMessage(ndefMessage)
        }
        
        return true
    }
}

