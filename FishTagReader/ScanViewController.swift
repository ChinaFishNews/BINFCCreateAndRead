/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View controller that reads NFC fish tag.
*/

import UIKit
import CoreNFC
import os

class ScanViewController: UITableViewController, NFCTagReaderSessionDelegate {

    // MARK: - Properties
    var readerSession: NFCTagReaderSession?
    
    @IBOutlet weak var kindText: UITextField!
    @IBOutlet weak var dateText: UITextField!
    @IBOutlet weak var priceText: UITextField!
    @IBOutlet weak var infoText: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: - Actions
    @IBAction func scanTag(_ sender: Any) {
        guard NFCNDEFReaderSession.readingAvailable else {
            let alertController = UIAlertController(
                title: "不支持扫描",
                message: "这个设备不支持标签扫描",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }
        
        readerSession = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693, .iso18092], delegate: self, queue: nil)
        readerSession?.alertMessage = "Hold your iPhone near an NFC fish tag."
        readerSession?.begin()
    }
    
    // MARK: - Private helper functions
    func tagRemovalDetect(_ tag: NFCTag) {
        self.readerSession?.connect(to: tag) { (error: Error?) in
            if error != nil || !tag.isAvailable {
                
                os_log("重新启动轮询")
                
                self.readerSession?.restartPolling()
                return
            }
            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + .milliseconds(500), execute: {
                self.tagRemovalDetect(tag)
            })
        }
    }
    
    func getDate(from value: String?) -> String? {
        guard let dateString = value else {
            return nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let outputDateFormatter = DateFormatter()
        outputDateFormatter.dateStyle = .medium
        outputDateFormatter.timeStyle = .none
        outputDateFormatter.locale = Locale.current
        
        return outputDateFormatter.string(from: dateFormatter.date(from: dateString)!)
    }
    
    func getPrice(from value: String?) -> String? {
        guard let priceString = value else {
            return nil
        }
        
        return String("$\(priceString.prefix(priceString.count - 2)).\(priceString.suffix(2))")
    }
    
    // UI元素根据接收到的NDEF消息进行更新
    func updateWithNDEFMessage(_ message: NFCNDEFMessage) -> Bool {
        let urls: [URLComponents] = message.records.compactMap { (payload: NFCNDEFPayload) -> URLComponents? in
            // 使用匹配的域主机和方案搜索URL记录
            if let url = payload.wellKnownTypeURIPayload() {
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                if components?.host == "www.baidu.com" && components?.scheme == "https" {
                    return components
                }
            }
            return nil
        }
        
        // 有效标签应该只包含一个URL和多个查询项
        guard urls.count == 1,
            let items = urls.first?.queryItems else {
            return false
        }
        
        // 从有效负载中获取可选信息文本
        var additionInfo: String? = nil

        for payload in message.records {
            (additionInfo, _) = payload.wellKnownTypeTextPayload()
            
            if additionInfo != nil {
                break
            }
        }
        
        DispatchQueue.main.async {
            self.infoText.text = additionInfo
            
            for item in items {
                switch item.name {
                case "date":
                    self.dateText.text = self.getDate(from: item.value)
                case "price":
                    self.priceText.text = self.getPrice(from: item.value)
                case "kind":
                    self.kindText.text = item.value
                default:
                    break
                }
            }
        }
        
        return true
    }
    
    // MARK: - NFCTagReaderSessionDelegate
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        // 如果需要，您可以在会话启动时执行其他操作
        // 此时启用了RF轮询
        print("BecomeActive");
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        // 如果有必要，您可以处理错误。注:会话不再有效
        // 您必须创建一个新会话来重新启动RF轮询
        print("error=\(error)");
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        if tags.count > 1 {
            session.alertMessage = "发现了1个以上的标签。请只展示1个标签"
            self.tagRemovalDetect(tags.first!)
            return
        }
        
        var ndefTag: NFCNDEFTag
        
        switch tags.first! {
        case let .iso7816(tag):
            ndefTag = tag
        case let .feliCa(tag):
            ndefTag = tag
        case let .iso15693(tag):
            ndefTag = tag
        case let .miFare(tag):
            ndefTag = tag
        @unknown default:
            session.invalidate(errorMessage: "标签无效")
            return
        }
        
        session.connect(to: tags.first!) { (error: Error?) in
            if error != nil {
                session.invalidate(errorMessage: "连接错误 请再试一次")
                return
            }
            
            ndefTag.queryNDEFStatus() { (status: NFCNDEFStatus, _, error: Error?) in
                if status == .notSupported {
                    session.invalidate(errorMessage: "标签无效")
                    return
                }
                ndefTag.readNDEF() { (message: NFCNDEFMessage?, error: Error?) in
                    if error != nil {
                        session.invalidate(errorMessage: "读取错误 请再试一次")
                        return
                    }
                    
                    if message == nil {
                        session.invalidate(errorMessage: "没有读取到任何信息")
                        return
                    }
                    
                    if self.updateWithNDEFMessage(message!) {
                        session.invalidate()
                    }
                    
//                    session.invalidate(errorMessage: "标签无效")
                }
            }
        }
    }
}

